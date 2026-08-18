import SwiftUI

/// Distinct configuration domains presented as dedicated preference panes.
enum SettingsTab: String, CaseIterable, Identifiable {
    case service = "AI Service"
    case languages = "Languages"
    case shortcuts = "Shortcuts"
    case permissions = "System"
    case debug = "Debug"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .service: return "cpu"
        case .languages: return "character.bubble"
        case .shortcuts: return "keyboard"
        case .permissions: return "gearshape.2"
        case .debug: return "ladybug"
        }
    }
}

/// Shared navigation coordinator for selecting active settings pane.
final class SettingsNavigationState: ObservableObject {
    static let shared = SettingsNavigationState()
    @Published var selectedTab: SettingsTab = .service
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var hotkeyManager: HotkeyManager
    @ObservedObject private var navState = SettingsNavigationState.shared
    @ObservedObject private var updateCoordinator = UpdateCoordinator.shared

    @State private var editingEndpointID: UUID?
    @State private var editedURL: String = ""
    @State private var editedModel: String = ""
    @State private var editedApiKey: String = ""
    @State private var showApiKey: Bool = false
    @ObservedObject private var accessibilityCoordinator = AccessibilityPermissionCoordinator.shared
    @ObservedObject private var launchCoordinator = LaunchAtLoginCoordinator.shared

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
                    switch navState.selectedTab {
                    case .service:
                        servicePane
                    case .languages:
                        languagesPane
                    case .shortcuts:
                        shortcutsPane
                    case .permissions:
                        systemPane
                    case .debug:
                        debugPane
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 580, height: 500)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            syncEditingEndpoint()
            accessibilityCoordinator.refreshStatus()
            launchCoordinator.refreshStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            accessibilityCoordinator.refreshStatus()
            launchCoordinator.refreshStatus()
        }
    }

    // MARK: - Header Tab Selector

    private var segmentedHeader: some View {
        HStack(spacing: 6) {
            ForEach(SettingsTab.allCases) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        navState.selectedTab = tab
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 13, weight: .medium))
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: navState.selectedTab == tab ? .semibold : .regular))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(TabPillButtonStyle(isSelected: navState.selectedTab == tab))
            }
        }
    }

    // MARK: - Panes

    /// 1. Multi-Endpoint AI Service Configuration Pane
    private var servicePane: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Endpoint List Selector Card
            settingsCard(title: "Configured AI Endpoints", icon: "server.rack") {
                VStack(spacing: 8) {
                    ForEach(settings.endpoints) { endpoint in
                        endpointRow(endpoint)
                    }

                    Divider()
                        .padding(.vertical, 2)

                    // Toolbar actions: Add Endpoint Button
                    HStack {
                        Button(action: addNewEndpoint) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Endpoint")
                            }
                            .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(.borderless)

                        Spacer()
                    }
                }
            }

            // Profile Detail Editor Card
            if let currentID = editingEndpointID,
               let endpoint = settings.endpoints.first(where: { $0.id == currentID }) {
                settingsCard(title: "Configure: \(endpoint.displayName)", icon: "slider.horizontal.3") {
                    VStack(spacing: 12) {
                        // Endpoint URL
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Endpoint Base URL")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            TextField("http://localhost:11434/v1", text: $editedURL)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))
                                .onChange(of: editedURL) { _ in persistCurrentEdit() }
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
                                TextField("Optional for local models", text: $editedApiKey)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 12))
                                    .onChange(of: editedApiKey) { _ in persistCurrentEdit() }
                            } else {
                                SecureField("Optional for local models", text: $editedApiKey)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 12))
                                    .onChange(of: editedApiKey) { _ in persistCurrentEdit() }
                            }
                        }

                        // Model Identifier
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Model Identifier")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            TextField("e.g. qwen3.6, gemma4, gpt-5.6-terra, claude-sonnet-5", text: $editedModel)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))
                                .onChange(of: editedModel) { _ in persistCurrentEdit() }
                        }

                        Divider()

                        // Action Bar: Set Active & Delete
                        HStack {
                            if settings.selectedEndpointID != currentID {
                                Button(action: {
                                    settings.selectEndpoint(id: currentID)
                                }) {
                                    HStack(spacing: 5) {
                                        Image(systemName: "checkmark.circle")
                                        Text("Set as Active Service")
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            } else {
                                HStack(spacing: 5) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Active Translation Service")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.green)
                                }
                            }

                            Spacer()

                            if settings.endpoints.count > 1 {
                                Button(role: .destructive, action: {
                                    settings.removeEndpoint(id: currentID)
                                    syncEditingEndpoint()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "trash")
                                        Text("Delete")
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }
            }

            // Informational Note
            infoBanner(
                icon: "lock.shield",
                text: "API keys are securely isolated in the macOS Keychain for each endpoint. Switch active services anytime here or from the Menu Bar."
            )
        }
    }

    private func endpointRow(_ endpoint: AIEndpoint) -> some View {
        let isSelectedForEdit = editingEndpointID == endpoint.id
        let isActive = settings.selectedEndpointID == endpoint.id

        return HStack(spacing: 10) {
            // Radio / Checkmark selector button
            Button(action: {
                settings.selectEndpoint(id: endpoint.id)
                selectForEdit(endpoint)
            }) {
                Image(systemName: isActive ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isActive ? .accentColor : .secondary)
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)

            // Endpoint details
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(endpoint.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)

                    if isActive {
                        Text("ACTIVE")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.green)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Capsule().fill(Color.green.opacity(0.15)))
                    }
                }

                Text(endpoint.baseURL)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Select to edit button / indicator
            Button(action: {
                selectForEdit(endpoint)
            }) {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                    .foregroundColor(isSelectedForEdit ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelectedForEdit ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectForEdit(endpoint)
        }
    }

    private func selectForEdit(_ endpoint: AIEndpoint) {
        editingEndpointID = endpoint.id
        editedURL = endpoint.baseURL
        editedModel = endpoint.model
        editedApiKey = settings.apiKey(for: endpoint.id)
    }

    private func syncEditingEndpoint() {
        if let current = settings.activeEndpoint {
            selectForEdit(current)
        }
    }

    private func persistCurrentEdit() {
        guard let id = editingEndpointID else { return }
        let updated = AIEndpoint(
            id: id,
            baseURL: editedURL.trimmingCharacters(in: .whitespaces),
            model: editedModel.trimmingCharacters(in: .whitespaces)
        )
        settings.updateEndpoint(updated, apiKey: editedApiKey)
    }

    private func addNewEndpoint() {
        let newEndpoint = AIEndpoint(baseURL: "http://localhost:11434/v1", model: "qwen3.6")
        settings.addEndpoint(newEndpoint)
        selectForEdit(newEndpoint)
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
                text: "Auto-detect analyzes the selected input language and translates it into your chosen Target Language. Press ⌥] or ⌥[ anywhere to cycle target languages on the fly."
            )
        }
    }

    /// 3. Shortcuts Configuration Pane
    private var shortcutsPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsCard(title: "Global Shortcuts", icon: "keyboard.fill") {
                VStack(spacing: 12) {
                    shortcutRow(
                        title: "Translate Focused Field",
                        subtitle: "Translate text in the current field of any app",
                        hotkey: settings.hotkey,
                        role: .translate
                    )

                    Divider()

                    shortcutRow(
                        title: "Next Target Language",
                        subtitle: "Switch to the next language in the list",
                        hotkey: settings.nextLanguageHotkey,
                        role: .nextLanguage
                    )

                    Divider()

                    shortcutRow(
                        title: "Previous Target Language",
                        subtitle: "Switch to the previous language in the list",
                        hotkey: settings.previousLanguageHotkey,
                        role: .previousLanguage
                    )
                }
            }

            infoBanner(
                icon: "sparkles",
                text: "Global shortcuts operate across all applications. Press Record, then press your desired key combination with at least one modifier."
            )
        }
    }

    private func shortcutRow(
        title: String,
        subtitle: String,
        hotkey: Hotkey,
        role: HotkeyRole
    ) -> some View {
        let isRecordingThis = hotkeyManager.recordingRole == role

        return HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Text(hotkey.displayString)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )

                Button(isRecordingThis ? "Press keys…" : "Record") {
                    if isRecordingThis {
                        hotkeyManager.cancelRecording()
                    } else {
                        hotkeyManager.beginRecording(for: role)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(isRecordingThis ? .orange : .accentColor)
                .controlSize(.small)
            }
        }
    }

    /// 4. System Integration & Permissions Pane
    private var systemPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Launch at Login Card
            settingsCard(title: "Startup Behavior", icon: "power") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Launch at Login")
                                .font(.system(size: 12, weight: .medium))
                            Text("Automatically start Tranz in the background when you log in")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { launchCoordinator.isEnabled },
                            set: { newValue in
                                _ = launchCoordinator.setLaunchAtLogin(enabled: newValue)
                            }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    }

                    Divider()

                    HStack {
                        // Status Badge
                        HStack(spacing: 5) {
                            let status = launchCoordinator.status
                            Image(systemName: status == .enabled ? "checkmark.circle.fill" : (status == .requiresApproval ? "exclamationmark.triangle.fill" : "circle"))
                                .foregroundColor(status == .enabled ? .green : (status == .requiresApproval ? .orange : .secondary))
                            Text(status == .enabled ? "Enabled" : (status == .requiresApproval ? "Approval Required" : "Disabled"))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(status == .enabled ? .green : (status == .requiresApproval ? .orange : .secondary))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            (launchCoordinator.status == .enabled ? Color.green : (launchCoordinator.status == .requiresApproval ? Color.orange : Color.secondary))
                                .opacity(0.12)
                        )
                        .cornerRadius(6)

                        Spacer()

                        Button(action: {
                            launchCoordinator.openLoginItemsSettings()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.forward.app")
                                Text("Login Items Settings…")
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            // Accessibility Permission Card
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
                            Image(systemName: accessibilityCoordinator.isTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(accessibilityCoordinator.isTrusted ? .green : .orange)
                            Text(accessibilityCoordinator.isTrusted ? "Granted" : "Required")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(accessibilityCoordinator.isTrusted ? .green : .orange)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            (accessibilityCoordinator.isTrusted ? Color.green : Color.orange)
                                .opacity(0.12)
                        )
                        .cornerRadius(6)
                    }

                    if !accessibilityCoordinator.isTrusted {
                        Text("Note: macOS requires restarting Tranz after enabling Accessibility in System Settings for changes to take effect.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
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

            // Software Updates Card
            settingsCard(title: "Software Updates", icon: "arrow.triangle.2.circlepath.circle.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text("Current Version")
                                    .font(.system(size: 12, weight: .medium))
                                Text("v\(updateCoordinator.currentVersionString)")
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(nsColor: .controlBackgroundColor))
                                    .cornerRadius(4)
                            }
                            if let lastChecked = updateCoordinator.lastCheckedDate {
                                Text("Last checked: \(lastChecked.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Check GitHub Releases for the latest application binary")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        // Action Button depending on state
                        switch updateCoordinator.state {
                        case .checking:
                            ProgressView()
                                .controlSize(.small)
                        case .idle, .upToDate:
                            Button(action: {
                                updateCoordinator.checkForUpdates(isUserInitiated: true)
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Check for Updates")
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        case let .updateAvailable(version, _, _, _, _, _):
                            Button(action: {
                                updateCoordinator.downloadAndPrepareUpdate()
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "arrow.down.circle.fill")
                                    Text("Update to v\(version)")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        case .downloading:
                            EmptyView()
                        case .verifying:
                            ProgressView()
                                .controlSize(.small)
                        case .readyToRestart:
                            Button(action: {
                                updateCoordinator.installAndRelaunch()
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "arrow.clockwise.circle.fill")
                                    Text("Restart & Install")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .controlSize(.small)
                        case .failed:
                            Button(action: {
                                updateCoordinator.checkForUpdates(isUserInitiated: true)
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Retry")
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    // Progress / Detailed Status Sections
                    switch updateCoordinator.state {
                    case .checking:
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Connecting to GitHub Releases API…")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 2)

                    case let .upToDate(version):
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Tranz is up to date (v\(version))")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.green)
                        }
                        .padding(.top, 2)

                    case let .updateAvailable(version, releaseNotes, htmlURL, _, _, _):
                        VStack(alignment: .leading, spacing: 8) {
                            Divider()
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.accentColor)
                                Text("New version available: v\(version)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.primary)
                                Spacer()
                                Link(destination: htmlURL) {
                                    HStack(spacing: 3) {
                                        Text("Release Notes")
                                        Image(systemName: "arrow.up.forward")
                                    }
                                    .font(.system(size: 11))
                                }
                            }
                            if !releaseNotes.isEmpty {
                                Text(releaseNotes)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(3)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                                    .cornerRadius(6)
                            }
                        }

                    case let .downloading(progress, written, total):
                        VStack(alignment: .leading, spacing: 6) {
                            Divider()
                            HStack {
                                Text("Downloading update…")
                                    .font(.system(size: 11, weight: .medium))
                                Spacer()
                                Text(String(format: "%.1f MB / %.1f MB (%.0f%%)", Double(written) / (1024 * 1024), Double(total) / (1024 * 1024), progress * 100))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            ProgressView(value: progress, total: 1.0)
                                .progressViewStyle(.linear)
                        }

                    case .verifying:
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Verifying SHA-256 cryptographic signature and staging binary…")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 2)

                    case .readyToRestart:
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            Text("Update downloaded and verified. Click 'Restart & Install' to apply.")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.green)
                        }
                        .padding(.top, 2)

                    case let .failed(error):
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.system(size: 11))
                                .foregroundColor(.red)
                        }
                        .padding(.top, 2)

                    case .idle:
                        EmptyView()
                    }
                }
            }

            infoBanner(
                icon: accessibilityCoordinator.isTrusted ? "hand.thumbsup" : "exclamationmark.circle",
                text: accessibilityCoordinator.isTrusted
                    ? "Accessibility access is verified. Tranz is ready to interact with all apps."
                    : "After toggling Tranz in System Settings → Privacy & Security → Accessibility, relaunch the app for permissions to take effect."
            )
        }
    }

    // MARK: - Debug Pane

    private var debugPane: some View {
        VStack(spacing: 16) {
            settingsCard(title: "Reasoning & Output Diagnostics", icon: "ladybug.fill") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Preserve Raw Model Output")
                                .font(.system(size: 13, weight: .medium))
                            Text("When enabled, bypasses reasoning tag filters (<think>, <thought>) and outputs unedited raw model responses directly.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Toggle("", isOn: $settings.rawModelOutputEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    Divider()

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: settings.rawModelOutputEnabled ? "exclamationmark.triangle.fill" : "checkmark.shield.fill")
                            .foregroundColor(settings.rawModelOutputEnabled ? .orange : .green)
                            .font(.system(size: 12))
                            .padding(.top, 1)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(settings.rawModelOutputEnabled
                                 ? "Raw Mode Active: Internal chain-of-thought tokens from models like DeepSeek-R1 or QwQ will appear directly in target text fields."
                                 : "Filtering Active (Default): Internal <think> scratchpads are automatically stripped, ensuring only the pure translated result is written.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            infoBanner(
                icon: "info.circle",
                text: "Use Debug mode to inspect model reasoning tokens, troubleshoot custom prompt templates, or diagnose API provider behaviors."
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
