import CoreGraphics

/// Low-level synthetic key events (US virtual keycodes).
///
/// Posting to `.cghidEventTap` delivers the events system-wide to the frontmost
/// app. Requires the app to be a trusted Accessibility client.
enum KeySimulator {
    static func press(keyCode: CGKeyCode, flags: CGEventFlags) {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        down?.flags = flags
        up?.flags = flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    /// kVK_ANSI_A == 0x00
    static func selectAll() { press(keyCode: 0x00, flags: .maskCommand) }

    /// kVK_ANSI_C == 0x08
    static func copy() { press(keyCode: 0x08, flags: .maskCommand) }

    /// kVK_ANSI_V == 0x09
    static func paste() { press(keyCode: 0x09, flags: .maskCommand) }
}
