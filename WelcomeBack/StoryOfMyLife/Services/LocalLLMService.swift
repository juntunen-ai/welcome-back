import Foundation
import llama

/// Wraps the llama.cpp C API for on-device LLM inference.
///
/// Usage:
/// 1. Create with path to a GGUF model file
/// 2. Call `loadModel()` to initialise the backend and load weights
/// 3. Call `setSystemPrompt(_:)` once per session
/// 4. Call `generateResponse(userMessage:)` to get an `AsyncStream<String>` of token pieces
/// 5. Call `unloadModel()` when done (or let deinit handle it)
/// C callback for llama.cpp internal logs — captures errors/warnings during model load.
private func llamaLogCallback(level: ggml_log_level, text: UnsafePointer<CChar>?, userData: UnsafeMutableRawPointer?) {
    guard let text = text else { return }
    let msg = String(cString: text).trimmingCharacters(in: .whitespacesAndNewlines)
    guard !msg.isEmpty else { return }
    let prefix: String
    switch level {
    case GGML_LOG_LEVEL_ERROR: prefix = "❌ ERROR"
    case GGML_LOG_LEVEL_WARN:  prefix = "⚠️ WARN"
    case GGML_LOG_LEVEL_INFO:  prefix = "ℹ️ INFO"
    default:                    prefix = "🔍 DEBUG"
    }
    dprint("[llama.cpp] \(prefix): \(msg)")
}

final class LocalLLMService: @unchecked Sendable {

    // MARK: - Types

    enum LLMError: LocalizedError {
        case modelNotFound
        case modelLoadFailed
        case contextCreationFailed
        case generationFailed
        case notLoaded

        var errorDescription: String? {
            switch self {
            case .modelNotFound:         return "Model file not found on disk."
            case .modelLoadFailed:       return "Failed to load the AI model."
            case .contextCreationFailed: return "Failed to create inference context."
            case .generationFailed:      return "Text generation failed."
            case .notLoaded:             return "Model is not loaded."
            }
        }
    }

    struct GenerationConfig {
        var temperature: Float = 0.7
        var topP: Float = 0.9
        var topK: Int32 = 40
        var maxTokens: Int = 384       // more room for richer responses with Q4_K_M quality
        var repeatPenalty: Float = 1.1
        var repeatPenaltyLastN: Int32 = 64
    }

    // MARK: - State

    // llama_model, llama_context, llama_vocab are forward-declared (incomplete) C types
    // → Swift imports their pointers as OpaquePointer
    private var model: OpaquePointer?
    private var context: OpaquePointer?
    private var vocab: OpaquePointer?
    private var sampler: UnsafeMutablePointer<llama_sampler>?
    private(set) var isLoaded = false
    private let modelPath: String
    private let modelFamily: ModelDownloadService.ModelFamily

    /// Tracks the total number of tokens evaluated so far in this context.
    private var nPast: Int32 = 0

    /// Stores the number of tokens consumed by the system prompt.
    private var systemPromptTokenCount: Int32 = 0

    /// Current generation config — can be adjusted between turns.
    var config = GenerationConfig()

    /// Set `true` from outside to cancel an in-progress generation.
    var cancelGeneration = false

    // MARK: - Init / Deinit

    init(modelPath: String, modelFamily: ModelDownloadService.ModelFamily = .gemma4) {
        self.modelPath = modelPath
        self.modelFamily = modelFamily
    }

    deinit {
        unloadModel()
    }

    // MARK: - Model Lifecycle

    /// Loads the GGUF model into memory.
    /// Mirrors the official llama.cpp SwiftUI example's approach exactly.
    func loadModel() throws {
        #if DEBUG
        dprint("[LocalLLM] ⏳ Starting model load...")
        #endif

        guard FileManager.default.fileExists(atPath: modelPath) else {
            #if DEBUG
            dprint("[LocalLLM] ❌ Model file not found at: \(modelPath)")
            #endif
            throw LLMError.modelNotFound
        }

        let attrs = try? FileManager.default.attributesOfItem(atPath: modelPath)
        let fileSize = (attrs?[.size] as? Int64) ?? 0
        dprint("[LocalLLM] 📦 Model file: \(modelPath)")
        dprint("[LocalLLM] 📦 Model file size: \(fileSize / 1_000_000) MB (\(fileSize) bytes)")

        // Validate file size — Gemma 4 E2B Q4_K_M should be ~3.1 GB
        if fileSize < 2_000_000_000 {
            dprint("[LocalLLM] ❌ Model file too small (\(fileSize) bytes) — likely corrupt or incomplete download")
            throw LLMError.modelLoadFailed
        }

        // 1. Backend init (safe to call multiple times)
        dprint("[LocalLLM] 🔧 Initializing backend...")
        llama_log_set(llamaLogCallback, nil)
        llama_backend_init()

        // 2. Load model + create context. Try Metal GPU offload first, fall back to CPU.
        //    The PREVIOUS bundled llama.xcframework produced GARBAGE on the iOS Metal
        //    path for the gemma4 architecture. That framework has been rebuilt from a
        //    current llama.cpp (b9430) — the exact build verified to produce coherent
        //    gemma4 output on Metal — so GPU offload is re-enabled here. flash_attn
        //    stays AUTO to match that verified-good configuration.
        //    NOTE: [999, 0] only falls back to CPU on a LOAD failure; if a future
        //    framework regresses Metal *correctness* (loads but emits gibberish),
        //    set this back to [0] until fixed.
        let gpuLayerAttempts: [Int32] = [999, 0]
        dprint("[LocalLLM] 🚀 Metal GPU offload enabled (rebuilt llama.xcframework, gemma4 Metal verified)")

        let nThreads = max(1, min(8, ProcessInfo.processInfo.processorCount - 2))
        dprint("[LocalLLM] 🔧 Using \(nThreads) threads")

        var loadedModel: OpaquePointer?
        var createdCtx: OpaquePointer?
        var lastFailure: LLMError = .modelLoadFailed

        for attemptLayers in gpuLayerAttempts {
            var modelParams = llama_model_default_params()
            modelParams.use_mmap = true
            modelParams.n_gpu_layers = attemptLayers

            if attemptLayers > 0 {
                dprint("[LocalLLM] 🚀 Attempt: Metal GPU offload (n_gpu_layers=\(attemptLayers))")
            } else {
                dprint("[LocalLLM] 🧠 Attempt: CPU-only (n_gpu_layers=0)")
            }

            dprint("[LocalLLM] 📂 Calling llama_model_load_from_file...")
            guard let mdl = llama_model_load_from_file(modelPath, modelParams) else {
                dprint("[LocalLLM] ❌ llama_model_load_from_file returned nil (n_gpu_layers=\(attemptLayers))")
                lastFailure = .modelLoadFailed
                continue
            }
            dprint("[LocalLLM] ✅ Model loaded into memory")

            var ctxParams = llama_context_default_params()
            ctxParams.n_ctx = 4096          // longer conversational memory (CPU + increased-memory-limit entitlement)
            ctxParams.n_batch = 256
            ctxParams.n_ubatch = 256
            ctxParams.n_threads = Int32(nThreads)
            ctxParams.n_threads_batch = Int32(nThreads)
            ctxParams.flash_attn_type = LLAMA_FLASH_ATTN_TYPE_AUTO
            dprint("[LocalLLM] 🔧 Creating context (n_ctx=4096, n_batch=256, flash_attn=auto)...")

            guard let ctx = llama_init_from_model(mdl, ctxParams) else {
                dprint("[LocalLLM] ❌ llama_init_from_model returned nil (n_gpu_layers=\(attemptLayers)) — will retry on CPU if possible")
                llama_model_free(mdl)
                lastFailure = .contextCreationFailed
                continue
            }

            loadedModel = mdl
            createdCtx = ctx
            dprint("[LocalLLM] ✅ Context created (n_gpu_layers=\(attemptLayers))")
            break
        }

        guard let finalModel = loadedModel, let finalCtx = createdCtx else {
            dprint("[LocalLLM] ❌ All load attempts failed — check [llama.cpp] logs above for reason")
            throw lastFailure
        }

        model = finalModel
        context = finalCtx

        // 3. Get vocabulary handle
        vocab = llama_model_get_vocab(finalModel)
        dprint("[LocalLLM] ✅ Vocabulary obtained")

        // 4. Build sampler chain
        #if DEBUG
        dprint("[LocalLLM] 🔧 Building sampler chain...")
        #endif
        try buildSamplerChain()

        nPast = 0
        isLoaded = true
        #if DEBUG
        dprint("[LocalLLM] ✅ Model fully ready")
        #endif
    }

    /// Builds a sampler chain with the current generation config.
    private func buildSamplerChain() throws {
        // Free any existing sampler
        if let s = sampler {
            llama_sampler_free(s)
            sampler = nil
        }

        let sparams = llama_sampler_chain_default_params()
        guard let chain = llama_sampler_chain_init(sparams) else {
            #if DEBUG
            dprint("[LocalLLM] ❌ llama_sampler_chain_init returned nil")
            #endif
            throw LLMError.generationFailed
        }

        // Penalties (applied first, before other sampling)
        llama_sampler_chain_add(chain, llama_sampler_init_penalties(
            config.repeatPenaltyLastN,
            config.repeatPenalty,
            0,   // frequency penalty
            0    // presence penalty
        ))

        // Top-K → Top-P → Temperature → Distribution sampling
        llama_sampler_chain_add(chain, llama_sampler_init_top_k(config.topK))
        llama_sampler_chain_add(chain, llama_sampler_init_top_p(config.topP, 1))
        llama_sampler_chain_add(chain, llama_sampler_init_temp(config.temperature))
        llama_sampler_chain_add(chain, llama_sampler_init_dist(UInt32.random(in: 0...UInt32.max)))

        sampler = chain
        #if DEBUG
        dprint("[LocalLLM] ✅ Sampler chain built")
        #endif
    }

    /// Resets the context for a new session without unloading the model.
    /// Much faster than unload + reload (~10ms vs ~2-5s).
    func resetContext() {
        guard isLoaded, let ctx = context else { return }
        let mem = llama_get_memory(ctx)
        llama_memory_clear(mem, true)
        nPast = 0
        systemPromptTokenCount = 0
        cancelGeneration = false
        gemmaFirstTurn = true
        #if DEBUG
        dprint("[LocalLLM] 🔄 Context reset (model stays loaded)")
        #endif
    }

    /// Unloads the model and frees all resources.
    func unloadModel() {
        if let s = sampler {
            llama_sampler_free(s)
            sampler = nil
        }
        if let ctx = context {
            llama_free(ctx)
            context = nil
        }
        if let mdl = model {
            llama_model_free(mdl)
            model = nil
        }
        vocab = nil
        llama_backend_free()
        isLoaded = false
        nPast = 0
        systemPromptTokenCount = 0
        #if DEBUG
        dprint("[LocalLLM] Model unloaded")
        #endif
    }

    // MARK: - Tokenisation Helpers

    /// Tokenises a string using the loaded model's vocabulary.
    private func tokenize(_ text: String, addSpecial: Bool = false) -> [llama_token] {
        guard let voc = vocab else { return [] }
        let utf8Count = Int32(text.utf8.count)
        let maxTokens = Int32(utf8Count + (addSpecial ? 1 : 0) + 16)
        var tokens = [llama_token](repeating: 0, count: Int(maxTokens))
        let n = llama_tokenize(voc, text, utf8Count,
                               &tokens, maxTokens,
                               addSpecial, /* parse_special: */ true)
        guard n >= 0 else { return [] }
        return Array(tokens.prefix(Int(n)))
    }

    /// Converts a token ID to its text representation.
    private func tokenToString(_ token: llama_token) -> String {
        guard let voc = vocab else { return "" }
        var buf = [CChar](repeating: 0, count: 128)
        let len = llama_token_to_piece(voc, token, &buf, Int32(buf.count), 0, false)
        guard len > 0 else { return "" }
        return String(cString: buf.prefix(Int(len)) + [0])
    }

    // MARK: - Evaluation

    /// Maximum tokens per decode call — must match `ctxParams.n_batch` (256).
    /// Submitting more tokens than n_batch in a single llama_decode call triggers
    /// a ggml_abort assertion inside ggml.c, causing a SIGABRT crash.
    private let maxBatchSize = 256

    /// Evaluates a batch of tokens into the context.
    /// Automatically splits into chunks of `maxBatchSize` to avoid ggml assertion failures.
    private func evaluate(tokens: [llama_token]) throws {
        guard let ctx = context else { throw LLMError.notLoaded }
        guard !tokens.isEmpty else { return }

        for chunkStart in stride(from: 0, to: tokens.count, by: maxBatchSize) {
            let chunkEnd = min(chunkStart + maxBatchSize, tokens.count)
            let chunk = Array(tokens[chunkStart..<chunkEnd])
            let isLastChunk = (chunkEnd == tokens.count)

            var batch = llama_batch_init(Int32(chunk.count), 0, 1)
            defer { llama_batch_free(batch) }

            for (i, token) in chunk.enumerated() {
                let pos = nPast + Int32(i)
                let idx = batch.n_tokens
                batch.token[Int(idx)] = token
                batch.pos[Int(idx)] = pos
                batch.n_seq_id[Int(idx)] = 1
                if let seqIdPtr = batch.seq_id?[Int(idx)] {
                    seqIdPtr.pointee = 0
                }
                // Only request logits for the very last token overall
                batch.logits[Int(idx)] = (isLastChunk && i == chunk.count - 1) ? 1 : 0
                batch.n_tokens += 1
            }

            let result = llama_decode(ctx, batch)
            guard result == 0 else {
                #if DEBUG
                dprint("[LocalLLM] ❌ llama_decode failed with code: \(result)")
                #endif
                throw LLMError.generationFailed
            }

            nPast += Int32(chunk.count)
        }
    }

    // MARK: - System Prompt

    /// Stores the system prompt for Gemma 4. It is emitted once at the start of
    /// the conversation in a dedicated `<|turn>system … <turn|>` block on the
    /// first generation (see `generateResponse`), matching Gemma 4's native
    /// chat template (Gemma 4 DOES have a system role, unlike Gemma 3).
    func setSystemPrompt(_ prompt: String) throws {
        gemmaSystemPrompt = prompt
        systemPromptTokenCount = 0
        #if DEBUG
        dprint("[LocalLLM] Gemma 4 system prompt stored (\(prompt.count) chars, emitted as a <|turn>system block on first turn)")
        #endif
    }

    /// Stored system prompt for Gemma models (emitted in a leading system turn).
    private var gemmaSystemPrompt: String?
    private var gemmaFirstTurn = true

    // MARK: - Streaming Generation

    /// Generates a response to the user's message, yielding token-strings as an `AsyncStream`.
    ///
    /// The caller should accumulate tokens, detect sentence boundaries, and route
    /// completed sentences to TTS for streaming playback.
    func generateResponse(userMessage: String) -> AsyncStream<String> {
        AsyncStream { continuation in
            // Use DispatchQueue (8 MB stack) instead of Task.detached (64 KB stack)
            // to avoid stack overflow in llama.cpp C code.
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self, self.isLoaded else {
                    continuation.finish()
                    return
                }
                self.cancelGeneration = false

                do {
                    // 1. Format the prompt using Gemma 4's NATIVE chat template.
                    //    Gemma 4 uses <|turn>role\n …<turn|>\n delimiters with a real
                    //    `system` role — NOT Gemma 3's <start_of_turn>/<end_of_turn>,
                    //    which are not tokens in the Gemma 4 vocabulary and would be fed
                    //    to the model as ordinary text. The model's stop token is <turn|>.
                    //    Full first turn:
                    //      <bos><|turn>system\n{system}<turn|>\n<|turn>user\n{msg}<turn|>\n<|turn>model\n
                    //    Later turns omit <bos> and the system block (the KV cache retains them).
                    let isFirstTurn = self.nPast == 0
                    var prefill = ""
                    var systemBlockTokens: Int32 = 0
                    if isFirstTurn {
                        var systemBlock = "<bos>"
                        if let sys = self.gemmaSystemPrompt, !sys.isEmpty {
                            systemBlock += "<|turn>system\n\(sys)<turn|>\n"
                        }
                        // Count the system-block tokens so the sliding-window trimmer
                        // never evicts the personal-profile system prompt. The <bos>,
                        // <|turn> and <turn|> tokens are atomic special tokens, so the
                        // separate tokenization matches the prefix of the full prefill.
                        systemBlockTokens = Int32(self.tokenize(systemBlock).count)
                        prefill += systemBlock
                    }
                    prefill += "<|turn>user\n\(userMessage)<turn|>\n<|turn>model\n"
                    self.gemmaFirstTurn = false
                    let prefillTokens = self.tokenize(prefill)
                    #if DEBUG
                    dprint("[LocalLLM] 📝 Prefill tokens: \(prefillTokens.count), nPast=\(self.nPast)")
                    #endif
                    try self.evaluate(tokens: prefillTokens)
                    if isFirstTurn {
                        self.systemPromptTokenCount = systemBlockTokens
                    }
                    #if DEBUG
                    dprint("[LocalLLM] ✅ Prefill evaluated, nPast=\(self.nPast), systemTokens=\(self.systemPromptTokenCount)")
                    #endif

                    // 3. Sampling loop
                    guard let ctx = self.context, let voc = self.vocab, let smpl = self.sampler else {
                        #if DEBUG
                        dprint("[LocalLLM] ❌ Missing context/vocab/sampler")
                        #endif
                        continuation.finish()
                        return
                    }

                    var generated: Int = 0
                    #if DEBUG
                    dprint("[LocalLLM] 🔄 Starting sampling loop...")
                    #endif

                    while generated < self.config.maxTokens && !self.cancelGeneration {
                        let newToken = llama_sampler_sample(smpl, ctx, -1)
                        llama_sampler_accept(smpl, newToken)

                        // Check for ANY end-of-generation token (EOS, EOT, etc.)
                        if llama_vocab_is_eog(voc, newToken) {
                            #if DEBUG
                            dprint("[LocalLLM] 🛑 EOG token after \(generated) tokens")
                            #endif
                            break
                        }

                        let piece = self.tokenToString(newToken)
                        if !piece.isEmpty {
                            continuation.yield(piece)
                        }

                        try self.evaluate(tokens: [newToken])
                        generated += 1
                    }
                    #if DEBUG
                    dprint("[LocalLLM] ✅ Generation complete: \(generated) tokens")
                    #endif
                } catch {
                    #if DEBUG
                    dprint("[LocalLLM] ❌ Generation error: \(error.localizedDescription)")
                    #endif
                }

                continuation.finish()
            }
        }
    }

    // MARK: - Context Management

    /// Checks if the context is getting full and trims old conversation turns.
    /// Uses a sliding window: keeps system prompt + recent conversation, evicts oldest tokens.
    /// Trims proactively at 75% capacity to leave room for the next turn.
    func trimContextIfNeeded() {
        guard isLoaded, let ctx = context else { return }
        let maxCtx: Int32 = 4096
        let threshold: Int32 = maxCtx * 3 / 4  // trim at 75% (3072)

        guard nPast > threshold else { return }

        let mem = llama_get_memory(ctx)

        // Keep system prompt tokens (0..<systemPromptTokenCount)
        // and the most recent ~1536 conversation tokens (~8 turns).
        let keepRecent: Int32 = min(1536, nPast - systemPromptTokenCount)
        let evictFrom = systemPromptTokenCount   // first token after system prompt
        let evictTo = nPast - keepRecent          // keep the tail

        if evictTo > evictFrom {
            // Remove the middle portion of the KV cache
            let removed = llama_memory_seq_rm(mem, 0, evictFrom, evictTo)
            if removed {
                // Shift remaining tokens' positions down
                let shift = evictTo - evictFrom
                llama_memory_seq_add(mem, 0, evictTo, nPast, -shift)
                nPast -= shift
                #if DEBUG
                dprint("[LocalLLM] 🔄 Context trimmed: evicted \(shift) tokens, nPast=\(nPast)")
                #endif
            } else {
                // Gradual fallback: try evicting just the oldest quarter
                let fallbackTo = evictFrom + (evictTo - evictFrom) / 4
                let fallbackRemoved = llama_memory_seq_rm(mem, 0, evictFrom, fallbackTo)
                if fallbackRemoved {
                    let shift = fallbackTo - evictFrom
                    llama_memory_seq_add(mem, 0, fallbackTo, nPast, -shift)
                    nPast -= shift
                    #if DEBUG
                    dprint("[LocalLLM] 🔄 Context partially trimmed: evicted \(shift) tokens, nPast=\(nPast)")
                    #endif
                } else {
                    // Last resort: full clear
                    llama_memory_clear(mem, true)
                    nPast = 0
                    systemPromptTokenCount = 0
                    #if DEBUG
                    dprint("[LocalLLM] 🔄 Context fully cleared (all trim attempts failed)")
                    #endif
                }
            }
        }
    }
}
