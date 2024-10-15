import Foundation
import Combine

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let launchAtLogin = "launchAtLogin"
        static let shortcut = "shortcut"
        static let rememberHistory = "rememberHistory"
        static let showRecent = "showRecent"
        static let showPinned = "showPinned"
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
    
    @Published var shortcut: String {
        didSet {
            defaults.set(shortcut, forKey: Keys.shortcut)
        }
    }
    
    private init() {
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        self.shortcut = defaults.string(forKey: Keys.shortcut) ?? ""
        self.rememberHistory = defaults.bool(forKey: Keys.rememberHistory)
        self.showRecent = defaults.bool(forKey: Keys.showRecent)
        self.showPinned = defaults.bool(forKey: Keys.showPinned)
        
        // Set default values if not already set
        if (defaults.object(forKey: Keys.showRecent) == nil) {
            self.showRecent = true
            defaults.set(true, forKey: Keys.showRecent)
        }
        if (defaults.object(forKey: Keys.showPinned) == nil) {
            self.showPinned = true
            defaults.set(true, forKey: Keys.showPinned)
        }
    }
    
    func resetToDefaults() {
        launchAtLogin = false
        shortcut = ""
        rememberHistory = true
        showRecent = true
        showPinned = true
    }
}
