import Foundation

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

    struct ModelConfig: Identifiable, Equatable, Sendable {
        let id: String
        let name: String
        let fileName: String
        let downloadURL: URL
        let expectedSizeBytes: Int64

        var sizeDescription: String {
            let gb = Double(expectedSizeBytes) / 1_000_000_000
            return String(format: "%.1f GB", gb)
        }
    }

    /// Recommended for iPhone — light enough to run within iOS memory limits.
    /// 1B Q4 uses ~800 MB on disk, ~270 MB KV cache at n_ctx=1024.
    nonisolated static let defaultModel = ModelConfig(
        id: "llama-3.2-1b",
        name: "Llama 3.2 1B (Recommended)",
        fileName: "Llama-3.2-1B-Instruct-Q4_K_M.gguf",
        downloadURL: URL(string: "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf")!,
        expectedSizeBytes: 876_000_000
    )

    /// Larger model — better quality but may crash on devices with < 8 GB RAM.
    nonisolated static let largeModel = ModelConfig(
        id: "llama-3.2-3b",
        name: "Llama 3.2 3B (Advanced)",
        fileName: "Llama-3.2-3B-Instruct-Q4_K_M.gguf",
        downloadURL: URL(string: "https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf")!,
        expectedSizeBytes: 1_920_000_000
    )

    nonisolated static let allModels: [ModelConfig] = [defaultModel, largeModel]

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

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
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
        Task { @MainActor [weak self] in
            self?.isDownloading = false
            self?.errorMessage = "Download failed: \(error.localizedDescription)"
            self?.progressObservation?.invalidate()
            self?.progressObservation = nil
        }
    }
}
