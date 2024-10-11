import SwiftUI
import Cocoa
import UniformTypeIdentifiers
import Carbon

@main
struct ClipboardManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    
      var body: some Scene {
          WindowGroup {
              ContentView()
                  .environmentObject(appDelegate)
          }
          .windowStyle(HiddenTitleBarWindowStyle())
          
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

    func applicationDidFinishLaunching(_ notification: Notification) {
           NSApp.setActivationPolicy(.accessory)
           
           statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
           if let button = statusItem?.button {
               button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard")
           }
           
           setupMenu()
           startMonitoringClipboard()
           setupGlobalKeyMonitor()
           
           NotificationCenter.default.addObserver(self, selector: #selector(shortcutChanged), name: Notification.Name("ShortcutChanged"), object: nil)
       }
       
       func setupGlobalKeyMonitor() {
           // Remove existing monitor if any
           if let existingMonitor = globalKeyMonitor {
               NSEvent.removeMonitor(existingMonitor)
           }
           
           globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
               self?.handleKeyEvent(event)
           }
       }
       
       func handleKeyEvent(_ event: NSEvent) {
           let shortcut = UserDefaults.standard.string(forKey: "shortcut") ?? ""
           let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
           var pressedShortcut = ""
           
           if modifiers.contains(.control) { pressedShortcut += "⌃" }
           if modifiers.contains(.option) { pressedShortcut += "⌥" }
           if modifiers.contains(.shift) { pressedShortcut += "⇧" }
           if modifiers.contains(.command) { pressedShortcut += "⌘" }
           
           if let specialKey = event.specialKey {
               pressedShortcut += specialKey.description
           } else if let characters = event.charactersIgnoringModifiers?.uppercased(), !characters.isEmpty {
               pressedShortcut += characters
           }
           
           if pressedShortcut == shortcut {
               DispatchQueue.main.async { [weak self] in
                   self?.showMenu()
               }
           }
       }
       
       @objc func shortcutChanged() {
           setupGlobalKeyMonitor()
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
       
       
    
      func setupMenu() {
          statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
          if let button = statusItem?.button {
              button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard")
          }
          
          let menu = NSMenu()
          
          let containerItem = NSMenuItem()
          let hostingView = NSHostingView(rootView: ClipboardMenuView().environmentObject(self))
          hostingView.frame = NSRect(x: 0, y: 0, width: 600, height: 150)
          containerItem.view = hostingView
          menu.addItem(containerItem)
          
          menu.addItem(NSMenuItem.separator())
          
          let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
          settingsItem.target = self
          menu.addItem(settingsItem)
          
          menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
          
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
            case .text:
                if let textContent = item.content as? String {
                    pasteboard.setString(textContent, forType: .string)
                }
            case .image:
                if let imageData = item.content as? Data, let image = NSImage(data: imageData) {
                    pasteboard.writeObjects([image])
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

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        updateMenuItems()
    }
    
    func updateMenuItems() {
        guard let menu = statusItem?.menu else { return }
        menu.removeAllItems()
        
        for (index, item) in clipboardItems.enumerated() {
            let menuItem = NSMenuItem()
            menuItem.title = item.displayString
            menuItem.target = self
            menuItem.action = #selector(menuItemClicked(_:))
            menuItem.tag = index
            
            if item.type == .image, let imageData = item.content as? Data, let image = NSImage(data: imageData) {
                let thumbnail = NSImage(size: NSSize(width: 20, height: 20))
                thumbnail.lockFocus()
                let drawRect = NSRect(x: 0, y: 0, width: 20, height: 20)
                image.draw(in: drawRect, from: .zero, operation: .copy, fraction: 1.0)
                thumbnail.unlockFocus()
                menuItem.image = thumbnail
            }
            
            menu.addItem(menuItem)
        }
        
        if clipboardItems.isEmpty {
            let emptyItem = NSMenuItem(title: "No items", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        }
        
    }
    
    @objc func menuItemClicked(_ sender: NSMenuItem) {
        let item = clipboardItems[sender.tag]
        copyItemToClipboard(item)
        statusItem?.menu?.cancelTracking()
    }
}

struct ClipboardItem: Identifiable {
    let id = UUID()
    enum ItemType {
        case text
        case image
    }
    
    let content: Any
    let type: ItemType
    
    var displayString: String {
        switch type {
        case .text:
            let text = content as! String
            return text.prefix(30) + (text.count > 30 ? "..." : "")
        case .image:
            return ""
        }
    }
    
    func isEqual(to other: ClipboardItem) -> Bool {
        switch (self.type, other.type) {
        case (.text, .text):
            return (self.content as? String) == (other.content as? String)
        case (.image, .image):
            if let selfData = self.content as? Data,
               let otherData = other.content as? Data {
                // Compare image data directly
                return selfData == otherData
            }
            return false
        default:
            return false
        }
    }
}
