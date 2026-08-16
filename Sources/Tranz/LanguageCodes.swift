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
}
