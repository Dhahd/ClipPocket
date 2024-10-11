import Foundation
import Combine

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let launchAtLogin = "launchAtLogin"
        static let shortcut = "shortcut"
        // Add any other settings keys here
    }
    
    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
        }
    }
    
    @Published var shortcut: String {
        didSet {
            defaults.set(shortcut, forKey: Keys.shortcut)
        }
    }
    
    // Add any other settings properties here
    
    private init() {
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        self.shortcut = defaults.string(forKey: Keys.shortcut) ?? ""
    }
    
    func resetToDefaults() {
        launchAtLogin = false
        shortcut = ""
        // Reset any other settings to their default values
    }
}
