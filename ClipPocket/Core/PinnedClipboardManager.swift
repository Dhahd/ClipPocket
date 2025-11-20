//
//  PinnedClipboardManager.swift
//  ClipPocket
//
//  Created by Shaneen on 22/5/25.
//


import Foundation
import Combine

class PinnedClipboardManager: ObservableObject {
    @Published var pinnedItems: [PinnedClipboardItem] = []
    private let userDefaults = UserDefaults.standard
    private let pinnedItemsKey = "PinnedClipboardItems"
    private let maxPinnedItems = 50 // Reasonable limit for pinned items
    
    init() {
        loadPinnedItems()
    }
    
    // MARK: - Public Methods
    
    func pinItem(_ item: ClipboardItem, customTitle: String? = nil) {
        // Check if item is already pinned using the same logic as AppDelegate
        if !isPinned(item) {
            let pinnedItem = PinnedClipboardItem(from: item, customTitle: customTitle)
            pinnedItems.insert(pinnedItem, at: 0) // Add to beginning like regular clipboard items
            
            // Trim the list if it exceeds the limit
            if pinnedItems.count > maxPinnedItems {
                pinnedItems = Array(pinnedItems.prefix(maxPinnedItems))
            }
            
            savePinnedItems()
            print("Pinned item: \(item.displayString)")
        }
    }
    
    func unpinItem(_ pinnedItem: PinnedClipboardItem) {
        if let index = pinnedItems.firstIndex(where: { $0.id == pinnedItem.id }) {
            let removedItem = pinnedItems.remove(at: index)
            savePinnedItems()
            print("Unpinned item: \(removedItem.displayString)")
        }
    }
    
    func unpinItem(withOriginalId originalId: UUID) {
        if let index = pinnedItems.firstIndex(where: { $0.originalItem.id == originalId }) {
            let removedItem = pinnedItems.remove(at: index)
            savePinnedItems()
            print("Unpinned item by original ID: \(removedItem.displayString)")
        }
    }
    
    func isPinned(_ item: ClipboardItem) -> Bool {
        // Use the same equality check as the main clipboard logic
        return pinnedItems.contains { pinnedItem in
            pinnedItem.originalItem.isEqual(to: item)
        }
    }
    
    func getPinnedItem(for originalItem: ClipboardItem) -> PinnedClipboardItem? {
        return pinnedItems.first { pinnedItem in
            pinnedItem.originalItem.isEqual(to: originalItem)
        }
    }
    
    func updateCustomTitle(for pinnedItem: PinnedClipboardItem, title: String?) {
        if let index = pinnedItems.firstIndex(where: { $0.id == pinnedItem.id }) {
            pinnedItems[index].customTitle = title?.isEmpty == true ? nil : title
            savePinnedItems()
            print("Updated title for pinned item: \(title ?? "No title")")
        }
    }
    
    func reorderPinnedItems(from source: IndexSet, to destination: Int) {
        pinnedItems.move(fromOffsets: source, toOffset: destination)
        savePinnedItems()
        print("Reordered pinned items")
    }

    func replaceAll(with items: [PinnedClipboardItem]) {
        pinnedItems = Array(items.prefix(maxPinnedItems))
        savePinnedItems()
        print("Replaced pinned items from import")
    }
    
    func clearAllPinnedItems() {
        pinnedItems.removeAll()
        savePinnedItems()
        print("Cleared all pinned items")
    }
    
    // MARK: - Filtering and Search
    
    func filteredPinnedItems(searchText: String) -> [PinnedClipboardItem] {
        if searchText.isEmpty {
            return pinnedItems
        } else {
            return pinnedItems.filter { item in
                // Search in both custom title and original content, case-insensitive
                let searchTextLower = searchText.lowercased()
                return item.displayString.lowercased().contains(searchTextLower) ||
                       item.displayTitle.lowercased().contains(searchTextLower)
            }
        }
    }
    
    func pinnedItemsByType(_ type: ClipboardItem.ItemType) -> [PinnedClipboardItem] {
        return pinnedItems.filter { $0.contentType == type }
    }
    
    // MARK: - Private Methods
    
    private func loadPinnedItems() {
        guard let data = userDefaults.data(forKey: pinnedItemsKey) else {
            print("No saved pinned items found")
            return
        }

        let containsLegacyIcons = data.range(of: Data("\"sourceIcon\"".utf8)) != nil
        
        do {
            let decoder = JSONDecoder()
            let loadedItems = try decoder.decode([PinnedClipboardItem].self, from: data)
            
            // Filter out any corrupted items following the same pattern as clipboard validation
            pinnedItems = loadedItems.compactMap { pinnedItem in
                // Basic validation similar to how clipboard items are handled
                if pinnedItem.originalItem.displayString.isEmpty {
                    print("Removing corrupted pinned item with empty content")
                    return nil
                }
                return pinnedItem
            }
            
            print("Loaded \(pinnedItems.count) pinned items")

            // If we stripped legacy icon payloads, rewrite the payload to shrink memory footprint
            if containsLegacyIcons {
                savePinnedItems()
                print("🧹 Rewrote pinned items without embedded icons")
            }
        } catch {
            print("Failed to load pinned items: \(error.localizedDescription)")
            pinnedItems = []
            
            // Clear corrupted data, similar to how the app handles other corrupted data
            userDefaults.removeObject(forKey: pinnedItemsKey)
        }
    }
    
    private func savePinnedItems() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(pinnedItems)
            userDefaults.set(data, forKey: pinnedItemsKey)
            // No need for synchronize() in modern apps, UserDefaults handles this
            print("Saved \(pinnedItems.count) pinned items")
        } catch {
            print("Failed to save pinned items: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Utility Methods
    
    var pinnedItemsCount: Int {
        return pinnedItems.count
    }
    
    func movePinnedItemToTop(_ pinnedItem: PinnedClipboardItem) {
        // Move a pinned item to the top when accessed, similar to how regular clipboard works
        if let index = pinnedItems.firstIndex(where: { $0.id == pinnedItem.id }) {
            let movedItem = pinnedItems.remove(at: index)
            pinnedItems.insert(movedItem, at: 0)
            savePinnedItems()
        }
    }
    
    func validateDataIntegrity() -> Bool {
        // Check for duplicate content (not IDs, since each pinned item has unique ID)
        var contentSet = Set<String>()
        
        for item in pinnedItems {
            let contentKey = item.originalItem.displayString
            if contentSet.contains(contentKey) {
                print("Warning: Found duplicate pinned item content")
                return false
            }
            contentSet.insert(contentKey)
            
            if item.originalItem.displayString.isEmpty {
                print("Warning: Found pinned item with empty content")
                return false
            }
        }
        
        return true
    }
}
