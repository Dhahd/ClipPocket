import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @StateObject private var settingsManager = SettingsManager.shared
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
                    }

                    Divider()

                    // Keyboard Shortcut Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Keyboard Shortcut")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)

                        HStack {
                            Text("Current Shortcut:")
                                .font(.system(size: 13))
                            Spacer()
                            Text("⌘⇧C")
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(6)
                        }
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
                appDelegate.clipboardItems.removeAll()
                appDelegate.saveClipboardHistory()
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
