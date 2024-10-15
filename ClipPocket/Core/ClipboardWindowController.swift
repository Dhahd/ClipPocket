//
//  ClipboardWindowController.swift
//  ClipPocket
//
//  Created by Shaneen on 10/11/24.
//

import SwiftUI
import AppKit

class ClipboardWindowController: NSWindowController {
    convenience init(contentRect: NSRect) {
        let panel = ClipboardPanel(
            contentRect: contentRect,
            backing: .buffered,
            defer: false
        )
        
        self.init(window: panel)
        
        setupWindow()
    }
    
    private func setupWindow() {
        guard let window = window as? ClipboardPanel else { return }
        
        // Additional setup if needed
        window.title = "ClipPocket"
    }
    
    override func showWindow(_ sender: Any?) {
        window?.orderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
