import Foundation
import Combine

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let launchAtLogin = "launchAtLogin"
        static let keyboardShortcut = "keyboardShortcut"
        static let rememberHistory = "rememberHistory"
        static let showRecent = "showRecent"
        static let showPinned = "showPinned"
        static let autoPasteEnabled = "autoPasteEnabled"
    }
    
    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
        }
    }
    
    @Published var rememberHistory: Bool {
        didSet {
            defaults.set(rememberHistory, forKey: Keys.rememberHistory)
        }
    }
    
    @Published var showRecent: Bool {
        didSet {
            defaults.set(showRecent, forKey: Keys.showRecent)
        }
    }
    
    @Published var showPinned: Bool {
        didSet {
            defaults.set(showPinned, forKey: Keys.showPinned)
        }
    }

    @Published var autoPasteEnabled: Bool {
        didSet {
            defaults.set(autoPasteEnabled, forKey: Keys.autoPasteEnabled)
        }
    }

    @Published var keyboardShortcut: KeyboardShortcut {
        didSet {
            persistKeyboardShortcut()
        }
    }
    
    private init() {
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)

        // Load keyboard shortcut from UserDefaults or use default
        if let shortcutData = defaults.data(forKey: Keys.keyboardShortcut),
           let shortcut = try? JSONDecoder().decode(KeyboardShortcut.self, from: shortcutData) {
            self.keyboardShortcut = shortcut
        } else {
            self.keyboardShortcut = .default
        }

        // Set default for rememberHistory if not set
        if defaults.object(forKey: Keys.rememberHistory) == nil {
            defaults.set(true, forKey: Keys.rememberHistory)
        }
        self.rememberHistory = defaults.bool(forKey: Keys.rememberHistory)

        // Set default values for layout toggles if not already set
        if defaults.object(forKey: Keys.showRecent) == nil {
            self.showRecent = true
            defaults.set(true, forKey: Keys.showRecent)
        } else {
            self.showRecent = defaults.bool(forKey: Keys.showRecent)
        }

        if defaults.object(forKey: Keys.showPinned) == nil {
            self.showPinned = true
            defaults.set(true, forKey: Keys.showPinned)
        } else {
            self.showPinned = defaults.bool(forKey: Keys.showPinned)
        }

        // Set default for autoPasteEnabled if not set
        if defaults.object(forKey: Keys.autoPasteEnabled) == nil {
            defaults.set(false, forKey: Keys.autoPasteEnabled)
        }
        self.autoPasteEnabled = defaults.bool(forKey: Keys.autoPasteEnabled)
    }

    private func persistKeyboardShortcut() {
        if let data = try? JSONEncoder().encode(keyboardShortcut) {
            defaults.set(data, forKey: Keys.keyboardShortcut)
        }
    }
    
    func resetToDefaults() {
        launchAtLogin = false
        keyboardShortcut = .default
        rememberHistory = true
        showRecent = true
        showPinned = true
        autoPasteEnabled = false
    }
}
