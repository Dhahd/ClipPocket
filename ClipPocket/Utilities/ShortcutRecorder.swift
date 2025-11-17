import SwiftUI
import Carbon
import AppKit

struct ShortcutRecorder: View {
    @Binding var shortcut: KeyboardShortcut
    @State private var isRecording = false
    @State private var localMonitor: Any?
    @EnvironmentObject var appDelegate: AppDelegate

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Click to record a new shortcut")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Button(action: {
                    isRecording.toggle()
                    if isRecording {
                        startRecording()
                    } else {
                        stopRecording()
                    }
                }) {
                    HStack {
                        Text(isRecording ? "Press keys..." : shortcut.displayString)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isRecording ? .white : .primary)
                        Spacer()
                        if isRecording {
                            Image(systemName: "circle.fill")
                                .foregroundColor(.red)
                                .font(.system(size: 8))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isRecording ? Color.red.opacity(0.3) : Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isRecording ? Color.red : Color.clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }

            Button(action: {
                shortcut = .default
                appDelegate.setupGlobalHotkey()
            }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 14))
            }
            .help("Reset to default (⌘⇧C)")
        }
    }

    private func startRecording() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Require at least one modifier key
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard !flags.isEmpty else {
                NSSound.beep()
                return nil
            }

            if let newShortcut = KeyboardShortcut(event: event) {
                shortcut = newShortcut
                stopRecording()

                // Re-register the hotkey with the new shortcut
                appDelegate.setupGlobalHotkey()
            } else {
                NSSound.beep()
            }

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
}
