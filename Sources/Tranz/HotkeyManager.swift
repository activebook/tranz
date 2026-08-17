import AppKit
import Carbon
import Combine

extension Notification.Name {
    /// Posted whenever the translation global hotkey is pressed.
    static let hotkeyPressed = Notification.Name("TranzHotkeyPressed")
    /// Posted whenever the next target language shortcut is pressed.
    static let nextLanguageHotkeyPressed = Notification.Name("TranzNextLanguageHotkeyPressed")
    /// Posted whenever the previous target language shortcut is pressed.
    static let previousLanguageHotkeyPressed = Notification.Name("TranzPreviousLanguageHotkeyPressed")
}

/// Carbon event-modifier masks (independent of the keyboard layout).
enum ModifierMasks {
    static let command: UInt32 = 0x0100
    static let shift: UInt32 = 0x0200
    static let option: UInt32 = 0x0800
    static let control: UInt32 = 0x1000
}

/// A global shortcut: a physical virtual keycode plus a Carbon modifier mask.
struct Hotkey: Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var displayName: String

    /// Default shortcut: Option+T (kVK_ANSI_T == 0x11).
    static let `default` = Hotkey(keyCode: 0x11, modifiers: ModifierMasks.option, displayName: "T")

    /// Default next language shortcut: Option+] (kVK_ANSI_RightBracket == 0x1E).
    static let defaultNext = Hotkey(keyCode: 0x1E, modifiers: ModifierMasks.option, displayName: "]")

    /// Default previous language shortcut: Option+[ (kVK_ANSI_LeftBracket == 0x21).
    static let defaultPrev = Hotkey(keyCode: 0x21, modifiers: ModifierMasks.option, displayName: "[")

    var displayString: String {
        var s = ""
        if modifiers & ModifierMasks.control != 0 { s += "⌃" }
        if modifiers & ModifierMasks.option != 0 { s += "⌥" }
        if modifiers & ModifierMasks.shift != 0 { s += "⇧" }
        if modifiers & ModifierMasks.command != 0 { s += "⌘" }
        s += displayName
        return s
    }
}

/// Identifies the distinct operational roles assigned to global hotkeys.
enum HotkeyRole: String, CaseIterable, Identifiable {
    case translate
    case nextLanguage
    case previousLanguage

    var id: String { rawValue }

    var hotKeyID: UInt32 {
        switch self {
        case .translate: return 1
        case .nextLanguage: return 2
        case .previousLanguage: return 3
        }
    }
}

/// Registers and manages system-wide shortcuts via Carbon `RegisterEventHotKey`.
final class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()

    @Published private(set) var recordingRole: HotkeyRole? = nil

    var isRecording: Bool { recordingRole != nil }

    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var eventHandlerRef: EventHandlerRef?
    private var recordMonitor: Any?

    private let signature: OSType = 0x5452_4E5A // "TRNZ"

    private init() {}

    func registerAll() {
        unregisterAll()
        installEventHandlerIfNeeded()
        let settings = AppSettings.shared
        register(role: .translate, with: settings.hotkey)
        register(role: .nextLanguage, with: settings.nextLanguageHotkey)
        register(role: .previousLanguage, with: settings.previousLanguageHotkey)
    }

    func register(role: HotkeyRole, with hotkey: Hotkey) {
        unregister(role: role)
        installEventHandlerIfNeeded()
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: signature, id: role.hotKeyID)
        let status = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr, let ref {
            hotKeyRefs[role.hotKeyID] = ref
        } else {
            NSLog("Tranz: RegisterEventHotKey for \(role) failed with OSStatus \(status)")
        }
    }

    /// Legacy compatibility bridge
    func register(with hotkey: Hotkey) {
        register(role: .translate, with: hotkey)
    }

    func unregister(role: HotkeyRole) {
        if let ref = hotKeyRefs[role.hotKeyID] {
            UnregisterEventHotKey(ref)
            hotKeyRefs.removeValue(forKey: role.hotKeyID)
        }
    }

    func unregister() {
        unregister(role: .translate)
    }

    func unregisterAll() {
        for (_, ref) in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
    }

    // MARK: - Recording (settings UI)

    func beginRecording(for role: HotkeyRole = .translate) {
        guard recordingRole == nil else { return }
        recordingRole = role
        recordMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.finishRecording(with: event)
            return nil // consume the key while recording
        }
    }

    func cancelRecording() {
        guard recordingRole != nil else { return }
        recordingRole = nil
        if let monitor = recordMonitor {
            NSEvent.removeMonitor(monitor)
            recordMonitor = nil
        }
    }

    private func finishRecording(with event: NSEvent) {
        guard let role = recordingRole else { return }
        recordingRole = nil
        if let monitor = recordMonitor {
            NSEvent.removeMonitor(monitor)
            recordMonitor = nil
        }

        let keyCode = UInt32(event.keyCode)
        let modifiers = Self.carbonModifiers(from: event.modifierFlags)
        // Require at least one modifier; a bare letter would shadow typing.
        guard keyCode != 0, modifiers != 0 else { return }

        let name = (event.charactersIgnoringModifiers ?? "").uppercased()
        let displayName = name.isEmpty ? "Key\(keyCode)" : name
        let hotkey = Hotkey(keyCode: keyCode, modifiers: modifiers, displayName: displayName)

        let settings = AppSettings.shared
        switch role {
        case .translate:
            settings.hotkey = hotkey
        case .nextLanguage:
            settings.nextLanguageHotkey = hotkey
        case .previousLanguage:
            settings.previousLanguageHotkey = hotkey
        }
        register(role: role, with: hotkey)
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= ModifierMasks.command }
        if flags.contains(.option) { result |= ModifierMasks.option }
        if flags.contains(.shift) { result |= ModifierMasks.shift }
        if flags.contains(.control) { result |= ModifierMasks.control }
        return result
    }

    // MARK: - Carbon event plumbing

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyEventHandler,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )
    }
}

/// Non-capturing C callback (required for `EventHandlerUPP`).
private func hotkeyEventHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event else { return noErr }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    if status == noErr {
        if hotKeyID.id == 1 {
            NotificationCenter.default.post(name: .hotkeyPressed, object: nil)
        } else if hotKeyID.id == 2 {
            NotificationCenter.default.post(name: .nextLanguageHotkeyPressed, object: nil)
        } else if hotKeyID.id == 3 {
            NotificationCenter.default.post(name: .previousLanguageHotkeyPressed, object: nil)
        }
    }
    return noErr
}
