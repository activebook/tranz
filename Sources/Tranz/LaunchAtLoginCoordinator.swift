import AppKit
import Combine
import Foundation
import ServiceManagement

/// Coordinates macOS Login Item registration via the modern ServiceManagement framework (macOS 13.0+).
final class LaunchAtLoginCoordinator: ObservableObject {
    static let shared = LaunchAtLoginCoordinator()

    @Published private(set) var isEnabled: Bool = false
    @Published private(set) var status: SMAppService.Status = .notRegistered

    private init() {
        refreshStatus()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func handleAppDidBecomeActive() {
        refreshStatus()
    }

    /// Queries the live registration status from macOS ServiceManagement.
    func refreshStatus() {
        let currentStatus = SMAppService.mainApp.status
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.status = currentStatus
            self.isEnabled = (currentStatus == .enabled)
        }
    }

    /// Registers or unregisters the application as a background login item.
    @discardableResult
    func setLaunchAtLogin(enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status == .enabled {
                    refreshStatus()
                    return true
                }
                try SMAppService.mainApp.register()
            } else {
                if SMAppService.mainApp.status != .enabled {
                    refreshStatus()
                    return true
                }
                try SMAppService.mainApp.unregister()
            }
            refreshStatus()
            return true
        } catch {
            NSLog("Tranz: Failed to update Launch at Login state: \(error.localizedDescription)")
            refreshStatus()
            return false
        }
    }

    /// Opens macOS System Settings -> General -> Login Items & Extensions.
    func openLoginItemsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
