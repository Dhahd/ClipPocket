import SwiftUI
import Carbon

struct ShortcutRecorder: View {
    @Binding var shortcut: String
    @State private var isRecording = false
    @State private var localMonitor: Any?
    
    var body: some View {
        Button(action: {
            isRecording.toggle()
            if isRecording {
                startRecording()
            } else {
                stopRecording()
            }
        }) {
            Text(isRecording ? "Recording..." : (shortcut.isEmpty ? "Record Shortcut" : shortcut))
                .padding()
                .background(isRecording ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                .cornerRadius(8)
        }
        .keyboardShortcut(.defaultAction)
    }
    
    private func startRecording() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            shortcut = eventToString(event)
            stopRecording()
            return nil
        }
    }
    
    private func stopRecording() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        isRecording = false
    }
    
    private func eventToString(_ event: NSEvent) -> String {
        var string = ""
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        
        if flags.contains(.control) { string += "⌃" }
        if flags.contains(.option) { string += "⌥" }
        if flags.contains(.shift) { string += "⇧" }
        if flags.contains(.command) { string += "⌘" }
        
        if let specialKey = event.specialKey {
            string += specialKey.description
        } else {
            string += String(event.keyCode)
        }
        
        return string
    }
}

extension NSEvent.SpecialKey {
    var description: String {
        switch self {
        case .tab: return "⇥"
        case .delete: return "⌫"
        case .leftArrow: return "←"
        case .rightArrow: return "→"
        case .upArrow: return "↑"
        case .downArrow: return "↓"
        default: return "Unknown"
        }
    }
}
