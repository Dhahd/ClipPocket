import Foundation
import Combine

class PinnedClipboardManager: ObservableObject {
    @Published var pinnedItems: [PinnedClipboardItem] = []
    private let userDefaults = UserDefaults.standard
    private let pinnedItemsKey = "PinnedClipboardItems"
    
    init() {
        loadPinnedItems()
    }
    
    // MARK: - Public Methods
    func pinItem(_ item: ClipboardItem, customTitle: String? = nil) {
        // Check if item is already pinned
        if !isPinned(item) {
            let pinnedItem = PinnedClipboardItem(from: item, customTitle: customTitle)
            pinnedItems.append(pinnedItem)
            savePinnedItems()
        }
    }
    
    func unpinItem(_ pinnedItem: PinnedClipboardItem) {
        pinnedItems.removeAll { $0.id == pinnedItem.id }
        savePinnedItems()
    }
    
    func unpinItem(withOriginalId originalId: UUID) {
        pinnedItems.removeAll { $0.originalItem.id == originalId }
        savePinnedItems()
    }
    
    func isPinned(_ item: ClipboardItem) -> Bool {
        return pinnedItems.contains { $0.originalItem.id == item.id }
    }
    
    func updateCustomTitle(for pinnedItem: PinnedClipboardItem, title: String?) {
        if let index = pinnedItems.firstIndex(where: { $0.id == pinnedItem.id }) {
            pinnedItems[index].customTitle = title
            savePinnedItems()
        }
    }
    
    func reorderPinnedItems(from source: IndexSet, to destination: Int) {
        pinnedItems.move(fromOffsets: source, toOffset: destination)
        savePinnedItems()
    }
    
    // MARK: - Private Methods
    private func loadPinnedItems() {
        guard let data = userDefaults.data(forKey: pinnedItemsKey) else { return }
        
        do {
            let decoder = JSONDecoder()
            pinnedItems = try decoder.decode([PinnedClipboardItem].self, from: data)
        } catch {
            print("Failed to load pinned items: \(error)")
            pinnedItems = []
        }
    }
    
    private func savePinnedItems() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(pinnedItems)
            userDefaults.set(data, forKey: pinnedItemsKey)
        } catch {
            print("Failed to save pinned items: \(error)")
        }
    }
}