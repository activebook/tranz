import AppKit
import ApplicationServices

/// Detects and requests the macOS Accessibility (TCC) permission.
///
/// Posting synthetic key events (`CGEvent.post`) to other apps requires the app to
/// be a trusted Accessibility client. Note that macOS applies the permission only
/// after the app is relaunched.
final class AccessibilityPermissionCoordinator {
    static let shared = AccessibilityPermissionCoordinator()

    private init() {}

    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Returns true if already trusted; otherwise prompts the system dialog once.
    @discardableResult
    func requestIfNeeded() -> Bool {
        if AXIsProcessTrusted() { return true }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Opens the Accessibility pane in System Settings for a manual grant.
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
