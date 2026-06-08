import Foundation
import SwiftUI

// MARK: - AppLanguage

enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case english = "en"
    case finnish = "fi"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .finnish: return "Suomi"
        }
    }

    var flag: String {
        switch self {
        case .english: return "🇬🇧"
        case .finnish: return "🇫🇮"
        }
    }

    /// BCP-47 locale identifier for speech recognition (STT) and text-to-speech (TTS).
    var speechLocaleIdentifier: String {
        switch self {
        case .english: return "en-US"
        case .finnish: return "fi-FI"
        }
    }

    /// English name of the language, for embedding in the (English) LLM system prompt.
    var englishName: String {
        switch self {
        case .english: return "English"
        case .finnish: return "Finnish"
        }
    }

    /// Native name of the language, reinforced in the prompt to anchor the model.
    var nativeName: String {
        switch self {
        case .english: return "English"
        case .finnish: return "suomi"
        }
    }
}

// MARK: - LanguageManager

final class LanguageManager: ObservableObject {

    static let shared = LanguageManager()

    private static let storageKey = "app_language"

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey)
        }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey) ?? ""
        language = AppLanguage(rawValue: stored) ?? .english
    }

    /// Returns the localised string for `key` in the current language.
    /// Falls back to the English value, then to the key itself.
    func t(_ key: String) -> String {
        switch language {
        case .english: return Strings.en[key] ?? key
        case .finnish: return Strings.fi[key] ?? Strings.en[key] ?? key
        }
    }

    /// Helper for strings that embed a dynamic value, e.g. `"Hello, %@"`.
    func t(_ key: String, _ arg: CVarArg) -> String {
        String(format: t(key), arg)
    }

    /// Pluralised member / place / memory count strings.
    func memberCount(_ n: Int) -> String {
        switch language {
        case .english: return n == 1 ? "1 member"  : "\(n) members"
        case .finnish: return n == 1 ? "1 jäsen"   : "\(n) jäsentä"
        }
    }

    func placeCount(_ n: Int) -> String {
        switch language {
        case .english: return n == 1 ? "1 place"   : "\(n) places"
        case .finnish: return n == 1 ? "1 paikka"  : "\(n) paikkaa"
        }
    }

    func memoryCount(_ n: Int) -> String {
        switch language {
        case .english: return n == 1 ? "1 memory"  : "\(n) memories"
        case .finnish: return n == 1 ? "1 muisto"  : "\(n) muistoa"
        }
    }
}
