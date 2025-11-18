//
//  SourceAppIconCache.swift
//  ClipPocket
//
//  Created by Codex on 12/03/25.
//

import AppKit

/// Caches app icons by bundle identifier to avoid storing large TIFF blobs per clipboard entry.
final class SourceAppIconCache {
    static let shared = SourceAppIconCache()

    private var cache: [String: NSImage] = [:]
    private let lock = NSLock()

    private init() {}

    func icon(for bundleIdentifier: String?) -> NSImage? {
        guard let bundleIdentifier else { return nil }

        lock.lock()
        if let cached = cache[bundleIdentifier] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }

        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        icon.size = NSSize(width: 64, height: 64)

        lock.lock()
        cache[bundleIdentifier] = icon
        lock.unlock()

        return icon
    }
}
