import Foundation
import AppKit

class ExcludedAppsManager: ObservableObject {
    static let shared = ExcludedAppsManager()

    @Published var excludedBundleIds: Set<String> = []

    private let defaults = UserDefaults.standard
    private let excludedAppsKey = "excludedApps"

    // Common sensitive apps that should be excluded by default
    private let defaultExcludedApps: Set<String> = [
        "com.agilebits.onepassword7",  // 1Password
        "com.lastpass.LastPass",        // LastPass
        "com.dashlane.dashlanephonefinal", // Dashlane
        "com.bitwarden.desktop",        // Bitwarden
        "com.apple.keychainaccess",     // Keychain Access
    ]

    private init() {
        loadExcludedApps()
    }

    func loadExcludedApps() {
        if let savedApps = defaults.array(forKey: excludedAppsKey) as? [String] {
            excludedBundleIds = Set(savedApps)
        } else {
            // First time - use defaults
            excludedBundleIds = defaultExcludedApps
            saveExcludedApps()
        }
    }

    func saveExcludedApps() {
        defaults.set(Array(excludedBundleIds), forKey: excludedAppsKey)
    }

    func isAppExcluded(_ bundleId: String?) -> Bool {
        guard let bundleId = bundleId else { return false }
        return excludedBundleIds.contains(bundleId)
    }

    func excludeApp(_ bundleId: String) {
        excludedBundleIds.insert(bundleId)
        saveExcludedApps()
    }

    func includeApp(_ bundleId: String) {
        excludedBundleIds.remove(bundleId)
        saveExcludedApps()
    }

    func toggleApp(_ bundleId: String) {
        if excludedBundleIds.contains(bundleId) {
            includeApp(bundleId)
        } else {
            excludeApp(bundleId)
        }
    }

    func resetToDefaults() {
        excludedBundleIds = defaultExcludedApps
        saveExcludedApps()
    }
}
