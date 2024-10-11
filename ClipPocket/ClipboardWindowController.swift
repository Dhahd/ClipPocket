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
            contentRect: NSRect(x: contentRect.origin.x,
                                y: contentRect.origin.y,
                                width: contentRect.width,
                                height: 230), // Updated height
            backing: .buffered,
            defer: false
        )
        
        self.init(window: panel)
    }
}
