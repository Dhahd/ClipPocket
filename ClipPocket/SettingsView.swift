import SwiftUI
import ServiceManagement
import Carbon

struct SettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("shortcut") private var shortcut = ""
    @State private var isRecordingShortcut = false
    @State private var tempShortcut = ""
    
    var body: some View {
        Form {
            Section(header: Text("General")) {
                VStack(alignment: .leading) {
                    Text("Shortcut:")
                    HStack {
                        Text(shortcut.isEmpty ? "None" : shortcut)
                        Button(isRecordingShortcut ? "Press keys..." : "Record") {
                            isRecordingShortcut.toggle()
                            if isRecordingShortcut {
                                tempShortcut = ""
                                NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                                    let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                                    var shortcutString = ""
                                    
                                    if modifiers.contains(.control) { shortcutString += "⌃" }
                                    if modifiers.contains(.option) { shortcutString += "⌥" }
                                    if modifiers.contains(.shift) { shortcutString += "⇧" }
                                    if modifiers.contains(.command) { shortcutString += "⌘" }
                                    
                                    if let specialKey = event.specialKey {
                                        shortcutString += specialKey.description
                                    } else if let characters = event.charactersIgnoringModifiers?.uppercased(), !characters.isEmpty {
                                        shortcutString += characters
                                    }
                                    
                                    if !shortcutString.isEmpty {
                                        shortcut = shortcutString
                                        isRecordingShortcut = false
                                        
                                        // Notify AppDelegate to update the shortcut
                                        NotificationCenter.default.post(name: Notification.Name("ShortcutChanged"), object: nil)
                                    }
                                    
                                    return nil
                                }
                            }
                        }
                    }
                }
                
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        let launcherAppId = "dhahdz.shaneen.ClipPocket"
                        if newValue {
                            try? SMAppService.mainApp.register()
                        } else {
                            try? SMAppService.mainApp.unregister()
                        }
                    }
            }
            
            Section {
                Text("Created by Shaneen Dhahd")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Text("shaneendhahd@gmail.com")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 300, height: 200)
    }
}

extension NSEvent.SpecialKey: CustomStringConvertible {
    public var description: String {
        switch self {
        case .home: return "Home"
        case .end: return "End"
        case .pageUp: return "Page Up"
        case .pageDown: return "Page Down"
        case .tab: return "⇥"
        case .delete: return "⌫"
        case .leftArrow: return "←"
        case .rightArrow: return "→"
        case .downArrow: return "↓"
        case .upArrow: return "↑"
        case .f1: return "F1"
        case .f2: return "F2"
        case .f3: return "F3"
        case .f4: return "F4"
        case .f5: return "F5"
        case .f6: return "F6"
        case .f7: return "F7"
        case .f8: return "F8"
        case .f9: return "F9"
        case .f10: return "F10"
        case .f11: return "F11"
        case .f12: return "F12"
        case .f13: return "F13"
        case .f14: return "F14"
        case .f15: return "F15"
        case .f16: return "F16"
        case .f17: return "F17"
        case .f18: return "F18"
        case .f19: return "F19"
        case .f20: return "F20"
        case .help: return "Help"
        case .home: return "Home"
        case .pageUp: return "Page Up"
        case .end: return "End"
        case .pageDown: return "Page Down"
        case .leftArrow: return "←"
        case .rightArrow: return "→"
        case .downArrow: return "↓"
        case .upArrow: return "↑"
        default: return "Unknown"
        }
    }
}
