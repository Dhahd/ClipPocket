import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        Form {
            Section(header: Text("General")) {
                VStack(alignment: .leading) {
                    Text("Shortcut: ⌘⇧C")
                        .frame(minWidth: 100, alignment: .leading)
                }
                .padding(.vertical, 5)
                
                Toggle("Launch at login", isOn: Binding(
                    get: { settingsManager.launchAtLogin },
                    set: { newValue in
                        settingsManager.launchAtLogin = newValue
                        setLaunchAtLogin(newValue)
                    }
                ))

            }
            
            Section {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Created by Shaneen Dhahd")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Text("shaneendhahd@gmail.com")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(width: 300, height: 200)
    }
    
    private func setLaunchAtLogin(_ enabled: Bool) {
        let launcherAppId = "dhahdz.shaneen.ClipPocket"
        if enabled {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }
}
