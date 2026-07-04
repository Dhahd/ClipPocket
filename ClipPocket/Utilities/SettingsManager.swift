import Foundation
import Combine
import SwiftUI

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
        static let autoShowDelay = "autoShowDelay"
        static let autoHideDelay = "autoHideDelay"
        static let captureRichText = "captureRichText"
        static let snippetsEnabled = "snippetsEnabled"
        static let densityMode = "densityMode"
        static let fontSizeScale = "fontSizeScale"
        static let themeOverride = "themeOverride"
        static let encryptHistory = "encryptHistory"
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

    /// Resolved history cap actually enforced at runtime.
    /// When the user disables the limit, this is `.max` (no application-level cap);
    /// memory pressure is managed by the per-item image filter, not a count ceiling.
    var effectiveHistoryLimit: Int {
        Self.effectiveHistoryLimit(
            enableHistoryLimit: enableHistoryLimit,
            maxHistoryItems: maxHistoryItems
        )
    }

    static func effectiveHistoryLimit(enableHistoryLimit: Bool, maxHistoryItems: Int) -> Int {
        guard enableHistoryLimit else { return .max }
        return max(1, maxHistoryItems)
    }

    @Published var autoShowOnEdge: Bool {
        didSet {
            defaults.set(autoShowOnEdge, forKey: Keys.autoShowOnEdge)
        }
    }

    @Published var autoShowDelay: Double {
        didSet {
            defaults.set(autoShowDelay, forKey: Keys.autoShowDelay)
        }
    }

    @Published var autoHideDelay: Double {
        didSet {
            defaults.set(autoHideDelay, forKey: Keys.autoHideDelay)
        }
    }

    @Published var captureRichText: Bool {
        didSet {
            defaults.set(captureRichText, forKey: Keys.captureRichText)
        }
    }

    @Published var snippetsEnabled: Bool {
        didSet {
            defaults.set(snippetsEnabled, forKey: Keys.snippetsEnabled)
        }
    }

    @Published var densityMode: String {
        didSet {
            defaults.set(densityMode, forKey: Keys.densityMode)
        }
    }

    @Published var fontSizeScale: Double {
        didSet {
            defaults.set(fontSizeScale, forKey: Keys.fontSizeScale)
        }
    }

    @Published var themeOverride: String {
        didSet {
            defaults.set(themeOverride, forKey: Keys.themeOverride)
        }
    }

    @Published var encryptHistory: Bool {
        didSet {
            defaults.set(encryptHistory, forKey: Keys.encryptHistory)
        }
    }

    @Published var keyboardShortcut: KeyboardShortcut {
        didSet {
            persistKeyboardShortcut()
        }
    }

    // MARK: - Appearance Computed Properties

    var isCompact: Bool { densityMode == "compact" }
    var cardWidth: CGFloat { isCompact ? 180 : 240 }
    var cardHeight: CGFloat { isCompact ? 140 : 180 }
    var cardHeaderHeight: CGFloat { isCompact ? 36 : 48 }
    var cardCornerRadius: CGFloat { isCompact ? 10 : 12 }
    var cardSpacing: CGFloat { isCompact ? 10 : 16 }
    var panelHeight: CGFloat { isCompact ? 250 : 300 }
    var pinnedCardWidth: CGFloat { isCompact ? 150 : 200 }
    var pinnedCardHeight: CGFloat { isCompact ? 90 : 120 }
    var emptyStateWidth: CGFloat { isCompact ? 190 : 250 }
    var emptyStateHeight: CGFloat { isCompact ? 90 : 120 }

    func scaledFont(_ baseSize: CGFloat) -> CGFloat {
        baseSize * fontSizeScale
    }

    var resolvedColorScheme: ColorScheme? {
        switch themeOverride {
        case "dark": return .dark
        case "light": return .light
        default: return nil
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

        // Set default for autoShowDelay if not set (0.3 seconds default)
        if defaults.object(forKey: Keys.autoShowDelay) == nil {
            defaults.set(0.3, forKey: Keys.autoShowDelay)
        }
        self.autoShowDelay = defaults.double(forKey: Keys.autoShowDelay)

        // Set default for autoHideDelay if not set (0.5 seconds default)
        if defaults.object(forKey: Keys.autoHideDelay) == nil {
            defaults.set(0.5, forKey: Keys.autoHideDelay)
        }
        self.autoHideDelay = defaults.double(forKey: Keys.autoHideDelay)

        // Set default for captureRichText if not set (enabled by default)
        if defaults.object(forKey: Keys.captureRichText) == nil {
            defaults.set(true, forKey: Keys.captureRichText)
        }
        self.captureRichText = defaults.bool(forKey: Keys.captureRichText)

        // Set default for snippetsEnabled if not set (enabled by default)
        if defaults.object(forKey: Keys.snippetsEnabled) == nil {
            defaults.set(true, forKey: Keys.snippetsEnabled)
        }
        self.snippetsEnabled = defaults.bool(forKey: Keys.snippetsEnabled)

        // Set default for densityMode if not set
        if defaults.object(forKey: Keys.densityMode) == nil {
            defaults.set("comfortable", forKey: Keys.densityMode)
        }
        self.densityMode = defaults.string(forKey: Keys.densityMode) ?? "comfortable"

        // Set default for fontSizeScale if not set
        if defaults.object(forKey: Keys.fontSizeScale) == nil {
            defaults.set(1.0, forKey: Keys.fontSizeScale)
        }
        self.fontSizeScale = defaults.double(forKey: Keys.fontSizeScale)

        // Set default for themeOverride if not set
        if defaults.object(forKey: Keys.themeOverride) == nil {
            defaults.set("dark", forKey: Keys.themeOverride)
        }
        self.themeOverride = defaults.string(forKey: Keys.themeOverride) ?? "dark"

        // Set default for encryptHistory if not set (disabled by default)
        if defaults.object(forKey: Keys.encryptHistory) == nil {
            defaults.set(false, forKey: Keys.encryptHistory)
        }
        self.encryptHistory = defaults.bool(forKey: Keys.encryptHistory)
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
        autoShowDelay = 0.3
        autoHideDelay = 0.5
        captureRichText = true
        snippetsEnabled = true
        densityMode = "comfortable"
        fontSizeScale = 1.0
        themeOverride = "dark"
        encryptHistory = false
    }
}
