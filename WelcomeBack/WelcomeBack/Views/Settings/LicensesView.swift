import SwiftUI

/// Displays open-source licenses for third-party dependencies.
struct LicensesView: View {

    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        ZStack {
            Color.backgroundDark.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    licenseEntry(
                        name: "llama.cpp",
                        description: "On-device large language model inference engine",
                        url: "https://github.com/ggml-org/llama.cpp",
                        license: llamaCppLicense
                    )
                }
                .padding(24)
            }
        }
        .navigationTitle(lang.t("settings.system.licenses.title"))
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - License Entry

    private func licenseEntry(name: String, description: String, url: String, license: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(name)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.onSurface)

            Text(description)
                .font(.system(size: 14))
                .foregroundColor(.onSurface.opacity(0.6))

            if let link = URL(string: url) {
                Link(url, destination: link)
                    .font(.system(size: 12))
                    .foregroundColor(.accentYellow)
            }

            Text(license)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.onSurface.opacity(0.5))
                .padding(12)
                .background(Color.surfaceVariant.opacity(0.3))
                .cornerRadius(8)
        }
    }

    // MARK: - License Text

    private var llamaCppLicense: String {
        if let url = Bundle.main.url(forResource: "llama-cpp-LICENSE", withExtension: "txt", subdirectory: "LICENSES"),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            return text
        }
        return """
        MIT License

        Copyright (c) 2023-2024 The ggml authors

        Permission is hereby granted, free of charge, to any person obtaining a copy \
        of this software and associated documentation files (the "Software"), to deal \
        in the Software without restriction, including without limitation the rights \
        to use, copy, modify, merge, publish, distribute, sublicense, and/or sell \
        copies of the Software, and to permit persons to whom the Software is \
        furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all \
        copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR \
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, \
        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE \
        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER \
        LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, \
        OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE \
        SOFTWARE.
        """
    }
}
