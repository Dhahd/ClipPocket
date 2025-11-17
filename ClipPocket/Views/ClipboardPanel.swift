import AppKit

class ClipboardPanel: NSPanel {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
    
    init(contentRect: NSRect, backing: NSWindow.BackingStoreType, defer: Bool) {
            super.init(contentRect: contentRect,
                       styleMask: [.borderless],
                       backing: backing,
                       defer: `defer`)

        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false // Remove shadow as it's handled by SwiftUI
        self.isMovable = false
        self.hidesOnDeactivate = false
        self.alphaValue = 1.0
        self.isReleasedWhenClosed = false

        // Allow keyboard input
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
    }
    
    override func mouseDown(with event: NSEvent) {
        // If the click is outside the window's frame, hide the clipboard manager
        let locationInWindow = self.convertPoint(fromScreen: event.locationInWindow)
        if !self.contentView!.bounds.contains(locationInWindow) {
            NSApp.sendAction(#selector(AppDelegate.hideClipboardManager), to: nil, from: nil)
        } else {
            super.mouseDown(with: event)
        }
    }
}
