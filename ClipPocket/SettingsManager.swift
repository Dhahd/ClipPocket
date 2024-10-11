import Foundation

class SettingsManager {
    static let shared = SettingsManager()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let launchAtLogin = "launchAtLogin"
        static let shortcut = "shortcut"
        // Add any other settings keys here
    }
    
    var launchAtLogin: Bool {
        get { defaults.bool(forKey: Keys.launchAtLogin) }
        set { defaults.set(newValue, forKey: Keys.launchAtLogin) }
    }
    
    var shortcut: String {
        get { defaults.string(forKey: Keys.shortcut) ?? "" }
        set { defaults.set(newValue, forKey: Keys.shortcut) }
    }
    
    // Add any other settings properties here
    
    private init() {}
    
    func resetToDefaults() {
        launchAtLogin = false
        shortcut = ""
        // Reset any other settings to their default values
    }
}