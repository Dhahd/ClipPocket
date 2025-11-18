//
//  ClipboardItem.swift
//  ClipPocket
//
//  Created by Shaneen on 10/15/24.
//


import AppKit

struct ClipboardItem: Identifiable, Codable {
    var id = UUID()
    let content: Any
    let type: ItemType
    let timestamp: Date
    let sourceBundleIdentifier: String?
    
    init(content: Any, type: ItemType, timestamp: Date, sourceApplication: NSRunningApplication?) {
        self.content = content
        self.type = type
        self.timestamp = timestamp
        self.sourceBundleIdentifier = sourceApplication?.bundleIdentifier
    }

    init(content: Any, type: ItemType, timestamp: Date, sourceBundleIdentifier: String?) {
        self.content = content
        self.type = type
        self.timestamp = timestamp
        self.sourceBundleIdentifier = sourceBundleIdentifier
    }
    
    enum ItemType: String, Codable {
        case text = "doc.text"
        case image = "photo"
        case color = "paintpalette"
        case code = "chevron.left.forwardslash.chevron.right"
        case url = "link"
        case email = "envelope"
        case phone = "phone"
        case json = "curlybraces"
        case file = "doc.fill"

        var typeDisplayName: String {
            switch self {
            case .text: return "Text"
            case .image: return "Image"
            case .color: return "Color"
            case .code: return "Code"
            case .url: return "URL"
            case .email: return "Email"
            case .phone: return "Phone"
            case .json: return "JSON"
            case .file: return "File"
            }
        }
    }
    
    var displayString: String {
        switch type {
        case .text, .code, .url, .email, .phone, .json:
            return String((content as? String)?.prefix(100) ?? "Invalid Text")
        case .image:
            return "Image"
        case .color:
            return content as? String ?? "Invalid Color"
        case .file:
            if let url = content as? URL {
                return url.lastPathComponent
            } else if let path = content as? String {
                return (path as NSString).lastPathComponent
            }
            return "File"
        }
    }

    var typeDisplayName: String {
        switch type {
        case .text: return "Text"
        case .image: return "Image"
        case .color: return "Color"
        case .code: return "Code"
        case .url: return "URL"
        case .email: return "Email"
        case .phone: return "Phone"
        case .json: return "JSON"
        case .file: return "File"
        }
    }
    
    var icon: String {
        return type.rawValue
    }

    var sourceIcon: NSImage? {
        SourceAppIconCache.shared.icon(for: sourceBundleIdentifier)
    }

    var sourceApplication: NSRunningApplication? {
        guard let bundleId = sourceBundleIdentifier else { return nil }
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first
    }
    
    func isEqual(to other: ClipboardItem) -> Bool {
        switch (self.type, other.type) {
        case (.text, .text), (.code, .code), (.color, .color), (.url, .url), (.email, .email), (.phone, .phone), (.json, .json):
            return (self.content as? String) == (other.content as? String)
        case (.image, .image):
            if let selfData = self.content as? Data,
               let otherData = other.content as? Data {
                return selfData == otherData
            }
            return false
        case (.file, .file):
            if let selfURL = self.content as? URL,
               let otherURL = other.content as? URL {
                return selfURL.path == otherURL.path
            }
            if let selfPath = self.content as? String,
               let otherPath = other.content as? String {
                return selfPath == otherPath
            }
            return false
        default:
            return false
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, content, type, timestamp, sourceBundleIdentifier, sourceApplication, sourceIcon
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(timestamp, forKey: .timestamp)
        
        // Encode content based on type
        switch type {
        case .text, .code, .color, .url, .email, .phone, .json:
            try container.encode(content as? String, forKey: .content)
        case .image:
            if let imageData = content as? Data {
                try container.encode(imageData, forKey: .content)
            } else if let imageData = (content as? NSImage)?.tiffRepresentation {
                try container.encode(imageData, forKey: .content)
            }
        case .file:
            if let url = content as? URL {
                try container.encode(url.path, forKey: .content)
            } else if let path = content as? String {
                try container.encode(path, forKey: .content)
            }
        }
        
        // Only persist the lightweight bundle identifier. Icons are resolved lazily from cache.
        try container.encodeIfPresent(sourceBundleIdentifier, forKey: .sourceBundleIdentifier)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(ItemType.self, forKey: .type)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        
        // Decode content based on type
        switch type {
        case .text, .code, .color, .url, .email, .phone, .json:
            content = try container.decode(String.self, forKey: .content)
        case .image:
            if let imageData = try container.decodeIfPresent(Data.self, forKey: .content) {
                content = imageData
            } else {
                content = Data()
            }
        case .file:
            if let path = try container.decodeIfPresent(String.self, forKey: .content) {
                content = URL(fileURLWithPath: path)
            } else {
                content = URL(fileURLWithPath: "")
            }
        }
        
        // Prefer new lightweight key; fall back to legacy field for backwards compatibility.
        sourceBundleIdentifier = try container.decodeIfPresent(String.self, forKey: .sourceBundleIdentifier)
            ?? container.decodeIfPresent(String.self, forKey: .sourceApplication)
    }
}

extension String {
    func matches(regex: String) -> Bool {
        return self.range(of: regex, options: .regularExpression) != nil
    }
}
