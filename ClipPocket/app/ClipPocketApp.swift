import SwiftUI
import ServiceManagement
import Cocoa
import UniformTypeIdentifiers
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var statusItem: NSStatusItem?
    @Published var clipboardItems: [ClipboardItem] = []
    @Published var isShowingSettings = true
    @Published var pinnedManager = PinnedClipboardManager()
    var timer: Timer?
    private var lastChangeCount: Int = 0
    private var isInternalCopy = false
    private var settingsWindow: NSWindow?
    private var clipboardWindowController: ClipboardWindowController?
    private var isClipboardManagerVisible = false
    var hotKeyRef: EventHotKeyRef?
    let settingsManager = SettingsManager.shared
    var statusItemView: StatusItemView?
    private var saveTimer: Timer?
    let excludedAppsManager = ExcludedAppsManager.shared
    @Published var isIncognitoMode: Bool = false
    @Published var showOnboarding = false
    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setLaunchAtLogin(settingsManager.launchAtLogin)

        loadPersistedClipboardHistory()
        startMonitoringClipboard()
        checkAccessibilityPermission()

        setupStatusItem()
        setupClipboardManager()

        // Set up a global event monitor for mouse clicks outside the window
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
            self.handleMouseClickOutsideWindow(event)
        }

        // Show onboarding for first-time users
        checkAndShowOnboarding()

        // Check for updates on launch (silently, once per day)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            UpdateChecker.shared.checkForUpdatesOnLaunch()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cancel any pending debounced save
        saveTimer?.invalidate()

        // Perform final synchronous save to ensure all items are persisted
        saveSynchronously()
    }
    
    private func setLaunchAtLogin(_ enabled: Bool) {
        if enabled {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }
    
    @objc func quitApp() {
        // Cancel any pending debounced saves
        saveTimer?.invalidate()
        // Save synchronously to ensure all items are persisted before quitting
        saveSynchronously()
        NSApp.terminate(nil)
    }

    func checkAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)

        print("🔍 Checking accessibility permission: \(accessibilityEnabled)")

        // Always try to setup hotkey - it will fail gracefully if no permission
        setupGlobalHotkey()

        if !accessibilityEnabled {
            print("⚠️ Accessibility permission not granted - hotkey may not work")
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
        let windowWidth: CGFloat = screenRect.width - 10  // Wide screen with small padding
        let windowHeight: CGFloat = 300

        let xPosition = (screenRect.width - windowWidth) / 2
        let yPosition = screenRect.minY + 10  // 10px from bottom

        let windowFrame = NSRect(x: xPosition, y: yPosition, width: windowWidth, height: windowHeight)

        clipboardWindowController = ClipboardWindowController(contentRect: windowFrame)

        clipboardWindowController?.window?.contentView?.layer?.cornerRadius = 15

        if let window = clipboardWindowController?.window {
            let hostingView = NSHostingView(rootView:
                ClipboardManagerView()
                    .environmentObject(self)
                    .environmentObject(pinnedManager)
            )
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
        let windowWidth: CGFloat = screenRect.width - 10
        let windowHeight: CGFloat = 300

        let xPosition = (screenRect.width - windowWidth) / 2
        let yPosition = screenRect.minY + 10  // 10px from bottom

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
        NSApp.activate(ignoringOtherApps: true)

        // Animate moving up into view
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2 // Adjust for animation speed
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrame(adjustedFrame, display: true)
        } completionHandler: {
            // Ensure the window can accept keyboard input after animation
            window.makeKey()
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
        // Skip monitoring in incognito mode
        guard !isIncognitoMode else {
            lastChangeCount = NSPasteboard.general.changeCount
            return
        }

        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount && !isInternalCopy else { return }

        lastChangeCount = pasteboard.changeCount

        let sourceApp = NSWorkspace.shared.frontmostApplication

        // Check if the source app is excluded
        if let bundleId = sourceApp?.bundleIdentifier,
           excludedAppsManager.isAppExcluded(bundleId) {
            print("⛔ Skipping clipboard from excluded app: \(bundleId)")
            return
        }

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
                .environmentObject(self)
            let hostingController = NSHostingController(rootView: settingsView)
            settingsWindow = NSWindow(contentViewController: hostingController)
            settingsWindow?.title = "Settings"
            settingsWindow?.styleMask = [.titled, .closable, .miniaturizable]
            settingsWindow?.setContentSize(NSSize(width: 450, height: 500))
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func startMonitoringClipboard() {
        // Set initial change count
        lastChangeCount = NSPasteboard.general.changeCount

        // Use longer polling interval for better performance
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    // MARK: - Persistence
    private var historyDirectoryURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let appDirectory = appSupport.appendingPathComponent("ClipPocket", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        return appDirectory
    }

    private func historyFileURL() -> URL? {
        historyDirectoryURL?.appendingPathComponent("clipboardHistory.json")
    }

    private func legacyHistoryFileURL() -> URL? {
        historyDirectoryURL?.appendingPathComponent("ClipboardHistory.json")
    }

    func loadPersistedClipboardHistory() {
        guard settingsManager.rememberHistory else {
            print("Remember history is disabled, skipping load")
            return
        }

        guard let fileURL = historyFileURL() else {
            print("Failed to get clipboard history file URL")
            return
        }

        // Migrate legacy capitalized filename if present (case-sensitive volumes)
        if let legacyURL = legacyHistoryFileURL(),
           !FileManager.default.fileExists(atPath: fileURL.path),
           FileManager.default.fileExists(atPath: legacyURL.path) {
            try? FileManager.default.moveItem(at: legacyURL, to: fileURL)
        }

        // Fallback: migrate very old UserDefaults blob if no file exists
        if !FileManager.default.fileExists(atPath: fileURL.path),
           let legacyData = UserDefaults.standard.data(forKey: "ClipboardHistory") {
            do {
                let decoder = JSONDecoder()
                let legacyItems = try decoder.decode([ClipboardItem].self, from: legacyData)

                // Apply limit only if enabled
                if settingsManager.enableHistoryLimit {
                    let maxItems = settingsManager.maxHistoryItems
                    clipboardItems = Array(legacyItems.prefix(maxItems))
                } else {
                    clipboardItems = legacyItems
                }

                saveClipboardHistory() // persist to file under the new location
                print("✅ Migrated clipboard history from UserDefaults (\(clipboardItems.count) items)")
                return
            } catch {
                print("❌ Failed to migrate legacy history: \(error.localizedDescription)")
            }
        }

        // Check if file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("No clipboard history file found")
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let loadedItems = try decoder.decode([ClipboardItem].self, from: data)

            // Load items - apply limit only if enabled
            if settingsManager.enableHistoryLimit {
                let maxItems = settingsManager.maxHistoryItems
                clipboardItems = Array(loadedItems.prefix(maxItems))
                print("✅ Loaded \(clipboardItems.count) clipboard items from history (limit: \(maxItems))")
            } else {
                clipboardItems = loadedItems
                print("✅ Loaded \(clipboardItems.count) clipboard items from history (no limit)")
            }
        } catch {
            print("❌ Failed to load clipboard history: \(error.localizedDescription)")
            clipboardItems = []
        }
    }

    func saveClipboardHistory() {
        guard settingsManager.rememberHistory else {
            print("Remember history is disabled, skipping save")
            return
        }

        guard let fileURL = historyFileURL() else {
            print("Failed to get clipboard history file URL")
            return
        }

        // Save asynchronously on background thread to avoid blocking UI
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted

                // Filter out items with large data (> 1MB per item) before saving
                let itemsToSave = self.clipboardItems.prefix(1000).filter { item in
                    // Skip very large images
                    if case .image = item.type,
                       let imageData = item.content as? Data,
                       imageData.count > 1_048_576 { // 1MB
                        print("⚠️ Skipping large image (\(imageData.count / 1024)KB) from history save")
                        return false
                    }
                    return true
                }

                let data = try encoder.encode(Array(itemsToSave))
                try data.write(to: fileURL, options: .atomic)
                print("✅ Saved \(itemsToSave.count) clipboard items to history (\(data.count / 1024)KB)")
            } catch {
                print("❌ Failed to save clipboard history: \(error.localizedDescription)")
            }
        }
    }

    private func saveSynchronously() {
        guard settingsManager.rememberHistory else {
            print("Remember history is disabled, skipping save")
            return
        }

        guard let fileURL = historyFileURL() else {
            print("Failed to get clipboard history file URL")
            return
        }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted

            // Filter out items with large data (> 1MB per item) before saving
            let itemsToSave = clipboardItems.prefix(1000).filter { item in
                // Skip very large images
                if case .image = item.type,
                   let imageData = item.content as? Data,
                   imageData.count > 1_048_576 { // 1MB
                    print("⚠️ Skipping large image (\(imageData.count / 1024)KB) from history save")
                    return false
                }
                return true
            }

            let data = try encoder.encode(Array(itemsToSave))
            try data.write(to: fileURL, options: .atomic)
            print("✅ [SYNC] Saved \(itemsToSave.count) clipboard items to history (\(data.count / 1024)KB)")
        } catch {
            print("❌ Failed to save clipboard history synchronously: \(error.localizedDescription)")
        }
    }

    private func debouncedSaveClipboardHistory() {
        // Invalidate any existing timer
        saveTimer?.invalidate()

        // Schedule a new timer to save after 0.5 seconds
        saveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.saveClipboardHistory()
        }
    }

    func clearClipboardHistory() {
        clipboardItems.removeAll()

        if let fileURL = historyFileURL() {
            try? FileManager.default.removeItem(at: fileURL)
        }

        // Also remove old UserDefaults data if it exists
        UserDefaults.standard.removeObject(forKey: "ClipboardHistory")

        print("✅ Cleared clipboard history")
    }
    
    func readClipboardItem(from pasteboard: NSPasteboard, sourceApp: NSRunningApplication?) -> ClipboardItem? {
        // Check for file URLs first (when copying files from Finder)
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let fileURL = urls.first,
           fileURL.isFileURL {
            print("📁 Detected file copy: \(fileURL.path)")
            return ClipboardItem(content: fileURL, type: .file, timestamp: Date(), sourceApplication: sourceApp)
        }

        // Check for image
        if let image = NSImage(pasteboard: pasteboard) {
            if let tiffData = image.tiffRepresentation {
                // Compress image for storage
                if let compressedData = compressImage(image) {
                    return ClipboardItem(content: compressedData, type: .image, timestamp: Date(), sourceApplication: sourceApp)
                }
                return ClipboardItem(content: tiffData, type: .image, timestamp: Date(), sourceApplication: sourceApp)
            }
        }

        // Check for text
        if let string = pasteboard.string(forType: .string) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip empty strings
            guard !trimmed.isEmpty else { return nil }

            let detectedType = detectContentType(from: trimmed)
            return ClipboardItem(content: string, type: detectedType, timestamp: Date(), sourceApplication: sourceApp)
        }

        return nil
    }

    private func compressImage(_ image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }

        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.7])
    }

    private func detectContentType(from string: String) -> ClipboardItem.ItemType {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)

        // Email detection
        if trimmed.range(of: #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#,
                        options: [.regularExpression, .caseInsensitive]) != nil {
            return .email
        }

        // URL detection (skip mailto: which should be treated as email)
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue),
           let match = detector.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           match.range.length == trimmed.count {
            if match.url?.scheme?.lowercased() == "mailto" {
                return .email
            }
            return .url
        }

        // Phone number detection
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue),
           detector.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
            return .phone
        }

        // JSON detection
        if (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) ||
           (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) {
            if let _ = try? JSONSerialization.jsonObject(with: Data(trimmed.utf8)) {
                return .json
            }
        }

        // Color detection - expand beyond hex
        if trimmed.matches(regex: #"^#([0-9a-fA-F]{3}){1,2}$"#) ||
           trimmed.matches(regex: #"^rgb\("#) ||
           trimmed.matches(regex: #"^hsl\("#) ||
           trimmed.matches(regex: #"^rgba\("#) ||
           trimmed.matches(regex: #"^hsla\("#) {
            return .color
        }

        // Code detection - use better heuristics
        let codeIndicators = [
            trimmed.contains("func ") || trimmed.contains("function "),
            trimmed.contains("class ") || trimmed.contains("struct "),
            trimmed.contains("import ") || trimmed.contains("package "),
            trimmed.contains("const ") || trimmed.contains("let ") || trimmed.contains("var "),
            trimmed.contains("def ") || trimmed.contains("=>"),
            (trimmed.split(separator: "\n").count > 3 && (trimmed.contains("{") || trimmed.contains(":"))),
            trimmed.contains("public ") || trimmed.contains("private "),
            trimmed.matches(regex: #"^\s*(if|for|while)\s*\("#)
        ]

        let indicatorCount = codeIndicators.filter({ $0 }).count
        if indicatorCount >= 2 {
            return .code
        }

        return .text
    }
    
    private var saveCounter = 0

    func addClipboardItem(_ item: ClipboardItem) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if !self.clipboardItems.contains(where: { $0.isEqual(to: item) }) {
                self.clipboardItems.insert(item, at: 0)

                // Trim the list if history limit is enabled and exceeds the configured limit
                if self.settingsManager.enableHistoryLimit {
                    let maxItems = self.settingsManager.maxHistoryItems
                    if self.clipboardItems.count > maxItems {
                        self.clipboardItems = Array(self.clipboardItems.prefix(maxItems))
                    }
                }

                print("Added new clipboard item: \(item.displayString)")

                // Auto-save every 30 items or when reaching certain milestones
                self.saveCounter += 1
                if self.saveCounter % 30 == 0 {
                    self.saveClipboardHistory()
                }

                // Persist new items shortly after they are added
                self.debouncedSaveClipboardHistory()
            }
        }
    }
    
    func copyItemToClipboard(_ item: ClipboardItem) {
        isInternalCopy = true
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        switch item.type {
        case .text, .code, .url, .email, .phone, .json:
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
        case .file:
            if let fileURL = item.content as? URL {
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    pasteboard.writeObjects([fileURL as NSURL])
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

    func deleteClipboardItem(_ item: ClipboardItem) {
        clipboardItems.removeAll(where: { $0.id == item.id })
        debouncedSaveClipboardHistory()
    }

    // MARK: - Pinned Item Management
    
    @objc func togglePinForItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? ClipboardItem else { return }
        
        if pinnedManager.isPinned(item) {
            pinnedManager.unpinItem(withOriginalId: item.id)
        } else {
            pinnedManager.pinItem(item)
        }
    }
    
    @objc func editPinTitle(_ sender: NSMenuItem) {
        guard let pinnedItem = sender.representedObject as? PinnedClipboardItem else { return }
        
        let alert = NSAlert()
        alert.messageText = "Edit Pin Title"
        alert.informativeText = "Enter a custom title for this pinned item:"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.stringValue = pinnedItem.customTitle ?? pinnedItem.displayString
        alert.accessoryView = textField
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let newTitle = textField.stringValue.isEmpty ? nil : textField.stringValue
            pinnedManager.updateCustomTitle(for: pinnedItem, title: newTitle)
        }
    }
    
    @objc func removePinnedItem(_ sender: NSMenuItem) {
        guard let pinnedItem = sender.representedObject as? PinnedClipboardItem else { return }
        pinnedManager.unpinItem(pinnedItem)
    }
    
    // Create context menu for regular clipboard items
    func createContextMenu(for item: ClipboardItem) -> NSMenu {
        let menu = NSMenu()
        
        // Copy item
        let copyItem = NSMenuItem(title: "Copy", action: #selector(copyContextMenuItem(_:)), keyEquivalent: "")
        copyItem.representedObject = item
        copyItem.target = self
        menu.addItem(copyItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Pin/Unpin option
        if pinnedManager.isPinned(item) {
            let unpinItem = NSMenuItem(title: "Unpin Item", action: #selector(togglePinForItem(_:)), keyEquivalent: "")
            unpinItem.representedObject = item
            unpinItem.target = self
            menu.addItem(unpinItem)
        } else {
            let pinItem = NSMenuItem(title: "Pin Item", action: #selector(togglePinForItem(_:)), keyEquivalent: "")
            pinItem.representedObject = item
            pinItem.target = self
            menu.addItem(pinItem)
        }
        
        return menu
    }
    
    // Create context menu for pinned items
    func createPinnedContextMenu(for pinnedItem: PinnedClipboardItem) -> NSMenu {
        let menu = NSMenu()
        
        // Copy item
        let copyItem = NSMenuItem(title: "Copy", action: #selector(copyPinnedContextMenuItem(_:)), keyEquivalent: "")
        copyItem.representedObject = pinnedItem
        copyItem.target = self
        menu.addItem(copyItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Edit title
        let editTitleItem = NSMenuItem(title: "Edit Title", action: #selector(editPinTitle(_:)), keyEquivalent: "")
        editTitleItem.representedObject = pinnedItem
        editTitleItem.target = self
        menu.addItem(editTitleItem)
        
        // Unpin
        let unpinItem = NSMenuItem(title: "Unpin", action: #selector(removePinnedItem(_:)), keyEquivalent: "")
        unpinItem.representedObject = pinnedItem
        unpinItem.target = self
        menu.addItem(unpinItem)
        
        return menu
    }
    
    @objc func copyContextMenuItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? ClipboardItem else { return }
        copyItemToClipboard(item)
        hideClipboardManager()
    }
    
    @objc func copyPinnedContextMenuItem(_ sender: NSMenuItem) {
        guard let pinnedItem = sender.representedObject as? PinnedClipboardItem else { return }
        copyItemToClipboard(pinnedItem.originalItem)
        hideClipboardManager()
    }
}

extension AppDelegate: StatusItemViewDelegate {
    func statusItemClicked() {
        statusItem?.button?.performClick(nil)
        toggleClipboardManager()
    }
    
    func statusItemRightClicked() {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    // MARK: - Onboarding
    private func checkAndShowOnboarding() {
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

        if !hasCompletedOnboarding {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showOnboardingWindow()
            }
        }
    }

    @objc func showOnboardingWindow() {
        if onboardingWindow == nil {
            let onboardingView = OnboardingView(isPresented: Binding(
                get: { self.showOnboarding },
                set: { newValue in
                    self.showOnboarding = newValue
                    if !newValue {
                        self.onboardingWindow?.close()
                        self.onboardingWindow = nil
                    }
                }
            ))
            .environmentObject(self)

            let hostingController = NSHostingController(rootView: onboardingView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Welcome to ClipPocket"
            window.styleMask = [.titled, .closable]
            window.center()
            window.isReleasedWhenClosed = false
            window.level = .floating

            onboardingWindow = window
        }

        onboardingWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        showOnboarding = true
    }
}
