import SwiftUI

/// Distinct configuration domains presented as dedicated preference panes.
enum SettingsTab: String, CaseIterable, Identifiable {
    case service = "AI Service"
    case languages = "Languages"
    case shortcuts = "Shortcuts"
    case permissions = "Permissions"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .service: return "cpu"
        case .languages: return "character.bubble"
        case .shortcuts: return "keyboard"
        case .permissions: return "lock.shield"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var hotkeyManager: HotkeyManager

    @State private var selectedTab: SettingsTab = .service
    @State private var showApiKey: Bool = false
    @State private var isAccessibilityGranted: Bool = AccessibilityPermissionCoordinator.shared.isTrusted

    var body: some View {
        VStack(spacing: 0) {
            // Segmented Tab Bar Header
            segmentedHeader
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 14)

            Divider()

            // Active Tab Content Pane
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    switch selectedTab {
                    case .service:
                        servicePane
                    case .languages:
                        languagesPane
                    case .shortcuts:
                        shortcutsPane
                    case .permissions:
                        permissionsPane
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 520, height: 430)
        .background(Color(nsColor: .windowBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            isAccessibilityGranted = AccessibilityPermissionCoordinator.shared.isTrusted
        }
    }

    // MARK: - Header Tab Selector

    private var segmentedHeader: some View {
        HStack(spacing: 6) {
            ForEach(SettingsTab.allCases) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = tab
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 13, weight: .medium))
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(TabPillButtonStyle(isSelected: selectedTab == tab))
            }
        }
    }

    // MARK: - Panes

    /// 1. AI Service Configuration Pane
    private var servicePane: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsCard(title: "API Endpoint & Credentials", icon: "network") {
                VStack(spacing: 12) {
                    // Endpoint URL
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Endpoint URL")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        TextField("http://localhost:11434/v1", text: $settings.endpointURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                    }

                    // API Key
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("API Key")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: { showApiKey.toggle() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: showApiKey ? "eye.slash" : "eye")
                                    Text(showApiKey ? "Hide" : "Show")
                                }
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }

                        if showApiKey {
                            TextField("Optional for local models", text: $settings.apiKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))
                        } else {
                            SecureField("Optional for local models", text: $settings.apiKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))
                        }
                    }

                    // Model Identifier
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Model Identifier")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        TextField("e.g. qwen2.5, gpt-4o-mini, gemini-2.5-flash", text: $settings.model)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                    }
                }
            }

            // Informational Note
            infoBanner(
                icon: "info.circle",
                text: "Supports OpenAI-compatible /chat/completions endpoints. The API key is securely encrypted inside the macOS Keychain."
            )
        }
    }

    /// 2. Language Selection Pane
    private var languagesPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsCard(title: "Translation Preferences", icon: "character.bubble.fill") {
                VStack(spacing: 12) {
                    // Target Language
                    HStack {
                        Text("Target Language")
                            .font(.system(size: 12))
                        Spacer()
                        Picker("", selection: $settings.targetLanguage) {
                            ForEach(LanguageCodes.all) { lang in
                                Text(lang.label).tag(lang.code)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 160)
                    }

                    Divider()

                    // Source Mode
                    HStack {
                        Text("Source Detection")
                            .font(.system(size: 12))
                        Spacer()
                        Picker("", selection: $settings.sourceMode) {
                            ForEach(SourceMode.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 160)
                    }

                    // Fixed Source Language (Conditional)
                    if settings.sourceMode == .fixed {
                        Divider()
                        HStack {
                            Text("Fixed Source Language")
                                .font(.system(size: 12))
                            Spacer()
                            Picker("", selection: $settings.sourceLanguage) {
                                ForEach(LanguageCodes.all) { lang in
                                    Text(lang.label).tag(lang.code)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 160)
                        }
                    }
                }
            }

            infoBanner(
                icon: "globe",
                text: "Auto-detect analyzes the selected input language and translates it into your chosen Target Language."
            )
        }
    }

    /// 3. Shortcuts Configuration Pane
    private var shortcutsPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsCard(title: "Global Shortcut Trigger", icon: "keyboard.fill") {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Translate Focused Field")
                            .font(.system(size: 12, weight: .medium))
                        Text("Applies translation directly in the active application")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        // Key Badge
                        Text(settings.hotkey.displayString)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                            )

                        Button(hotkeyManager.isRecording ? "Press keys…" : "Record") {
                            hotkeyManager.beginRecording()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(hotkeyManager.isRecording ? .orange : .accentColor)
                    }
                }
            }

            infoBanner(
                icon: "sparkles",
                text: "Focus on any editable text field in any app, then trigger this hotkey to translate text in-place."
            )
        }
    }

    /// 4. Permissions & System Access Pane
    private var permissionsPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsCard(title: "Accessibility Access", icon: "lock.shield.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Accessibility Permission")
                                .font(.system(size: 12, weight: .medium))
                            Text("Allows Tranz to read and replace text directly in active applications")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // Status Badge
                        HStack(spacing: 5) {
                            Image(systemName: isAccessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(isAccessibilityGranted ? .green : .orange)
                            Text(isAccessibilityGranted ? "Granted" : "Required")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(isAccessibilityGranted ? .green : .orange)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            (isAccessibilityGranted ? Color.green : Color.orange)
                                .opacity(0.12)
                        )
                        .cornerRadius(6)
                    }

                    Divider()

                    HStack {
                        Spacer()
                        Button(action: {
                            AccessibilityPermissionCoordinator.shared.openAccessibilitySettings()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.forward.app")
                                Text("Open System Settings…")
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            infoBanner(
                icon: isAccessibilityGranted ? "hand.thumbsup" : "exclamationmark.circle",
                text: isAccessibilityGranted
                    ? "Accessibility access is verified. Tranz is ready to interact with all apps."
                    : "After toggling Tranz in System Settings → Privacy & Security → Accessibility, relaunch the app for permissions to take effect."
            )
        }
    }

    // MARK: - Reusable Card Components

    private func settingsCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
            }

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 1)
            )
        }
    }

    private func infoBanner(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Custom Tab Pill Button Style

struct TabPillButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isSelected ? .white : .primary)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSelected ? Color.accentColor : (configuration.isPressed ? Color(nsColor: .controlBackgroundColor) : Color.clear))
            )
    }
}
