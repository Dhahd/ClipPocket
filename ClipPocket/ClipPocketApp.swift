import SwiftUI
import ServiceManagement
import Cocoa
import UniformTypeIdentifiers
import Carbon

@main
struct ClipboardManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    
    var body: some Scene {
        
        Settings {
            SettingsView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        EmptyView()
            .frame(width: 0, height: 0)
            .hidden()
    }
}

extension AppDelegate {
    func setupGlobalShortcut() {
           NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
               guard let self = self else { return }
               
               let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
               let isCommand = modifiers.contains(.command)
               let isShift = modifiers.contains(.shift)
               let isCKeyCode = event.keyCode == 8 // 8 is the key code for 'C' on a standard keyboard
               
               if isCommand && isShift && isCKeyCode {
                   DispatchQueue.main.async {
                       self.toggleClipboardManager()
                   }
               }
           }
       }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var statusItem: NSStatusItem?
    @Published var clipboardItems: [ClipboardItem] = []
    @Published var isShowingSettings = true
    var timer: Timer?
    private var lastChangeCount: Int = 0
    private var isInternalCopy = false
    private var settingsWindow: NSWindow?
    private var shortcutMonitor: Any?
    private var localShortcutMonitor: Any?
    private var globalKeyMonitor: Any?
    private var clipboardMenuView: ClipboardMenuView?
    private var clipboardWindowController: ClipboardWindowController?
    private var isClipboardManagerVisible = false
    private var eventHandler: EventHandlerRef?
    private var localEventMonitor: Any?
    private let settingsManager = SettingsManager.shared

    func unregisterGlobalShortcut() {
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
    
    
    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard")
        }
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
            self.handleMouseClickOutsideWindow(event)
        }

        setLaunchAtLogin(settingsManager.launchAtLogin)

        //setupMenu()
        setupGlobalShortcut()
        startMonitoringClipboard()
        checkAccessibilityPermission()
        
        setupStatusItem()
        setupClipboardManager()
       
        NSApp.setActivationPolicy(.accessory)
        
        // Optionally, add a menu bar item (to quit the app for example)
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "☰" // You can set an icon or text
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
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !accessibilityEnabled {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permission Required"
                alert.informativeText = "ClipPocket needs Accessibility permission to monitor keyboard events for the global shortcut. Please grant permission in System Preferences > Security & Privacy > Privacy > Accessibility."
                alert.addButton(withTitle: "Open System Preferences")
                alert.addButton(withTitle: "Later")
                
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            }
        } else {
            
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
            print("Mouse clicked outside the window")
            // You can now perform any action, such as hiding the window
            hideClipboardManager()
        }
    }


        
    private var clipboardWindowFrame: NSRect?

       func setupClipboardManager() {
           let screenRect = NSScreen.main?.visibleFrame ?? .zero
           let windowHeight: CGFloat = 230
           let windowWidth: CGFloat = screenRect.width - 100  // Subtracting 100 to give some padding
           
           // Calculate the x position to center the window
           let xPosition = (screenRect.width - windowWidth) / 20
           
           clipboardWindowFrame = NSRect(x: xPosition,
                                         y: screenRect.minY, // 10 pixels from the bottom
                                         width: windowWidth,
                                         height: windowHeight)
           
           guard let windowFrame = clipboardWindowFrame else { return }
           
           clipboardWindowController = ClipboardWindowController(contentRect: windowFrame)
           
           let hostingView = NSHostingView(rootView: ClipboardManagerView().environmentObject(self))
           clipboardWindowController?.window?.contentView = hostingView
           clipboardWindowController?.window?.isReleasedWhenClosed = false
           clipboardWindowController?.window?.level = .floating
           clipboardWindowController?.window?.setFrame(windowFrame, display: false)
       }

    @objc func showClipboardManager() {
           print("Attempting to show clipboard manager")
           guard let window = clipboardWindowController?.window else {
               print("Error: Window controller or window is nil")
               return
           }
           
           if isClipboardManagerVisible {
               print("Clipboard manager is already visible")
               return
           }
           
           window.animator().alphaValue = 1
           let screenRect = NSScreen.main?.visibleFrame ?? .zero
           let finalFrame = window.frame
           
           window.setFrame(NSRect(x: finalFrame.origin.x,
                                  y: screenRect.minY - finalFrame.height,
                                  width: finalFrame.width,
                                  height: finalFrame.height),
                           display: false)
           
           window.makeKeyAndOrderFront(self)
           
           NSAnimationContext.runAnimationGroup({ context in
               context.duration = 0.3
               window.animator().setFrame(finalFrame, display: true)
           }, completionHandler: {
               NSApp.activate(ignoringOtherApps: true)
               self.isClipboardManagerVisible = true
               print("Clipboard manager shown successfully")
           })
       }
    @objc func hideClipboardManager() {
          guard let window = clipboardWindowController?.window else {
              print("Error: Window controller or window is nil")
              return
          }
          
          if !isClipboardManagerVisible {
              print("Clipboard manager is already hidden")
              return
          }
          
          NSAnimationContext.runAnimationGroup({ context in
              context.duration = 0.3
              window.animator().alphaValue = 0.0
          }, completionHandler: {
              window.orderOut(nil)
              self.isClipboardManagerVisible = false
              // Save the current frame in case it was moved
              self.clipboardWindowFrame = window.frame
          })
      }

    @objc func toggleClipboardManager() {
        if isClipboardManagerVisible {
            hideClipboardManager()
        } else {
            showClipboardManager()
        }
    }
    

    
    func showMenu() {
        if let statusItem = statusItem, let button = statusItem.button {
            let event = NSEvent.mouseEvent(with: .leftMouseUp,
                                           location: button.convert(NSPoint(x: button.bounds.midX, y: button.bounds.midY), to: nil),
                                           modifierFlags: [],
                                           timestamp: 0,
                                           windowNumber: button.window?.windowNumber ?? 0,
                                           context: nil,
                                           eventNumber: 0,
                                           clickCount: 1,
                                           pressure: 1.0)!
            NSMenu.popUpContextMenu(statusItem.menu!, with: event, for: button)
        }
    }
    
   
    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard")
        }
        
        setupMenu()
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
    
    func setupMenu() {
            let menu = NSMenu()
            
            let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
            settingsItem.target = self
            menu.addItem(settingsItem)
            
            menu.addItem(NSMenuItem.separator())
            
            let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            menu.addItem(quitItem)
            
            statusItem?.menu = menu
        }
    
    func addClipboardItem(_ item: ClipboardItem) {
        DispatchQueue.main.async {
            if !self.clipboardItems.contains(where: { $0.isEqual(to: item) }) {
                self.clipboardItems.insert(item, at: 0)
                print("Added new item. Total items: \(self.clipboardItems.count)")
                //                   self.clipboardMenuView?.updateItems()
            } else {
                print("Item already exists in clipboard history")
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
    
    func checkClipboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount && !isInternalCopy else { return }
        
        lastChangeCount = pasteboard.changeCount
        print("--- Clipboard Changed ---")
        print("Available types: \(pasteboard.types?.map { $0.rawValue } ?? [])")
        
        if let item = readClipboardItem(from: pasteboard) {
            addClipboardItem(item)
        } else {
            print("Unable to read clipboard content")
        }
        
        print("--- End of Clipboard Change ---")
    }
    
    func readClipboardItem(from pasteboard: NSPasteboard) -> ClipboardItem? {
        // Check for image
        if let image = NSImage(pasteboard: pasteboard) {
            print("Image found. Size: \(image.size)")
            if let tiffData = image.tiffRepresentation {
                return ClipboardItem(content: tiffData, type: .image)
            }
        }
        
        // Check for text
        if let string = pasteboard.string(forType: .string) {
            print("Text found: \(string.prefix(50))...")
            
            // Check if it's a color (simple hex check)
            if string.matches(regex: "^#(?:[0-9a-fA-F]{3}){1,2}$") {
                return ClipboardItem(content: string, type: .color)
            }
            
            // Check if it's code (simple check for common programming keywords)
            let codeKeywords = ["func", "class", "struct", "var", "let", "if", "else", "for", "while", "return"]
            if codeKeywords.contains(where: { string.contains($0) }) {
                return ClipboardItem(content: string, type: .code)
            }
            
            return ClipboardItem(content: string, type: .text)
        }
        
        // Check for file URL
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in urls {
                print("File URL found: \(url.absoluteString)")
                if let imageData = try? Data(contentsOf: url), let image = NSImage(data: imageData) {
                    print("Image loaded from URL")
                    return ClipboardItem(content: imageData, type: .image)
                }
            }
        }
        
        return nil
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
struct ClipboardItem: Identifiable {
    let id = UUID()
    enum ItemType {
        case text
        case image
        case color
        case code
    }
    
    let content: Any
    let type: ItemType
    
    var displayString: String {
        switch type {
        case .text, .code:
            let text = content as! String
            return text.prefix(100) + (text.count > 100 ? "..." : "")
        case .image:
            return "Image"
        case .color:
            return content as? String ?? "Invalid Color"
        }
    }
    
    func isEqual(to other: ClipboardItem) -> Bool {
        switch (self.type, other.type) {
        case (.text, .text), (.code, .code), (.color, .color):
            return (self.content as? String) == (other.content as? String)
        case (.image, .image):
            if let selfData = self.content as? Data,
               let otherData = other.content as? Data {
                return selfData == otherData
            }
            return false
        default:
            return false
        }
    }
}
extension String {
    func matches(regex: String) -> Bool {
        return self.range(of: regex, options: .regularExpression) != nil
    }
}
extension NSColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        self.init(
            red: CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgb & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgb & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }
}
