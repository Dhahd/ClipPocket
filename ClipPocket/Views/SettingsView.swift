import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    @EnvironmentObject var appDelegate: AppDelegate
    @State private var showClearHistoryAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // General Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("General")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        VStack(spacing: 16) {
                            SettingRow(
                                title: "Launch at Login",
                                description: "Start ClipPocket automatically when you log in",
                                toggle: Binding(
                                    get: { settingsManager.launchAtLogin },
                                    set: { newValue in
                                        settingsManager.launchAtLogin = newValue
                                        setLaunchAtLogin(newValue)
                                    }
                                )
                            )

                            SettingRow(
                                title: "Remember History",
                                description: "Store clipboard items between sessions",
                                toggle: Binding(
                                    get: { settingsManager.rememberHistory },
                                    set: { newValue in
                                        settingsManager.rememberHistory = newValue
                                        if newValue {
                                            appDelegate.loadPersistedClipboardHistory()
                                        }
                                    }
                                )
                            )

                            SettingRow(
                                title: "Auto Paste on Selection",
                                description: "Immediately paste the copied item after selection",
                                toggle: $settingsManager.autoPasteEnabled
                            )
                        }
                    }

                    Divider()

                    // Keyboard Shortcut Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Keyboard Shortcut")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Click to record a new shortcut")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)

                            ShortcutRecorder(shortcut: Binding(
                                get: { settingsManager.keyboardShortcut },
                                set: { newShortcut in
                                    settingsManager.keyboardShortcut = newShortcut
                                }
                            ))
                        }
                    }

                    Divider()

                    // Data Management Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Data Management")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        VStack(spacing: 12) {
                            // Enable history limit toggle
                            SettingRow(
                                title: "Limit History Size",
                                description: "Automatically remove old items to save storage",
                                toggle: $settingsManager.enableHistoryLimit
                            )

                            // Maximum items setting (only shown when limit is enabled)
                            if settingsManager.enableHistoryLimit {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(alignment: .center, spacing: 16) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Maximum History Items")
                                                .font(.system(size: 14, weight: .medium))
                                            Text("Keep up to \(settingsManager.maxHistoryItems) items in history")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Stepper(
                                            value: $settingsManager.maxHistoryItems,
                                            in: 10...1000,
                                            step: 10
                                        ) {
                                            Text("\(settingsManager.maxHistoryItems)")
                                                .font(.system(size: 14, weight: .medium))
                                                .frame(minWidth: 50)
                                        }
                                    }
                                    .padding(16)
                                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                                    .cornerRadius(8)
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }

                            HStack(alignment: .center, spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Clipboard History")
                                        .font(.system(size: 14, weight: .medium))
                                    Text("\(appDelegate.clipboardItems.count) items stored")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button("Clear All") {
                                    showClearHistoryAlert = true
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.red)
                                .controlSize(.large)
                            }
                            .padding(16)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(8)

                            // Export/Import buttons
                            HStack(spacing: 12) {
                                Button(action: {
                                    exportClipboardHistory()
                                }) {
                                    Label("Export History", systemImage: "square.and.arrow.up")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.large)

                                Button(action: {
                                    importClipboardHistory()
                                }) {
                                    Label("Import History", systemImage: "square.and.arrow.down")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                            }
                        }
                    }

                    Divider()

                    // Layout Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Layout")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        VStack(spacing: 16) {
                            SettingRow(
                                title: "Show Pinned Items",
                                description: "Display pinned clipboard items section",
                                toggle: $settingsManager.showPinned
                            )

                            SettingRow(
                                title: "Show Recent Items",
                                description: "Display recent clipboard items section",
                                toggle: $settingsManager.showRecent
                            )
                        }
                    }

                    Divider()

                    // Privacy Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Privacy")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        VStack(spacing: 16) {
                            SettingRow(
                                title: "Incognito Mode",
                                description: "Pause clipboard monitoring temporarily",
                                toggle: $appDelegate.isIncognitoMode
                            )

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Excluded Applications")
                                    .font(.system(size: 14, weight: .medium))
                                Text("ClipPocket won't monitor clipboard from these apps")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)

                                NavigationLink(destination: ExcludedAppsView()) {
                                    HStack {
                                        Image(systemName: "shield.lefthalf.filled")
                                            .foregroundColor(.blue)
                                        Text("Manage Excluded Apps")
                                            .font(.system(size: 13))
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                            .font(.system(size: 12))
                                    }
                                    .padding(16)
                                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Divider()

                    // About Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("ClipPocket")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Version \(AppVersion.current)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Text("Created by Shaneen Dhahd")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Link("shaneendhahd@gmail.com", destination: URL(string: "mailto:shaneendhahd@gmail.com")!)
                                    .font(.system(size: 12))
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(8)

                            // Check for Updates button
                            Button(action: {
                                UpdateChecker.shared.checkForUpdates(showAlert: true)
                            }) {
                                HStack {
                                    Image(systemName: "arrow.down.circle")
                                    Text("Check for Updates")
                                    Spacer()
                                    if UpdateChecker.shared.isCheckingForUpdates {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .frame(width: 16, height: 16)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .disabled(UpdateChecker.shared.isCheckingForUpdates)
                        }
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 500, height: 600)
        .alert("Clear Clipboard History", isPresented: $showClearHistoryAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                appDelegate.clearClipboardHistory()
            }
        } message: {
            Text("Are you sure you want to clear all clipboard history? This action cannot be undone.")
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        if enabled {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }

    private func exportClipboardHistory() {
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = "ClipPocket-Export-\(Date().formatted(date: .abbreviated, time: .omitted)).json"
        savePanel.allowedContentTypes = [.json]

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .prettyPrinted
                    let data = try encoder.encode(Array(appDelegate.clipboardItems))
                    try data.write(to: url)
                } catch {
                    print("Export failed: \(error)")
                }
            }
        }
    }

    private func importClipboardHistory() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false

        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                do {
                    let data = try Data(contentsOf: url)
                    let decoder = JSONDecoder()
                    let items = try decoder.decode([ClipboardItem].self, from: data)
                    appDelegate.clipboardItems = items
                    appDelegate.saveClipboardHistory()
                } catch {
                    print("Import failed: \(error)")
                }
            }
        }
    }
}

// MARK: - Setting Row Component
struct SettingRow: View {
    let title: String
    let description: String
    @Binding var toggle: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: $toggle)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }
}
