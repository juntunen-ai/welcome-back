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
        var maxTokens: Int = 150
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

    /// Tracks the total number of tokens evaluated so far in this context.
    private var nPast: Int32 = 0

    /// Stores the number of tokens consumed by the system prompt.
    private var systemPromptTokenCount: Int32 = 0

    /// Current generation config — can be adjusted between turns.
    var config = GenerationConfig()

    /// Set `true` from outside to cancel an in-progress generation.
    var cancelGeneration = false

    // MARK: - Init / Deinit

    init(modelPath: String) {
        self.modelPath = modelPath
    }

    deinit {
        unloadModel()
    }

    // MARK: - Model Lifecycle

    /// Loads the GGUF model into memory.
    /// Mirrors the official llama.cpp SwiftUI example's approach exactly.
    func loadModel() throws {
        print("[LocalLLM] ⏳ Starting model load...")

        guard FileManager.default.fileExists(atPath: modelPath) else {
            print("[LocalLLM] ❌ Model file not found at: \(modelPath)")
            throw LLMError.modelNotFound
        }

        let attrs = try? FileManager.default.attributesOfItem(atPath: modelPath)
        let fileSize = (attrs?[.size] as? Int64) ?? 0
        print("[LocalLLM] 📦 Model file size: \(fileSize / 1_000_000) MB")

        // 1. Backend init (safe to call multiple times)
        print("[LocalLLM] 🔧 Initializing backend...")
        llama_backend_init()

        // 2. Model parameters — GPU offload on real device, CPU-only on simulator
        var modelParams = llama_model_default_params()
        #if targetEnvironment(simulator)
        modelParams.n_gpu_layers = 0
        print("[LocalLLM] ⚠️ Simulator detected, forcing CPU-only")
        #else
        modelParams.n_gpu_layers = 99   // offload all layers to Metal GPU
        print("[LocalLLM] 🚀 Metal GPU offload enabled (n_gpu_layers=99)")
        #endif
        print("[LocalLLM] 📂 Loading model file...")

        guard let loadedModel = llama_model_load_from_file(modelPath, modelParams) else {
            print("[LocalLLM] ❌ llama_model_load_from_file returned nil")
            throw LLMError.modelLoadFailed
        }
        model = loadedModel
        print("[LocalLLM] ✅ Model loaded into memory")

        // 3. Get vocabulary handle
        vocab = llama_model_get_vocab(loadedModel)
        print("[LocalLLM] ✅ Vocabulary obtained")

        // 4. Context parameters — only set n_ctx and threads (like the official example)
        let nThreads = max(1, min(8, ProcessInfo.processInfo.processorCount - 2))
        print("[LocalLLM] 🔧 Using \(nThreads) threads")

        var ctxParams = llama_context_default_params()
        ctxParams.n_ctx = 4096
        ctxParams.n_threads = Int32(nThreads)
        ctxParams.n_threads_batch = Int32(nThreads)
        print("[LocalLLM] 🔧 Creating context (n_ctx=4096)...")

        guard let ctx = llama_init_from_model(loadedModel, ctxParams) else {
            print("[LocalLLM] ❌ llama_init_from_model returned nil")
            llama_model_free(loadedModel)
            model = nil
            vocab = nil
            throw LLMError.contextCreationFailed
        }
        context = ctx
        print("[LocalLLM] ✅ Context created")

        // 5. Build sampler chain
        print("[LocalLLM] 🔧 Building sampler chain...")
        try buildSamplerChain()

        nPast = 0
        isLoaded = true
        print("[LocalLLM] ✅ Model fully ready")
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
            print("[LocalLLM] ❌ llama_sampler_chain_init returned nil")
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
        print("[LocalLLM] ✅ Sampler chain built")
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
        print("[LocalLLM] Model unloaded")
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

    /// Evaluates a batch of tokens into the context.
    private func evaluate(tokens: [llama_token]) throws {
        guard let ctx = context else { throw LLMError.notLoaded }
        guard !tokens.isEmpty else { return }

        var batch = llama_batch_init(Int32(tokens.count), 0, 1)
        defer { llama_batch_free(batch) }

        for (i, token) in tokens.enumerated() {
            let pos = nPast + Int32(i)
            let idx = batch.n_tokens
            batch.token[Int(idx)] = token
            batch.pos[Int(idx)] = pos
            batch.n_seq_id[Int(idx)] = 1
            if let seqIdPtr = batch.seq_id?[Int(idx)] {
                seqIdPtr.pointee = 0
            }
            batch.logits[Int(idx)] = (i == tokens.count - 1) ? 1 : 0
            batch.n_tokens += 1
        }

        let result = llama_decode(ctx, batch)
        guard result == 0 else {
            print("[LocalLLM] ❌ llama_decode failed with code: \(result)")
            throw LLMError.generationFailed
        }

        nPast += Int32(tokens.count)
    }

    // MARK: - System Prompt

    /// Evaluates the system prompt once at the start of a session.
    /// Uses the Llama 3 chat template format.
    func setSystemPrompt(_ prompt: String) throws {
        let formatted = "<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\n\(prompt)<|eot_id|>"
        let tokens = tokenize(formatted, addSpecial: false)
        guard !tokens.isEmpty else { return }

        try evaluate(tokens: tokens)
        systemPromptTokenCount = nPast
        print("[LocalLLM] System prompt set: \(tokens.count) tokens")
    }

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
                    // 1. Format user turn + assistant header and evaluate in a single batch
                    let prefill = "<|start_header_id|>user<|end_header_id|>\n\n\(userMessage)<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n"
                    let prefillTokens = self.tokenize(prefill)
                    print("[LocalLLM] 📝 Prefill tokens: \(prefillTokens.count), nPast=\(self.nPast)")
                    try self.evaluate(tokens: prefillTokens)
                    print("[LocalLLM] ✅ Prefill evaluated, nPast=\(self.nPast)")

                    // 3. Sampling loop
                    guard let ctx = self.context, let voc = self.vocab, let smpl = self.sampler else {
                        print("[LocalLLM] ❌ Missing context/vocab/sampler")
                        continuation.finish()
                        return
                    }

                    var generated: Int = 0
                    print("[LocalLLM] 🔄 Starting sampling loop...")

                    while generated < self.config.maxTokens && !self.cancelGeneration {
                        let newToken = llama_sampler_sample(smpl, ctx, -1)
                        llama_sampler_accept(smpl, newToken)

                        // Check for ANY end-of-generation token (EOS, EOT, etc.)
                        if llama_vocab_is_eog(voc, newToken) {
                            print("[LocalLLM] 🛑 EOG token after \(generated) tokens")
                            break
                        }

                        let piece = self.tokenToString(newToken)
                        if !piece.isEmpty {
                            continuation.yield(piece)
                        }

                        try self.evaluate(tokens: [newToken])
                        generated += 1
                    }
                    print("[LocalLLM] ✅ Generation complete: \(generated) tokens")
                } catch {
                    print("[LocalLLM] ❌ Generation error: \(error.localizedDescription)")
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
        let threshold: Int32 = maxCtx * 3 / 4  // trim at 75% (3072), not 88%

        guard nPast > threshold else { return }

        let mem = llama_get_memory(ctx)

        // Keep system prompt tokens (0..<systemPromptTokenCount)
        // and the most recent 1536 conversation tokens (~6-8 turns).
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
                print("[LocalLLM] 🔄 Context trimmed: evicted \(shift) tokens, nPast=\(nPast)")
            } else {
                // Gradual fallback: try evicting just the oldest quarter
                let fallbackTo = evictFrom + (evictTo - evictFrom) / 4
                let fallbackRemoved = llama_memory_seq_rm(mem, 0, evictFrom, fallbackTo)
                if fallbackRemoved {
                    let shift = fallbackTo - evictFrom
                    llama_memory_seq_add(mem, 0, fallbackTo, nPast, -shift)
                    nPast -= shift
                    print("[LocalLLM] 🔄 Context partially trimmed: evicted \(shift) tokens, nPast=\(nPast)")
                } else {
                    // Last resort: full clear
                    llama_memory_clear(mem, true)
                    nPast = 0
                    systemPromptTokenCount = 0
                    print("[LocalLLM] 🔄 Context fully cleared (all trim attempts failed)")
                }
            }
        }
    }
}
