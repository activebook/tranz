import Combine
import Foundation

enum SourceMode: String, CaseIterable, Identifiable {
    case autoDetect = "auto-detect"
    case fixed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .autoDetect: return "Auto-detect"
        case .fixed: return "Fixed language"
        }
    }
}

/// Application configuration, persisted to UserDefaults (API key lives in Keychain).
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Keys {
        static let endpoint = "endpoint"
        static let model = "model"
        static let targetLanguage = "targetLanguage"
        static let sourceMode = "sourceMode"
        static let sourceLanguage = "sourceLanguage"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyModifiers = "hotkeyModifiers"
        static let hotkeyDisplayName = "hotkeyDisplayName"
    }

    @Published var endpointURL: String {
        didSet { UserDefaults.standard.set(endpointURL, forKey: Keys.endpoint) }
    }
    @Published var model: String {
        didSet { UserDefaults.standard.set(model, forKey: Keys.model) }
    }
    @Published var targetLanguage: String {
        didSet { UserDefaults.standard.set(targetLanguage, forKey: Keys.targetLanguage) }
    }
    @Published var sourceMode: SourceMode {
        didSet { UserDefaults.standard.set(sourceMode.rawValue, forKey: Keys.sourceMode) }
    }
    @Published var sourceLanguage: String {
        didSet { UserDefaults.standard.set(sourceLanguage, forKey: Keys.sourceLanguage) }
    }
    @Published var apiKey: String {
        didSet { KeychainVault.shared.save(apiKey) }
    }
    @Published var hotkey: Hotkey {
        didSet {
            UserDefaults.standard.set(Int(hotkey.keyCode), forKey: Keys.hotkeyKeyCode)
            UserDefaults.standard.set(Int(hotkey.modifiers), forKey: Keys.hotkeyModifiers)
            UserDefaults.standard.set(hotkey.displayName, forKey: Keys.hotkeyDisplayName)
        }
    }

    private init() {
        let defaults = UserDefaults.standard

        endpointURL = defaults.string(forKey: Keys.endpoint) ?? "http://localhost:11434/v1"
        model = defaults.string(forKey: Keys.model) ?? ""
        targetLanguage = defaults.string(forKey: Keys.targetLanguage) ?? "en"
        sourceMode = SourceMode(rawValue: defaults.string(forKey: Keys.sourceMode) ?? "") ?? .autoDetect
        sourceLanguage = defaults.string(forKey: Keys.sourceLanguage) ?? "en"
        apiKey = KeychainVault.shared.load() ?? ""

        let keyCode = UInt32(defaults.integer(forKey: Keys.hotkeyKeyCode))
        let modifiers = UInt32(defaults.integer(forKey: Keys.hotkeyModifiers))
        let displayName = defaults.string(forKey: Keys.hotkeyDisplayName)
        if keyCode == 0 && modifiers == 0 {
            hotkey = .default
        } else {
            hotkey = Hotkey(
                keyCode: keyCode,
                modifiers: modifiers,
                displayName: (displayName?.isEmpty == false) ? displayName! : "Key\(keyCode)"
            )
        }
    }

    var translatorConfig: TranslatorConfig {
        TranslatorConfig(
            baseURL: endpointURL,
            apiKey: apiKey.isEmpty ? nil : apiKey,
            model: model,
            targetLanguage: LanguageCodes.label(for: targetLanguage),
            sourceLanguage: sourceMode == .autoDetect
                ? "auto-detect"
                : LanguageCodes.label(for: sourceLanguage)
        )
    }

    var isConfigured: Bool {
        !endpointURL.trimmingCharacters(in: .whitespaces).isEmpty
            && !model.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
