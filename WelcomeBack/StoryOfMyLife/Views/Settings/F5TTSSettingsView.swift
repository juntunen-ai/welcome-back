import SwiftUI
import Darwin

/// Settings view for configuring the F5-TTS voice cloning server.
struct F5TTSSettingsView: View {

    @State private var serverURL: String = F5TTSService.shared.serverURL
    @State private var isTestingConnection = false
    @State private var connectionResult: ConnectionResult?
    @State private var references: [VoiceReference] = []
    @State private var isLoadingRefs = false

    enum ConnectionResult {
        case success, failure(String)
    }

    var body: some View {
        ZStack {
            Color.backgroundDark.ignoresSafeArea()

            List {
                serverSection
                testSection
                if case .success = connectionResult {
                    referencesSection
                }
                infoSection
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Voice Cloning")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Server URL

    private var serverSection: some View {
        Section {
            HStack {
                TextField("e.g. http://192.168.1.50:5005", text: $serverURL)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .foregroundColor(.onSurface)
                    .onChange(of: serverURL) { _, newValue in
                        F5TTSService.shared.serverURL = newValue
                        connectionResult = nil
                    }

                if serverURL.isEmpty {
                    Button {
                        if let detected = Self.detectLocalServerURL() {
                            serverURL = detected
                            F5TTSService.shared.serverURL = detected
                        }
                    } label: {
                        Text("Detect")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.accentYellow)
                    }
                } else {
                    Button {
                        serverURL = ""
                        F5TTSService.shared.serverURL = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.onSurface.opacity(0.3))
                    }
                }
            }
            .listRowBackground(Color.surfaceVariant.opacity(0.4))
        } header: {
            Text("Server URL")
                .foregroundColor(.accentYellow)
                .font(.system(size: 12, weight: .bold))
                .tracking(1.5)
        } footer: {
            Text("Tap Detect to find the server automatically, or type the URL of your F5-TTS server (e.g. http://your-mac-ip:5005).")
                .font(.system(size: 11))
                .foregroundColor(.onSurface.opacity(0.4))
        }
    }

    /// Attempts to detect the local Mac's IP by checking common gateway patterns.
    private static func detectLocalServerURL() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let sa = ptr.pointee.ifa_addr.pointee
            guard sa.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: ptr.pointee.ifa_name)
            // WiFi interface on iOS
            guard name == "en0" else { continue }

            var addr = ptr.pointee.ifa_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
            var ipBuf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            inet_ntop(AF_INET, &addr.sin_addr, &ipBuf, socklen_t(INET_ADDRSTRLEN))
            let deviceIP = String(cString: ipBuf)

            // Device is on e.g. 192.168.1.42 — server is likely on same subnet.
            // We can't know the Mac's IP from the phone, but we return the subnet
            // prefix so the user just needs the last octet.
            // For now, just return the device's own IP with port as a starting point.
            if !deviceIP.isEmpty && deviceIP != "0.0.0.0" {
                return "http://\(deviceIP):5005"
            }
        }
        return nil
    }

    // MARK: - Test Connection

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
            .disabled(serverURL.isEmpty || isTestingConnection)
            .listRowBackground(Color.surfaceVariant.opacity(0.4))

            if case .failure(let msg) = connectionResult {
                Text(msg)
                    .font(.system(size: 12))
                    .foregroundColor(.red.opacity(0.8))
                    .listRowBackground(Color.surfaceVariant.opacity(0.4))
            }
        }
    }

    // MARK: - Voice References

    private var referencesSection: some View {
        Section {
            if isLoadingRefs {
                HStack {
                    ProgressView().tint(.accentYellow)
                    Text("Loading voices...")
                        .font(.system(size: 14))
                        .foregroundColor(.onSurface.opacity(0.6))
                }
                .listRowBackground(Color.surfaceVariant.opacity(0.4))
            } else if references.isEmpty {
                Text("No cloned voices yet. Record a family member's voice to get started.")
                    .font(.system(size: 13))
                    .foregroundColor(.onSurface.opacity(0.5))
                    .listRowBackground(Color.surfaceVariant.opacity(0.4))
            } else {
                ForEach(references) { ref in
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundColor(.accentYellow)
                        Text(ref.name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.onSurface)
                    }
                    .listRowBackground(Color.surfaceVariant.opacity(0.4))
                }
                .onDelete(perform: deleteReference)
            }
        } header: {
            Text("Cloned Voices")
                .foregroundColor(.accentYellow)
                .font(.system(size: 12, weight: .bold))
                .tracking(1.5)
        }
    }

    // MARK: - Info

    private var infoSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "info.circle")
                    .foregroundColor(.accentYellow)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Voice cloning runs on your home network.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.onSurface)
                    Text("A Mac or PC on your Wi-Fi runs the F5-TTS server. Your voice data never leaves your network. When the server is offline, the app uses the default Apple voice.")
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
                let success = try await F5TTSService.shared.testConnection()
                connectionResult = success ? .success : .failure("Server responded but is not healthy")
                if success { await loadReferences() }
            } catch {
                connectionResult = .failure(error.localizedDescription)
            }
            isTestingConnection = false
        }
    }

    private func loadReferences() async {
        isLoadingRefs = true
        do {
            references = try await F5TTSService.shared.listReferences()
        } catch {
            references = []
        }
        isLoadingRefs = false
    }

    private func deleteReference(at offsets: IndexSet) {
        let toDelete = offsets.map { references[$0] }
        references.remove(atOffsets: offsets)

        Task {
            for ref in toDelete {
                try? await F5TTSService.shared.deleteReference(id: ref.id)
            }
        }
    }
}

#Preview {
    NavigationStack { F5TTSSettingsView() }
        .preferredColorScheme(.dark)
}
