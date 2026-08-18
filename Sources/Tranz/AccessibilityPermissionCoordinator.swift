import AppKit
import ApplicationServices

/// Detects and requests the macOS Accessibility (TCC) permission.
///
/// Posting synthetic key events (`CGEvent.post`) to other apps requires the app to
/// be a trusted Accessibility client. Note that macOS applies the permission only
/// after the app is relaunched.
final class AccessibilityPermissionCoordinator: ObservableObject {
    static let shared = AccessibilityPermissionCoordinator()

    @Published private(set) var isTrusted: Bool = AXIsProcessTrusted()

    private init() {
        refreshStatus()
    }

    /// Re-evaluates whether the current process is a trusted accessibility client.
    @discardableResult
    func refreshStatus() -> Bool {
        let trusted = AXIsProcessTrusted()
        DispatchQueue.main.async {
            self.isTrusted = trusted
        }
        return trusted
    }

    /// Returns true if already trusted; otherwise prompts the system dialog once.
    @discardableResult
    func requestIfNeeded() -> Bool {
        if AXIsProcessTrusted() {
            refreshStatus()
            return true
        }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let result = AXIsProcessTrustedWithOptions(options)
        refreshStatus()
        return result
    }

    /// Opens the Accessibility pane in System Settings for a manual grant.
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
