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
        static let maxHistoryItems = "maxHistoryItems"
        static let enableHistoryLimit = "enableHistoryLimit"
        static let autoShowOnEdge = "autoShowOnEdge"
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

    @Published var maxHistoryItems: Int {
        didSet {
            defaults.set(maxHistoryItems, forKey: Keys.maxHistoryItems)
        }
    }

    @Published var enableHistoryLimit: Bool {
        didSet {
            defaults.set(enableHistoryLimit, forKey: Keys.enableHistoryLimit)
        }
    }

    @Published var autoShowOnEdge: Bool {
        didSet {
            defaults.set(autoShowOnEdge, forKey: Keys.autoShowOnEdge)
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

        // Set default for maxHistoryItems if not set
        if defaults.object(forKey: Keys.maxHistoryItems) == nil {
            defaults.set(100, forKey: Keys.maxHistoryItems)
        }
        self.maxHistoryItems = defaults.integer(forKey: Keys.maxHistoryItems)

        // Set default for enableHistoryLimit if not set (disabled by default for backward compatibility)
        if defaults.object(forKey: Keys.enableHistoryLimit) == nil {
            defaults.set(false, forKey: Keys.enableHistoryLimit)
        }
        self.enableHistoryLimit = defaults.bool(forKey: Keys.enableHistoryLimit)

        // Set default for autoShowOnEdge if not set
        if defaults.object(forKey: Keys.autoShowOnEdge) == nil {
            defaults.set(false, forKey: Keys.autoShowOnEdge)
        }
        self.autoShowOnEdge = defaults.bool(forKey: Keys.autoShowOnEdge)
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
        maxHistoryItems = 100
        enableHistoryLimit = false
        autoShowOnEdge = false
    }
}
