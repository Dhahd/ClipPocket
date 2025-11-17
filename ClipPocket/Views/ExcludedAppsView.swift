import SwiftUI
import AppKit

struct ExcludedAppsView: View {
    @ObservedObject private var excludedAppsManager = ExcludedAppsManager.shared
    @State private var runningApps: [RunningAppInfo] = []

    struct RunningAppInfo: Identifiable {
        let id = UUID()
        let name: String
        let bundleId: String
        let icon: NSImage?
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: {
                    // Navigate back
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.plain)

                Text("Excluded Applications")
                    .font(.system(size: 18, weight: .semibold))

                Spacer()

                Button("Reset to Defaults") {
                    excludedAppsManager.resetToDefaults()
                    loadRunningApps()
                }
                .buttonStyle(.bordered)
            }
            .padding()

            Divider()

            // Instructions
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("Clipboard monitoring will be paused for excluded apps")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 16)
            }

            // List of running apps
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(runningApps) { app in
                        AppRow(
                            app: app,
                            isExcluded: excludedAppsManager.excludedBundleIds.contains(app.bundleId),
                            onToggle: {
                                excludedAppsManager.toggleApp(app.bundleId)
                            }
                        )
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 600)
        .onAppear {
            loadRunningApps()
        }
    }

    private func loadRunningApps() {
        let workspace = NSWorkspace.shared
        let apps = workspace.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> RunningAppInfo? in
                guard let bundleId = app.bundleIdentifier,
                      let name = app.localizedName else {
                    return nil
                }
                return RunningAppInfo(
                    name: name,
                    bundleId: bundleId,
                    icon: app.icon
                )
            }
            .sorted { $0.name < $1.name }

        runningApps = apps
    }
}

struct AppRow: View {
    let app: ExcludedAppsView.RunningAppInfo
    let isExcluded: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // App icon
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 14, weight: .medium))
                Text(app.bundleId)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isExcluded },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }
}
