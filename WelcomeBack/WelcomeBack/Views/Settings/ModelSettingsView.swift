import SwiftUI

/// Settings UI for downloading and managing the Gemma 4 voice AI model.
struct ModelSettingsView: View {

    @StateObject private var downloadService = ModelDownloadService.shared
    @EnvironmentObject private var appVM: AppViewModel

    private var model: ModelDownloadService.ModelConfig { ModelDownloadService.defaultModel }

    var body: some View {
        ZStack {
            Color.backgroundDark.ignoresSafeArea()

            List {
                statusSection
                downloadSection
                storageSection
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
            .listRowSeparatorTint(Color.white.opacity(0.07))
        }
        .navigationTitle("Voice AI Model")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Status

    private var statusSection: some View {
        Section {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(downloadService.isModelReady ? Color.green : Color.orange)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: downloadService.isModelReady ? "checkmark.circle" : "arrow.down.circle")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(downloadService.isModelReady ? "Gemma 4 Ready" : "Model Not Downloaded")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.onSurface)

                    Text("Google Gemma 4 E2B — best on-device AI")
                        .font(.system(size: 12))
                        .foregroundColor(.onSurface.opacity(0.5))
                }

                Spacer()
            }
            .padding(.vertical, 4)
            .listRowBackground(Color.surfaceVariant.opacity(0.4))
        } header: {
            sectionHeader("Status")
        }
    }

    // MARK: - Download

    private var downloadSection: some View {
        Section {
            if downloadService.isDownloading {
                // Progress
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Downloading Gemma 4 E2B…")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.onSurface)
                        Spacer()
                        Text("\(Int(downloadService.downloadProgress * 100))%")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.accentYellow)
                    }

                    ProgressView(value: downloadService.downloadProgress)
                        .tint(.accentYellow)

                    Button("Cancel Download") {
                        downloadService.cancelDownload()
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                }
                .padding(.vertical, 6)
                .listRowBackground(Color.surfaceVariant.opacity(0.4))
            } else if !downloadService.isModelDownloaded(model) {
                // Download button
                Button {
                    downloadService.downloadModel(model)
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 20))
                        Text("Download Gemma 4 E2B")
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Text(model.sizeDescription)
                            .font(.system(size: 13))
                            .foregroundColor(.onSurface.opacity(0.5))
                    }
                    .foregroundColor(.accentYellow)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.surfaceVariant.opacity(0.4))
            } else {
                // Already downloaded
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Gemma 4 downloaded and ready")
                        .font(.system(size: 15))
                        .foregroundColor(.onSurface)
                    Spacer()
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.surfaceVariant.opacity(0.4))
            }

            // Error message
            if let error = downloadService.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(.orange)
                }
                .listRowBackground(Color.surfaceVariant.opacity(0.4))
            }
        } header: {
            sectionHeader("Download")
        } footer: {
            Text("Gemma 4 E2B is Google's best on-device AI model (~2.3 GB). A Wi-Fi connection is recommended.")
                .font(.system(size: 11))
                .foregroundColor(.onSurface.opacity(0.3))
        }
    }

    // MARK: - Storage

    private var storageSection: some View {
        Section {
            if downloadService.isModelDownloaded(model) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Gemma 4 E2B")
                            .font(.system(size: 15))
                            .foregroundColor(.onSurface)

                        if let size = downloadService.modelFileSizeBytes(model) {
                            let gb = Double(size) / 1_000_000_000
                            Text(String(format: "%.1f GB on disk", gb))
                                .font(.system(size: 12))
                                .foregroundColor(.onSurface.opacity(0.5))
                        }
                    }

                    Spacer()

                    Button(role: .destructive) {
                        downloadService.deleteModel(model)
                    } label: {
                        Text("Delete")
                            .font(.system(size: 13, weight: .medium))
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.surfaceVariant.opacity(0.4))
            }

            let available = downloadService.availableStorageBytes()
            let availableGB = Double(available) / 1_000_000_000
            HStack {
                Text("Available Storage")
                    .font(.system(size: 14))
                    .foregroundColor(.onSurface.opacity(0.6))
                Spacer()
                Text(String(format: "%.1f GB", availableGB))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.onSurface)
            }
            .listRowBackground(Color.surfaceVariant.opacity(0.4))
        } header: {
            sectionHeader("Storage")
        }
    }

    // MARK: - Utility

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .foregroundColor(.accentYellow)
            .font(.system(size: 12, weight: .bold))
            .tracking(1.5)
            .textCase(.uppercase)
    }
}

#Preview {
    NavigationStack {
        ModelSettingsView()
            .environmentObject(AppViewModel())
    }
}
