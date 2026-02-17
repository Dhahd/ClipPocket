//
//  DraggableClipboardItemCard.swift
//  ClipPocket
//
//  Created by Shaneen on 10/14/24.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct DraggableClipboardItemCard: View {
    let item: ClipboardItem
    @EnvironmentObject var dragDropManager: DragDropManager
    @EnvironmentObject var appDelegate: AppDelegate
    @ObservedObject private var settings = SettingsManager.shared
    var isBeingDragged = false
    
    var body: some View {
        ClipboardItemCard(item: item)
            .onDrag {
                appDelegate.toggleClipboardManager()
                self.dragDropManager.draggedItem = self.item
                let provider = NSItemProvider()
                switch item.type {
                case .text, .code, .color, .url, .email, .phone, .json:
                    if let stringContent = item.content as? String {
                        provider.registerObject(stringContent as NSString, visibility: .all)
                    }
                case .richText:
                    if let info = item.content as? [String: Any],
                       let plainText = info["plainText"] as? String {
                        provider.registerObject(plainText as NSString, visibility: .all)
                    }
                case .image:
                    if let imageData = item.content as? Data,
                       let image = NSImage(data: imageData) {
                        provider.registerObject(image, visibility: .all)
                    }
                case .file:
                    if let url = item.content as? URL {
                        provider.registerObject(url as NSURL, visibility: .all)
                    }
                }

                return provider
            } preview: {
                ClipboardItemCard(item: item)
                    .frame(width: settings.cardWidth, height: settings.cardHeight)
            }
    }
}
class DragDropManager: ObservableObject {
    @Published var draggedItem: ClipboardItem?
}
