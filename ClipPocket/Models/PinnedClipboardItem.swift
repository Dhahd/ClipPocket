//
//  PinnedClipboardItem.swift
//  ClipPocket
//
//  Created by Shaneen on 22/5/25.
//


import Foundation

class PinnedClipboardItem: ObservableObject, Identifiable, Codable {
    let id: UUID
    let originalItem: ClipboardItem
    let pinnedDate: Date
    @Published var customTitle: String?
    
    init(from item: ClipboardItem, customTitle: String? = nil) {
        self.id = UUID()
        self.originalItem = item
        self.pinnedDate = Date()
        self.customTitle = customTitle
    }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, originalItem, pinnedDate, customTitle
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        originalItem = try container.decode(ClipboardItem.self, forKey: .originalItem)
        pinnedDate = try container.decode(Date.self, forKey: .pinnedDate)
        customTitle = try container.decodeIfPresent(String.self, forKey: .customTitle)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(originalItem, forKey: .originalItem)
        try container.encode(pinnedDate, forKey: .pinnedDate)
        try container.encodeIfPresent(customTitle, forKey: .customTitle)
    }
    
    // MARK: - Helper Properties
    var displayTitle: String {
        return customTitle ?? originalItem.displayString
    }
    
    var displayString: String {
        return originalItem.displayString
    }
    
    var contentType: ClipboardItem.ItemType {
        return originalItem.type
    }
}
