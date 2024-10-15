import SwiftUI
import ServiceManagement
import Cocoa
import UniformTypeIdentifiers
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var statusItem: NSStatusItem?
    @Published var clipboardItems: [ClipboardItem] = []
    @Published var isShowingSettings = true
    var timer: Timer?
    private var lastChangeCount: Int = 0
    private var isInternalCopy = false
    private var settingsWindow: NSWindow?
    private var clipboardWindowController: ClipboardWindowController?
    private var isClipboardManagerVisible = false
    var eventHandler: EventHandlerRef?
    private let settingsManager = SettingsManager.shared
    var statusItemView: StatusItemView?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        setLaunchAtLogin(settingsManager.launchAtLogin)
        
        setupGlobalHotkey()
        startMonitoringClipboard()
        checkAccessibilityPermission()
        
        setupStatusItem()
        setupClipboardManager()
        
        NSApp.setActivationPolicy(.accessory)
        
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "☰" // You can set an icon or text
        }
        
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
        // Set up a global event monitor for mouse clicks outside the window
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
            self.handleMouseClickOutsideWindow(event)
        }
    }
    
    private func setLaunchAtLogin(_ enabled: Bool) {
        let launcherAppId = "dhahdz.shaneen.ClipPocket"
        if enabled {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }
    
    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    func checkAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if accessibilityEnabled {
            print("Accessibility permission already granted")
            setupGlobalHotkey()
        } else {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permission Required"
                alert.informativeText = "ClipPocket needs Accessibility permission to monitor keyboard events for the global shortcut. Would you like to open System Preferences to grant permission?"
                alert.addButton(withTitle: "Open System Preferences")
                alert.addButton(withTitle: "Later")
                
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    self.openAccessibilityPreferences()
                }
            }
            startAccessibilityPermissionCheck()
        }
    }

    func handleMouseClickOutsideWindow(_ event: NSEvent) {
        guard let window = clipboardWindowController?.window else {
            return
        }
        
        let mouseLocation = event.locationInWindow
        
        // Check if the mouse click happened outside the window
        let windowFrame = window.frame
        if !windowFrame.contains(mouseLocation) {
            // Mouse click happened outside the window
            // You can now perform any action, such as hiding the window
            hideClipboardManager()
        }
    }
    
    private var clipboardWindowFrame: NSRect?
    
    func setupClipboardManager() {
        let screenRect = NSScreen.main?.visibleFrame ?? .zero
        let windowWidth: CGFloat = screenRect.width - 10  // Subtracting 100 to give some padding
        
        let xPosition = (screenRect.width - windowWidth) / 2
        let yPosition = screenRect.minY + 10  // 10 pixels from the bottom
        
        let windowFrame = NSRect(x: xPosition, y: yPosition, width: windowWidth, height: 300)
        
        clipboardWindowController = ClipboardWindowController(contentRect: windowFrame)
    
        clipboardWindowController?.window?.contentView?.layer?.cornerRadius = 15
        
        if let window = clipboardWindowController?.window {
            let hostingView = NSHostingView(rootView: ClipboardManagerView().environmentObject(self))
            hostingView.layer?.cornerRadius = 15
            window.contentView = hostingView
        }
        
        print("Clipboard window controller initialized: \(clipboardWindowController != nil)")
    }
    
    @objc func toggleClipboardManager() {
        print("Toggling clipboard manager. Current visibility: \(isClipboardManagerVisible)")
        if isClipboardManagerVisible {
            hideClipboardManager()
        } else {
            showClipboardManager()
        }
    }

    private var storedWindowFrame: NSRect {
        let screenRect = NSScreen.main?.visibleFrame ?? .zero
        let windowWidth: CGFloat = screenRect.width - 10  // Subtracting 10 to give some padding
        let windowHeight: CGFloat = 300
        
        let xPosition = (screenRect.width - windowWidth) / 2
        let yPosition = screenRect.minY + 10  // 10 pixels from the bottom
        
        return NSRect(x: xPosition, y: yPosition, width: windowWidth, height: windowHeight)
    }

    func showClipboardManager() {
        guard !isClipboardManagerVisible else { return }

        guard let window = clipboardWindowController?.window else { return }

        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let originalFrame = storedWindowFrame

        // Ensure the window is within the screen bounds
        let adjustedFrame = NSRect(
            x: min(max(originalFrame.origin.x, screenFrame.minX), screenFrame.maxX - originalFrame.width),
            y: min(max(originalFrame.origin.y, screenFrame.minY), screenFrame.maxY - originalFrame.height),
            width: originalFrame.width,
            height: originalFrame.height
        )

        // Start below the screen (offscreen)
        let offscreenFrame = NSRect(
            x: adjustedFrame.origin.x,
            y: screenFrame.minY - adjustedFrame.height,
            width: adjustedFrame.width,
            height: adjustedFrame.height
        )

        window.setFrame(offscreenFrame, display: false)
        window.makeKeyAndOrderFront(nil)

        // Animate moving up into view
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2 // Adjust for animation speed
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrame(adjustedFrame, display: true)
        }

        isClipboardManagerVisible = true
        print("Clipboard manager shown")
    }

    @objc func hideClipboardManager() {
        guard isClipboardManagerVisible else { return }

        guard let window = clipboardWindowController?.window else { return }

        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let currentFrame = window.frame

        // Store the current frame for next time

        // Animate moving down, offscreen
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2 // Adjust for animation speed
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            let offscreenFrame = NSRect(
                x: currentFrame.origin.x,
                y: screenFrame.minY - currentFrame.height,
                width: currentFrame.width,
                height: currentFrame.height
            )
            window.animator().setFrame(offscreenFrame, display: true)
        } completionHandler: {
            window.orderOut(nil) // Hide the window after animation completes
        }

        isClipboardManagerVisible = false
        print("Clipboard manager hidden")
    }
    
    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let statusBarButton = statusItem?.button {
            let statusItemView = StatusItemView(frame: statusBarButton.bounds)
            statusItemView.delegate = self
            statusBarButton.addSubview(statusItemView)
            self.statusItemView = statusItemView
        }
    }
    
    func checkClipboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount && !isInternalCopy else { return }
        
        lastChangeCount = pasteboard.changeCount
        
        let sourceApp = NSWorkspace.shared.frontmostApplication
        
        if let item = readClipboardItem(from: pasteboard, sourceApp: sourceApp) {
            addClipboardItem(item)
            animateStatusItemIcon()
        }
    }
    
    private func animateStatusItemIcon() {
        statusItemView?.startAnimation()
    }
    
    @objc func statusItemClicked(_ sender: NSStatusBarButton) {
        if let event = NSApp.currentEvent {
            if event.type == .rightMouseUp {
                statusItem?.menu?.popUp(positioning: nil, at: NSPoint(x: 0, y: statusItem?.button?.bounds.height ?? 0), in: statusItem?.button)
            } else if event.type == .leftMouseUp {
                toggleClipboardManager()
            }
        }
    }
    
    @objc func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)
            settingsWindow = NSWindow(contentViewController: hostingController)
            settingsWindow?.title = "Settings"
            settingsWindow?.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            settingsWindow?.setContentSize(NSSize(width: 300, height: 200))
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func startMonitoringClipboard() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    func readClipboardItem(from pasteboard: NSPasteboard, sourceApp: NSRunningApplication?) -> ClipboardItem? {
        // Check for image
        if let image = NSImage(pasteboard: pasteboard) {
            if let tiffData = image.tiffRepresentation {
                return ClipboardItem(content: tiffData, type: .image, timestamp: Date(), sourceApplication: sourceApp)
            }
        }
        
        // Check for text
        if let string = pasteboard.string(forType: .string) {
            // Check if it's a color (simple hex check)
            if string.matches(regex: "^#(?:[0-9a-fA-F]{3}){1,2}$") {
                return ClipboardItem(content: string, type: .color, timestamp: Date(), sourceApplication: sourceApp)
            }
            
            // Check if it's code (simple check for common programming keywords)
            let codeKeywords = ["func", "class", "struct", "var", "let", "if", "else", "for", "while", "return"]
            if codeKeywords.contains(where: { string.contains($0) }) {
                return ClipboardItem(content: string, type: .code, timestamp: Date(), sourceApplication: sourceApp)
            }
            
            // If it's not a color or code, treat it as plain text
            return ClipboardItem(content: string, type: .text, timestamp: Date(), sourceApplication: sourceApp)
        }
        
        return nil
    }
    
    func addClipboardItem(_ item: ClipboardItem) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if !self.clipboardItems.contains(where: { $0.isEqual(to: item) }) {
                self.clipboardItems.insert(item, at: 0)
                
                // Trim the list if it exceeds a certain limit (e.g., 100 items)
                let maxItems = 100
                if self.clipboardItems.count > maxItems {
                    self.clipboardItems = Array(self.clipboardItems.prefix(maxItems))
                }
                
                print("Added new clipboard item: \(item.displayString)")
            }
        }
    }
    
    func copyItemToClipboard(_ item: ClipboardItem) {
        isInternalCopy = true
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        switch item.type {
        case .text, .code:
            if let textContent = item.content as? String {
                pasteboard.setString(textContent, forType: .string)
            }
        case .image:
            if let imageData = item.content as? Data, let image = NSImage(data: imageData) {
                pasteboard.writeObjects([image])
            }
        case .color:
            if let colorString = item.content as? String {
                pasteboard.setString(colorString, forType: .string)
                
                // Optionally, you can also set the color as an NSColor object
                if let color = NSColor(hex: colorString) {
                    pasteboard.setData(try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true), forType: .color)
                }
            }
        }
        animateStatusItemIcon()
        // Move the selected item to the top of the list
        if let index = clipboardItems.firstIndex(where: { $0.id == item.id }) {
            let movedItem = clipboardItems.remove(at: index)
            clipboardItems.insert(movedItem, at: 0)
        }
        
        DispatchQueue.main.async {
            self.isInternalCopy = false
        }
    }
}

extension AppDelegate: StatusItemViewDelegate {
    func statusItemClicked() {
        statusItem?.button?.performClick(nil)
        toggleClipboardManager()
    }
    
    func statusItemRightClicked() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }
}
