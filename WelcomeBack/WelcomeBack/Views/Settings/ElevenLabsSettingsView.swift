import SwiftUI

/// Settings view for configuring the ElevenLabs API key for voice cloning.
struct ElevenLabsSettingsView: View {

    @State private var apiKey: String = ElevenLabsService.shared.apiKey
    @State private var isTestingConnection = false
    @State private var connectionResult: ConnectionResult?

    enum ConnectionResult {
        case success, failure(String)
    }

    var body: some View {
        ZStack {
            Color.backgroundDark.ignoresSafeArea()

            List {
                apiKeySection
                testSection
                infoSection
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("ElevenLabs")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - API Key

    private var apiKeySection: some View {
        Section {
            SecureField("API Key", text: $apiKey)
                .textContentType(.password)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .foregroundColor(.onSurface)
                .onChange(of: apiKey) { _, newValue in
                    ElevenLabsService.shared.apiKey = newValue
                    connectionResult = nil
                }
                .listRowBackground(Color.surfaceVariant.opacity(0.4))
        } header: {
            Text("API Key")
                .foregroundColor(.accentYellow)
                .font(.system(size: 12, weight: .bold))
                .tracking(1.5)
        } footer: {
            Text("Enter your ElevenLabs API key. You can find it at elevenlabs.io → Profile → API Key.")
                .font(.system(size: 11))
                .foregroundColor(.onSurface.opacity(0.4))
        }
    }

    // MARK: - Test

    private var testSection: some View {
        Section {
            Button {
                testConnection()
            } label: {
                HStack {
                    if isTestingConnection {
                        ProgressView()
                            .tint(.accentYellow)
                    } else {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.accentYellow)
                    }

                    Text("Test Connection")
                        .foregroundColor(.onSurface)

                    Spacer()

                    if let result = connectionResult {
                        switch result {
                        case .success:
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        case .failure:
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .disabled(apiKey.isEmpty || isTestingConnection)
            .listRowBackground(Color.surfaceVariant.opacity(0.4))

            if case .failure(let msg) = connectionResult {
                Text(msg)
                    .font(.system(size: 12))
                    .foregroundColor(.red.opacity(0.8))
                    .listRowBackground(Color.surfaceVariant.opacity(0.4))
            }
        }
    }

    // MARK: - Info

    private var infoSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "info.circle")
                    .foregroundColor(.accentYellow)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Voice cloning requires an ElevenLabs account.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.onSurface)
                    Text("The free tier includes voice cloning and limited speech generation. Cloned voices can make the AI sound like a family member.")
                        .font(.system(size: 12))
                        .foregroundColor(.onSurface.opacity(0.55))
                }
            }
            .padding(.vertical, 4)
            .listRowBackground(Color.surfaceVariant.opacity(0.4))
        }
    }

    // MARK: - Actions

    private func testConnection() {
        isTestingConnection = true
        connectionResult = nil

        Task {
            do {
                let success = try await ElevenLabsService.shared.testConnection()
                connectionResult = success ? .success : .failure("Invalid API key")
            } catch {
                connectionResult = .failure(error.localizedDescription)
            }
            isTestingConnection = false
        }
    }
}

#Preview {
    NavigationStack { ElevenLabsSettingsView() }
        .preferredColorScheme(.dark)
}
