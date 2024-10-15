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
        // Remove any existing event handler
        if let eventHandler = self.eventHandler {
            UnregisterEventHotKey(eventHandler)
            self.eventHandler = nil
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
        
        // Register hotkey (Command-Shift-C)
        let hotKeyRef = UnsafeMutablePointer<EventHotKeyRef?>.allocate(capacity: 1)
        let status = RegisterEventHotKey(8, // Virtual key code for 'C'
                                         UInt32(cmdKey + shiftKey),
                                         gMyHotKeyID,
                                         GetApplicationEventTarget(),
                                         0,
                                         hotKeyRef)
        
        if status == noErr {
            print("Hotkey registered successfully")
            self.eventHandler = hotKeyRef.pointee
        } else {
            print("Error registering hotkey")
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
                print("Accessibility permission granted")
                self.setupGlobalHotkey()
                timer.invalidate() // Stop the timer
                DispatchQueue.main.async {
                    self.showPermissionGrantedAlert()
                }
            }
        }
    }
    
    func showPermissionGrantedAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Granted"
        alert.informativeText = "Thank you! ClipPocket now has the necessary permissions to function properly."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func openAccessibilityPreferences() {
        let prefpaneUrl = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(prefpaneUrl)
    }
}
