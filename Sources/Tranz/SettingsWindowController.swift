import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    private let settings: AppSettings
    private let hotkeyManager: HotkeyManager

    init(settings: AppSettings, hotkeyManager: HotkeyManager) {
        self.settings = settings
        self.hotkeyManager = hotkeyManager

        let view = SettingsView(settings: settings, hotkeyManager: hotkeyManager)
        let hosting = NSHostingController(rootView: view)

        let window = NSWindow(contentViewController: hosting)
        window.title = "Tranz Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 520, height: 430))
        window.minSize = NSSize(width: 520, height: 430)
        window.maxSize = NSSize(width: 520, height: 430)
        window.center()

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
