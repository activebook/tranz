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

/// Application configuration, persisted to UserDefaults (API keys live in Keychain per endpoint).
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Keys {
        static let endpoints = "aiEndpoints"
        static let selectedEndpointID = "selectedEndpointID"
        static let targetLanguage = "targetLanguage"
        static let sourceMode = "sourceMode"
        static let sourceLanguage = "sourceLanguage"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyModifiers = "hotkeyModifiers"
        static let hotkeyDisplayName = "hotkeyDisplayName"

        // Legacy single-endpoint keys for migration
        static let legacyEndpoint = "endpoint"
        static let legacyModel = "model"
    }

    @Published var endpoints: [AIEndpoint] {
        didSet { saveEndpoints() }
    }
    @Published var selectedEndpointID: UUID {
        didSet { UserDefaults.standard.set(selectedEndpointID.uuidString, forKey: Keys.selectedEndpointID) }
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
    @Published var hotkey: Hotkey {
        didSet {
            UserDefaults.standard.set(Int(hotkey.keyCode), forKey: Keys.hotkeyKeyCode)
            UserDefaults.standard.set(Int(hotkey.modifiers), forKey: Keys.hotkeyModifiers)
            UserDefaults.standard.set(hotkey.displayName, forKey: Keys.hotkeyDisplayName)
        }
    }

    private init() {
        let defaults = UserDefaults.standard

        targetLanguage = defaults.string(forKey: Keys.targetLanguage) ?? "en"
        sourceMode = SourceMode(rawValue: defaults.string(forKey: Keys.sourceMode) ?? "") ?? .autoDetect
        sourceLanguage = defaults.string(forKey: Keys.sourceLanguage) ?? "en"

        // Hotkey initialization
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

        // AI Endpoints loading & automatic migration
        if let data = defaults.data(forKey: Keys.endpoints),
           let decoded = try? JSONDecoder().decode([AIEndpoint].self, from: data),
           !decoded.isEmpty {
            endpoints = decoded
            if let savedIDString = defaults.string(forKey: Keys.selectedEndpointID),
               let savedID = UUID(uuidString: savedIDString),
               decoded.contains(where: { $0.id == savedID }) {
                selectedEndpointID = savedID
            } else {
                selectedEndpointID = decoded[0].id
            }
        } else if let legacyURL = defaults.string(forKey: Keys.legacyEndpoint),
                  !legacyURL.isEmpty {
            // Migrate legacy single endpoint
            let legacyModel = defaults.string(forKey: Keys.legacyModel) ?? "qwen2.5:7b"
            let initial = AIEndpoint(
                baseURL: legacyURL,
                model: legacyModel
            )
            endpoints = [initial]
            selectedEndpointID = initial.id

            // Migrate legacy Keychain API key
            if let legacyKey = KeychainVault.shared.load() {
                KeychainVault.shared.save(legacyKey, for: initial.id.uuidString)
            }
            if let data = try? JSONEncoder().encode([initial]) {
                defaults.set(data, forKey: Keys.endpoints)
            }
            defaults.set(initial.id.uuidString, forKey: Keys.selectedEndpointID)
        } else {
            // Default initial installation
            let initial = [AIEndpoint.defaultEndpoint]
            endpoints = initial
            selectedEndpointID = initial[0].id
            if let data = try? JSONEncoder().encode(initial) {
                defaults.set(data, forKey: Keys.endpoints)
            }
            defaults.set(initial[0].id.uuidString, forKey: Keys.selectedEndpointID)
        }
    }

    // MARK: - Active Endpoint Resolution

    var activeEndpoint: AIEndpoint? {
        endpoints.first(where: { $0.id == selectedEndpointID }) ?? endpoints.first
    }

    var translatorConfig: TranslatorConfig {
        let ep = activeEndpoint ?? AIEndpoint.defaultEndpoint
        let key = apiKey(for: ep.id)
        return TranslatorConfig(
            baseURL: ep.baseURL,
            apiKey: key.isEmpty ? nil : key,
            model: ep.model,
            targetLanguage: LanguageCodes.label(for: targetLanguage),
            sourceLanguage: sourceMode == .autoDetect
                ? "auto-detect"
                : LanguageCodes.label(for: sourceLanguage)
        )
    }

    var isConfigured: Bool {
        guard let ep = activeEndpoint else { return false }
        return !ep.baseURL.trimmingCharacters(in: .whitespaces).isEmpty
            && !ep.model.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Endpoint Management Helpers

    func selectEndpoint(id: UUID) {
        guard endpoints.contains(where: { $0.id == id }) else { return }
        selectedEndpointID = id
    }

    func addEndpoint(_ endpoint: AIEndpoint, apiKey: String? = nil) {
        endpoints.append(endpoint)
        if let apiKey, !apiKey.isEmpty {
            setApiKey(apiKey, for: endpoint.id)
        }
    }

    func updateEndpoint(_ endpoint: AIEndpoint, apiKey: String? = nil) {
        if let idx = endpoints.firstIndex(where: { $0.id == endpoint.id }) {
            endpoints[idx] = endpoint
            if let apiKey {
                setApiKey(apiKey, for: endpoint.id)
            }
        }
    }

    func removeEndpoint(id: UUID) {
        guard endpoints.count > 1 else { return } // Retain at least one profile
        endpoints.removeAll(where: { $0.id == id })
        KeychainVault.shared.delete(for: id.uuidString)
        if selectedEndpointID == id, let first = endpoints.first {
            selectedEndpointID = first.id
        }
    }

    func apiKey(for endpointID: UUID) -> String {
        KeychainVault.shared.load(for: endpointID.uuidString) ?? ""
    }

    func setApiKey(_ key: String, for endpointID: UUID) {
        KeychainVault.shared.save(key, for: endpointID.uuidString)
    }

    private func saveEndpoints() {
        if let data = try? JSONEncoder().encode(endpoints) {
            UserDefaults.standard.set(data, forKey: Keys.endpoints)
        }
    }
}
