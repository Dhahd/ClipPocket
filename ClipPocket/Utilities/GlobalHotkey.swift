//
//  GlobalHotkey.swift
//  ClipPocket
//
//  Created by Shaneen on 10/15/24.
//

import Carbon
import AppKit

extension String {
    var fourCharCodeValue: OSType {
        guard let data = self.data(using: .macOSRoman) else { return 0 }
        return data.reduce(0) { ($0 << 8) + OSType($1) }
    }
}

extension AppDelegate {
    func setupGlobalHotkey() {
        print("🔧 Setting up global hotkey...")

        // Remove any existing hotkey
        if let existingHotKey = self.hotKeyRef {
            print("🗑️ Removing existing hotkey handler")
            UnregisterEventHotKey(existingHotKey)
            self.hotKeyRef = nil
        }

        var gMyHotKeyID = EventHotKeyID()
        gMyHotKeyID.signature = OSType("MyHK".fourCharCodeValue)
        gMyHotKeyID.id = 1

        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)

        // Install handler
        InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            let appDelegate = unsafeBitCast(userData, to: AppDelegate.self)
            appDelegate.handleHotKeyEvent()
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)

        let shortcut = settingsManager.keyboardShortcut

        // Register hotkey using the user's shortcut
        let hotKeyRef = UnsafeMutablePointer<EventHotKeyRef?>.allocate(capacity: 1)
        let status = RegisterEventHotKey(shortcut.keyCode,
                                         shortcut.modifiers,
                                         gMyHotKeyID,
                                         GetApplicationEventTarget(),
                                         0,
                                         hotKeyRef)

        if status == noErr {
            print("✅ Hotkey \(shortcut.displayString) registered successfully!")
            self.hotKeyRef = hotKeyRef.pointee
        } else {
            print("❌ Error registering hotkey - status code: \(status)")
        }

        hotKeyRef.deallocate()
    }
    
    func handleHotKeyEvent() {
        DispatchQueue.main.async {
            self.toggleClipboardManager()
        }
    }
    
    func startAccessibilityPermissionCheck() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
            let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)

            if accessibilityEnabled {
                print("✅ Accessibility permission granted via timer check - retrying hotkey setup")
                self.setupGlobalHotkey()
                timer.invalidate() // Stop the timer
            }
        }
    }
    
    func openAccessibilityPreferences() {
        let prefpaneUrl = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(prefpaneUrl)
    }
}
