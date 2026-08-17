import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let settings = AppSettings.shared
    private let hotkeyManager = HotkeyManager.shared
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        setupMenuBar()
        hotkeyManager.register(with: settings.hotkey)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHotkey),
            name: .hotkeyPressed,
            object: nil
        )
        // Prompt for Accessibility permission on first launch (needed to post
        // the synthetic Cmd+A / Cmd+C / Cmd+V events).
        AccessibilityPermissionCoordinator.shared.requestIfNeeded()
    }

    // MARK: - Main menu

    /// A minimal main menu is required so that Cmd+C / Cmd+V / Cmd+X / Cmd+A work
    /// inside the settings window's text fields. A menu-bar (LSUIElement) app has no
    /// visible menu bar, but key equivalents are still dispatched through `mainMenu`.
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(
            NSMenuItem(
                title: "Quit Tranz",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )
        appMenuItem.submenu = appMenu

        // Edit menu — provides the standard clipboard/undo shortcuts to text fields
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: NSSelectorFromString("undo:"), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: NSSelectorFromString("redo:"), keyEquivalent: "Z"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: NSSelectorFromString("cut:"), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: NSSelectorFromString("copy:"), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: NSSelectorFromString("paste:"), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: NSSelectorFromString("selectAll:"), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Menu bar

    private var modelsSubmenu: NSMenu?

    private func setupMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            if let icon = NSImage(named: "menuBarIcon") {
                icon.isTemplate = true
                button.image = icon
            } else {
                // Fallback if the custom icon isn't bundled.
                button.image = NSImage(
                    systemSymbolName: "character.bubble.fill",
                    accessibilityDescription: "Tranz"
                )
            }
        }

        let menu = NSMenu()
        menu.delegate = self

        let translateItem = NSMenuItem(
            title: "Translate Focused Field",
            action: #selector(translateNow),
            keyEquivalent: ""
        )
        translateItem.target = self
        menu.addItem(translateItem)

        menu.addItem(.separator())

        // Active AI Service Quick-Switcher Submenu
        let modelsMenuItem = NSMenuItem(
            title: "Active AI Service",
            action: nil,
            keyEquivalent: ""
        )
        let subMenu = NSMenu(title: "Active AI Service")
        subMenu.delegate = self
        modelsMenuItem.submenu = subMenu
        menu.addItem(modelsMenuItem)
        self.modelsSubmenu = subMenu

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Tranz",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }

    // MARK: - Actions

    @objc private func translateNow() {
        TranslationCoordinator.shared.performTranslation()
    }

    @objc private func handleHotkey() {
        TranslationCoordinator.shared.performTranslation()
    }

    @objc private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                settings: settings,
                hotkeyManager: hotkeyManager
            )
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func didSelectEndpointMenuItem(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? UUID {
            settings.selectEndpoint(id: id)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

// MARK: - NSMenuDelegate for Dynamic Submenus

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu == modelsSubmenu {
            guard let submenu = modelsSubmenu else { return }
            submenu.removeAllItems()

            let endpoints = settings.endpoints
            let activeID = settings.selectedEndpointID

            for endpoint in endpoints {
                let item = NSMenuItem(
                    title: endpoint.displayName,
                    action: #selector(didSelectEndpointMenuItem(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = endpoint.id
                item.state = (endpoint.id == activeID) ? .on : .off
                submenu.addItem(item)
            }
        }
    }
}
