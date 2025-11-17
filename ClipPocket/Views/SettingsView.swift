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
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // General Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("General")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)

                        Toggle(isOn: Binding(
                            get: { settingsManager.launchAtLogin },
                            set: { newValue in
                                settingsManager.launchAtLogin = newValue
                                setLaunchAtLogin(newValue)
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Launch at Login")
                                    .font(.system(size: 13))
                                Text("Start ClipPocket automatically when you log in")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.switch)

                        Toggle(isOn: Binding(
                            get: { settingsManager.rememberHistory },
                            set: { newValue in
                                settingsManager.rememberHistory = newValue
                                if newValue {
                                    appDelegate.loadPersistedClipboardHistory()
                                } else {
                                    appDelegate.clearClipboardHistory()
                                }
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Remember History")
                                    .font(.system(size: 13))
                                Text("Store clipboard items between sessions")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.switch)

                        Toggle(isOn: $settingsManager.autoPasteEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Auto Paste on Selection")
                                    .font(.system(size: 13))
                                Text("Immediately paste the copied item after selection")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                    }

                    Divider()

                    // Keyboard Shortcut Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Keyboard Shortcut")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)

                        ShortcutRecorder(shortcut: Binding(
                            get: { settingsManager.keyboardShortcut },
                            set: { newShortcut in
                                settingsManager.keyboardShortcut = newShortcut
                            }
                        ))
                        .frame(maxWidth: .infinity)
                    }

                    Divider()

                    // Data Management Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Data Management")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Clipboard History")
                                    .font(.system(size: 13))
                                Text("\(appDelegate.clipboardItems.count) items stored")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Clear All") {
                                showClearHistoryAlert = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        }
                    }

                    Divider()

                    // Layout Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Layout")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)

                        Toggle("Show Pinned Items", isOn: $settingsManager.showPinned)
                            .toggleStyle(.switch)

                        Toggle("Show Recent Items", isOn: $settingsManager.showRecent)
                            .toggleStyle(.switch)
                    }

                    Divider()

                    // About Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("ClipPocket")
                                .font(.system(size: 13, weight: .medium))
                            Text("Version 1.0.0")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text("Created by Shaneen Dhahd")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text("shaneendhahd@gmail.com")
                                .font(.system(size: 11))
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 450, height: 500)
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
}
