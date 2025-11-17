import Foundation
import AppKit
import Carbon

struct KeyboardShortcut: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
    let displayString: String

    static let `default` = KeyboardShortcut(
        keyCode: UInt32(kVK_ANSI_C),
        modifiers: UInt32(cmdKey | shiftKey),
        displayString: "⌘⇧C"
    )

    init(keyCode: UInt32, modifiers: UInt32, displayString: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.displayString = displayString
    }

    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard let display = KeyboardShortcut.displayString(for: event) else {
            return nil
        }

        self.keyCode = UInt32(event.keyCode)
        self.modifiers = KeyboardShortcut.carbonModifiers(from: flags)
        self.displayString = display
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var value: UInt32 = 0
        if flags.contains(.command) { value |= UInt32(cmdKey) }
        if flags.contains(.option) { value |= UInt32(optionKey) }
        if flags.contains(.shift) { value |= UInt32(shiftKey) }
        if flags.contains(.control) { value |= UInt32(controlKey) }
        return value
    }

    private static func displayString(for event: NSEvent) -> String? {
        var components: [String] = []
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if flags.contains(.control) { components.append("⌃") }
        if flags.contains(.option) { components.append("⌥") }
        if flags.contains(.shift) { components.append("⇧") }
        if flags.contains(.command) { components.append("⌘") }

        if let specialKey = event.specialKey {
            components.append(specialKey.symbol)
        } else if let characters = event.charactersIgnoringModifiers, !characters.isEmpty {
            components.append(characters.uppercased())
        } else {
            return nil
        }

        return components.joined()
    }
}

private extension NSEvent.SpecialKey {
    var symbol: String {
        switch self {
        case .delete: return "⌫"
        case .tab: return "⇥"
        case .leftArrow: return "←"
        case .rightArrow: return "→"
        case .upArrow: return "↑"
        case .downArrow: return "↓"
        default: return "?"
        }
    }
}
