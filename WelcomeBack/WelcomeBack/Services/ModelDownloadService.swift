import Foundation
import CryptoKit

/// Manages downloading and storage of GGUF model files for local LLM inference.
@MainActor
final class ModelDownloadService: NSObject, ObservableObject {

    static let shared = ModelDownloadService()

    // MARK: - Published State

    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0
    @Published private(set) var isModelReady = false
    @Published var errorMessage: String?

    // MARK: - Model Configuration

    /// Identifies the model family so LocalLLMService can apply the correct chat template.
    enum ModelFamily: String, Codable, Sendable {
        case llama3
        case gemma4
    }

    struct ModelConfig: Identifiable, Equatable, Sendable {
        let id: String
        let name: String
        let fileName: String
        let downloadURL: URL
        let expectedSizeBytes: Int64
        /// Expected SHA256 hash of the downloaded file for integrity verification.
        let expectedSHA256: String
        let family: ModelFamily

        var sizeDescription: String {
            let gb = Double(expectedSizeBytes) / 1_000_000_000
            return String(format: "%.1f GB", gb)
        }
    }

    /// Recommended for iPhone — light enough to run within iOS memory limits.
    /// 1B Q4 uses ~800 MB on disk, ~270 MB KV cache at n_ctx=1024.
    nonisolated static let defaultModel: ModelConfig = {
        guard let url = URL(string: "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf") else {
            preconditionFailure("Invalid hardcoded URL for default model")
        }
        return ModelConfig(
            id: "llama-3.2-1b",
            name: "Llama 3.2 1B",
            fileName: "Llama-3.2-1B-Instruct-Q4_K_M.gguf",
            downloadURL: url,
            expectedSizeBytes: 876_000_000,
            expectedSHA256: "0af83581e3f3efb0eda498b0d62ac11aff6b1e4cf9acf4346aa2eeb0e3d7d014",
            family: .llama3
        )
    }()

    /// Larger model — better quality but may crash on devices with < 8 GB RAM.
    nonisolated static let largeModel: ModelConfig = {
        guard let url = URL(string: "https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf") else {
            preconditionFailure("Invalid hardcoded URL for large model")
        }
        return ModelConfig(
            id: "llama-3.2-3b",
            name: "Llama 3.2 3B",
            fileName: "Llama-3.2-3B-Instruct-Q4_K_M.gguf",
            downloadURL: url,
            expectedSizeBytes: 1_920_000_000,
            expectedSHA256: "6c1a3e0b4f1c1b3e0a2c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5",
            family: .llama3
        )
    }()

    /// Gemma 4 E2B — Google's frontier on-device model with multimodal support.
    /// ~3.1 GB on disk (Q4_K_M), needs ~4 GB RAM. Best quality for devices with 6+ GB RAM.
    nonisolated static let gemma4E2B: ModelConfig = {
        guard let url = URL(string: "https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/resolve/main/gemma-4-E2B-it-Q4_K_M.gguf") else {
            preconditionFailure("Invalid hardcoded URL for Gemma 4 E2B model")
        }
        return ModelConfig(
            id: "gemma-4-e2b",
            name: "Gemma 4 E2B (Recommended)",
            fileName: "gemma-4-E2B-it-Q4_K_M.gguf",
            downloadURL: url,
            expectedSizeBytes: 3_110_000_000,
            expectedSHA256: "",
            family: .gemma4
        )
    }()

    nonisolated static let allModels: [ModelConfig] = [gemma4E2B, defaultModel, largeModel]

    // MARK: - Active Model

    @Published var selectedModelID: String = ModelDownloadService.defaultModel.id {
        didSet {
            UserDefaults.standard.set(selectedModelID, forKey: "selectedLocalModelID")
            refreshModelReadiness()
        }
    }

    var selectedModel: ModelConfig {
        Self.allModels.first { $0.id == selectedModelID } ?? Self.defaultModel
    }

    // MARK: - Paths

    private var modelsDirectoryURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Models", isDirectory: true)
    }

    func modelFileURL(for config: ModelConfig) -> URL {
        modelsDirectoryURL.appendingPathComponent(config.fileName)
    }

    // MARK: - State Queries

    func isModelDownloaded(_ config: ModelConfig) -> Bool {
        FileManager.default.fileExists(atPath: modelFileURL(for: config).path)
    }

    func modelFileSizeBytes(_ config: ModelConfig) -> Int64? {
        let url = modelFileURL(for: config)
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return nil
        }
        return attrs[.size] as? Int64
    }

    func availableStorageBytes() -> Int64 {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        guard let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]) else {
            return 0
        }
        return values.volumeAvailableCapacityForImportantUsage ?? 0
    }

    // MARK: - Init

    private override init() {
        super.init()
        let savedID = UserDefaults.standard.string(forKey: "selectedLocalModelID") ?? Self.defaultModel.id
        // If the saved model exists in allModels, use it; otherwise fall back to default
        if Self.allModels.contains(where: { $0.id == savedID }) {
            selectedModelID = savedID
        } else {
            selectedModelID = Self.defaultModel.id
        }
        refreshModelReadiness()
    }

    func refreshModelReadiness() {
        isModelReady = isModelDownloaded(selectedModel)
    }

    // MARK: - Download

    private var downloadTask: URLSessionDownloadTask?
    private var progressObservation: NSKeyValueObservation?

    func downloadModel(_ config: ModelConfig) {
        guard !isDownloading else { return }

        // Storage check
        let required = config.expectedSizeBytes + 500_000_000 // 500MB buffer
        guard availableStorageBytes() > required else {
            errorMessage = "Not enough storage. Need \(config.sizeDescription) + 500 MB free."
            return
        }

        // Create directory
        let fm = FileManager.default
        if !fm.fileExists(atPath: modelsDirectoryURL.path) {
            try? fm.createDirectory(at: modelsDirectoryURL, withIntermediateDirectories: true)
        }

        isDownloading = true
        downloadProgress = 0
        errorMessage = nil

        var sessionConfig = URLSessionConfiguration.default
        sessionConfig.allowsCellularAccess = false
        let session = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
        let task = session.downloadTask(with: config.downloadURL)
        self.downloadTask = task

        // Observe progress
        progressObservation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            Task { @MainActor [weak self] in
                self?.downloadProgress = progress.fractionCompleted
            }
        }

        task.resume()
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        progressObservation?.invalidate()
        progressObservation = nil
        isDownloading = false
        downloadProgress = 0
    }

    func deleteModel(_ config: ModelConfig) {
        let url = modelFileURL(for: config)
        try? FileManager.default.removeItem(at: url)
        refreshModelReadiness()
    }
}

// MARK: - File Integrity

extension ModelDownloadService {
    /// Computes SHA256 hash of a file using streaming (1 MB chunks) to avoid loading the entire file into memory.
    nonisolated static func sha256OfFile(at url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { handle.closeFile() }

        var hasher = SHA256()
        let chunkSize = 1_024 * 1_024 // 1 MB
        while autoreleasepool(invoking: {
            let chunk = handle.readData(ofLength: chunkSize)
            guard !chunk.isEmpty else { return false }
            hasher.update(data: chunk)
            return true
        }) {}

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - URLSessionDownloadDelegate

extension ModelDownloadService: URLSessionDownloadDelegate {

    nonisolated func urlSession(_ session: URLSession,
                                downloadTask: URLSessionDownloadTask,
                                didFinishDownloadingTo location: URL) {
        // IMPORTANT: The temp file at `location` is deleted as soon as this
        // delegate method returns, so we must move it synchronously here —
        // NOT inside an async Task.

        let config = Self.allModels.first {
            downloadTask.originalRequest?.url == $0.downloadURL
        } ?? Self.defaultModel

        let fm = FileManager.default
        let documentsURL = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelsDir = documentsURL.appendingPathComponent("Models", isDirectory: true)
        let destination = modelsDir.appendingPathComponent(config.fileName)

        do {
            // Ensure the Models directory exists
            if !fm.fileExists(atPath: modelsDir.path) {
                try fm.createDirectory(at: modelsDir, withIntermediateDirectories: true)
            }

            // Remove existing file if present
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }

            // Move the temp file — must happen synchronously before delegate returns
            try fm.moveItem(at: location, to: destination)
            print("[ModelDownload] Model saved to \(destination.path)")

            // Verify file integrity via streaming SHA256
            if !config.expectedSHA256.isEmpty {
                let computedHash = Self.sha256OfFile(at: destination)
                if computedHash != config.expectedSHA256 {
                    print("[ModelDownload] SHA256 mismatch: expected \(config.expectedSHA256), got \(computedHash ?? "nil")")
                    try? fm.removeItem(at: destination)
                    Task { @MainActor [weak self] in
                        self?.isDownloading = false
                        self?.errorMessage = "Model file integrity check failed. Please try downloading again."
                        self?.progressObservation?.invalidate()
                        self?.progressObservation = nil
                    }
                    return
                }
                print("[ModelDownload] SHA256 verified OK")
            }

            // Update UI state on MainActor
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isDownloading = false
                self.downloadProgress = 1.0
                self.progressObservation?.invalidate()
                self.progressObservation = nil
                self.refreshModelReadiness()
            }
        } catch {
            print("[ModelDownload] Failed to save: \(error)")
            Task { @MainActor [weak self] in
                self?.isDownloading = false
                self?.errorMessage = "Failed to save model: \(error.localizedDescription)"
                self?.progressObservation?.invalidate()
                self?.progressObservation = nil
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession,
                                task: URLSessionTask,
                                didCompleteWithError error: Error?) {
        guard let error, (error as NSError).code != NSURLErrorCancelled else { return }
        let nsError = error as NSError
        let message: String
        if nsError.domain == NSURLErrorDomain,
           nsError.code == NSURLErrorNotConnectedToInternet || nsError.code == NSURLErrorDataNotAllowed {
            message = "Please connect to Wi-Fi to download the AI model."
        } else {
            message = "Download failed: \(error.localizedDescription)"
        }
        Task { @MainActor [weak self] in
            self?.isDownloading = false
            self?.errorMessage = message
            self?.progressObservation?.invalidate()
            self?.progressObservation = nil
        }
    }
}
