import Foundation

/// A curated language entry.
struct Language: Identifiable, Hashable {
    let code: String
    let label: String
    var id: String { code }
}

/// The locked top-7 language list (§3.5). Default target = English.
enum LanguageCodes {
    static let all: [Language] = [
        Language(code: "en", label: "English"),
        Language(code: "zh", label: "简体中文"),
        Language(code: "ja", label: "日本語"),
        Language(code: "ko", label: "한국어"),
        Language(code: "es", label: "Español"),
        Language(code: "fr", label: "Français"),
        Language(code: "de", label: "Deutsch")
    ]

    static func label(for code: String) -> String {
        all.first { $0.code == code }?.label ?? code
    }

    static func nextLanguage(after code: String) -> Language {
        guard let currentIndex = all.firstIndex(where: { $0.code == code }) else {
            return all[0]
        }
        let nextIndex = (currentIndex + 1) % all.count
        return all[nextIndex]
    }

    static func previousLanguage(before code: String) -> Language {
        guard let currentIndex = all.firstIndex(where: { $0.code == code }) else {
            return all[0]
        }
        let prevIndex = (currentIndex - 1 + all.count) % all.count
        return all[prevIndex]
    }
}
