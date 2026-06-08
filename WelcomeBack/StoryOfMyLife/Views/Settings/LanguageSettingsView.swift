import SwiftUI

struct LanguageSettingsView: View {

    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        ZStack {
            Color.backgroundDark.ignoresSafeArea()

            List {
                Section {
                    ForEach(AppLanguage.allCases) { language in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                lang.language = language
                            }
                        } label: {
                            HStack(spacing: 16) {
                                Text(language.flag)
                                    .font(.system(size: 28))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(language.displayName)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.onSurface)
                                    Text(language == .english ? "English" : "Suomi")
                                        .font(.system(size: 12))
                                        .foregroundColor(.onSurface.opacity(0.5))
                                }

                                Spacer()

                                if lang.language == language {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(.accentYellow)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.surfaceVariant.opacity(0.4))
                        .accessibilityLabel("\(language.flag) \(language.displayName)")
                        .accessibilityAddTraits(lang.language == language ? [.isSelected] : [])
                    }
                } header: {
                    Text(lang.t("languagesettings.subtitle"))
                        .foregroundColor(.onSurface.opacity(0.45))
                        .font(.system(size: 12))
                        .textCase(nil)
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
            .listRowSeparatorTint(Color.white.opacity(0.07))
        }
        .navigationTitle(lang.t("languagesettings.title"))
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        LanguageSettingsView()
            .environmentObject(LanguageManager())
    }
    .preferredColorScheme(.dark)
}
