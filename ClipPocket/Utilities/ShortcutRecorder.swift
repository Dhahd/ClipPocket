import SwiftUI
import Carbon
import AppKit

struct ShortcutRecorder: View {
    @Binding var shortcut: KeyboardShortcut
    @State private var isRecording = false
    @State private var localMonitor: Any?
    @EnvironmentObject var appDelegate: AppDelegate

    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                isRecording.toggle()
                if isRecording {
                    startRecording()
                } else {
                    stopRecording()
                }
            }) {
                HStack(spacing: 12) {
                    Text(isRecording ? "Press keys..." : shortcut.displayString)
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundColor(isRecording ? .white : .primary)

                    Spacer()

                    if isRecording {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            Text("Recording")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isRecording ? Color.red.opacity(0.15) : Color(NSColor.controlBackgroundColor).opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isRecording ? Color.red : Color.clear, lineWidth: 2)
                )
            }
            .buttonStyle(.plain)

            Button(action: {
                shortcut = .default
                appDelegate.setupGlobalHotkey()
            }) {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
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
