import AppKit
import Carbon
import Combine

extension Notification.Name {
    /// Posted whenever the global hotkey is pressed.
    static let hotkeyPressed = Notification.Name("TranzHotkeyPressed")
}

/// Carbon event-modifier masks (independent of the keyboard layout).
enum ModifierMasks {
    static let command: UInt32 = 0x0100
    static let shift: UInt32 = 0x0200
    static let option: UInt32 = 0x0800
    static let control: UInt32 = 0x1000
}

/// A global shortcut: a physical virtual keycode plus a Carbon modifier mask.
///
/// `displayName` is the character that the key produces (captured at record time),
/// used only for the settings UI. RegisterEventHotKey matches the physical keycode,
/// so the shortcut itself is layout-independent.
struct Hotkey: Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var displayName: String

    /// Default shortcut: Option+T (kVK_ANSI_T == 0x11).
    static let `default` = Hotkey(keyCode: 0x11, modifiers: ModifierMasks.option, displayName: "T")

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

/// Registers a system-wide hotkey via Carbon `RegisterEventHotKey`.
///
/// Unlike a global `NSEvent` monitor, RegisterEventHotKey *consumes* the key
/// combination, so Option+T is never typed into the focused field.
final class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()

    @Published private(set) var isRecording = false

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var recordMonitor: Any?

    private let hotKeyID = EventHotKeyID(signature: 0x5452_4E5A, id: 1) // "TRNZ"

    private init() {}

    func register(with hotkey: Hotkey) {
        unregister()
        installEventHandlerIfNeeded()
        let status = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status != noErr {
            NSLog("Tranz: RegisterEventHotKey failed with OSStatus \(status)")
        }
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    // MARK: - Recording (settings UI)

    func beginRecording() {
        guard !isRecording else { return }
        isRecording = true
        recordMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.finishRecording(with: event)
            return nil // consume the key while recording
        }
    }

    private func finishRecording(with event: NSEvent) {
        guard isRecording else { return }
        isRecording = false
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
        AppSettings.shared.hotkey = Hotkey(keyCode: keyCode, modifiers: modifiers, displayName: displayName)
        register(with: AppSettings.shared.hotkey)
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
        NotificationCenter.default.post(name: .hotkeyPressed, object: nil)
    }
    return noErr
}
