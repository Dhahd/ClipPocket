//
//  ClipboardManager.swift
//  ClipPocket
//
//  Created by Shaneen on 10/14/24.
//

import Foundation
import AppKit

class ClipboardManager: ObservableObject {
    @Published var clipboardItems: [ClipboardItem] = []
    
    func copyItemToClipboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.type {
        case .text, .code, .color, .url, .email, .phone, .json:
            if let content = item.content as? String {
                pasteboard.setString(content, forType: .string)
            }
        case .image:
            if let imageData = item.content as? Data,
               let image = NSImage(data: imageData) {
                pasteboard.writeObjects([image])
            }
        case .file:
            // Copy file from source path
            if let fileURL = item.content as? URL {
                // Check if file still exists
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    pasteboard.writeObjects([fileURL as NSURL])
                    print("📁 Copied file reference to clipboard: \(fileURL.path)")
                } else {
                    print("❌ File no longer exists: \(fileURL.path)")
                    // Could show an alert to the user here
                }
            }
        }

        simulatePasteKeyPress()
    }
    
    private func simulatePasteKeyPress() {
        let source = CGEventSource(stateID: .hidSystemState)
        
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)
        
        cmdDown?.flags = .maskCommand
        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand
        
        cmdDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
    }
}
