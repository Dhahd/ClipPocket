import Foundation

struct ClipboardBackup: Codable {
    let version: Int
    let history: [ClipboardItem]
    let pinned: [PinnedClipboardItem]?
}

/// Handles export/import of clipboard data with filtering and limits consistent with app storage.
final class ClipboardBackupManager {
    static let shared = ClipboardBackupManager()
    private init() {}

    // Apply the same limits used elsewhere to avoid gigantic exports/imports.
    private func filteredHistory(_ items: [ClipboardItem], maxItems: Int) -> [ClipboardItem] {
        let limited = Array(items.prefix(maxItems))
        return limited.filter { item in
            if case .image = item.type,
               let data = item.content as? Data,
               data.count > 1_048_576 {
                // Skip images larger than 1MB
                return false
            }
            return true
        }
    }

    private func filteredPinned(_ items: [PinnedClipboardItem], maxItems: Int) -> [PinnedClipboardItem] {
        return Array(items.prefix(maxItems))
    }

    func exportBackup(history: [ClipboardItem], pinned: [PinnedClipboardItem], maxHistory: Int, maxPinned: Int) throws -> Data {
        let payload = ClipboardBackup(
            version: 1,
            history: filteredHistory(history, maxItems: maxHistory),
            pinned: filteredPinned(pinned, maxItems: maxPinned)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }

    func importBackup(from data: Data, maxHistory: Int, maxPinned: Int) throws -> (history: [ClipboardItem], pinned: [PinnedClipboardItem]) {
        let decoder = JSONDecoder()

        if let payload = try? decoder.decode(ClipboardBackup.self, from: data) {
            let history = filteredHistory(payload.history, maxItems: maxHistory)
            let pinned = filteredPinned(payload.pinned ?? [], maxItems: maxPinned)
            return (history, pinned)
        } else {
            // Backward compatibility: plain array of ClipboardItem
            let history = try decoder.decode([ClipboardItem].self, from: data)
            return (filteredHistory(history, maxItems: maxHistory), [])
        }
    }
}
