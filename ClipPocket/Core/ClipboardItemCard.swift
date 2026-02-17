//
//  ClipboardItemCard.swift
//  ClipPocket
//
//  Created by Shaneen on 10/14/24.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit


struct ClipboardItemCard: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @ObservedObject private var settings = SettingsManager.shared

    let item: ClipboardItem
    @State private var headerColor: Color = .blue

    var body: some View {
        VStack(spacing: 0) {
            // Header with glass effect
            HStack(spacing: 0) {
                if let sourceIcon = item.sourceIcon {
                    Image(nsImage: sourceIcon)
                        .resizable()
                        .offset(x: -10)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 65, height: 55)
                        .clipped()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(item.typeDisplayName)
                        .font(.system(size: settings.scaledFont(14), weight: .bold))
                    Text(item.timestamp, style: .relative)
                        .font(.system(size: settings.scaledFont(12), weight: .thin))
                }
                .padding(.trailing, 12)
            }
            .frame(height: settings.cardHeaderHeight)
            .foregroundColor(.white)
            .background(
                ZStack {
                    headerColor

                    // Glass overlay
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.clear,
                            Color.black.opacity(0.2)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            )
            
            // Content area
            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: settings.cardWidth, height: settings.cardHeight)
        .background(
            ZStack {
                if let cardColor = colorFromItem() {
                    cardColor
                } else {
                    VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                }

                // Gradient overlay for depth
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.08),
                        Color.clear,
                        Color.black.opacity(0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .cornerRadius(settings.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: settings.cardCornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.primary.opacity(0.15),
                            Color.primary.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        .onAppear {
            if item.type == .color, let cardColor = colorFromItem() {
                headerColor = cardColor
            } else if let sourceIcon = item.sourceIcon {
                headerColor = Color(vibrantColorFrom: sourceIcon)
            }
        }
    }
    
    private func colorFromItem() -> Color? {
        guard item.type == .color, let colorString = item.content as? String else { return nil }
        if let nsColor = NSColor(hex: colorString) {
            return Color(nsColor: nsColor)
        }
        return nil
    }

    @ViewBuilder
    var codeView: some View {
        SyntaxHighlightedCodeView(code: item.displayString, sourceIDE: determineSourceIDE(item))
        }
    func determineSourceIDE(_ item: ClipboardItem) -> SourceIDE {
        if (item.displayString.contains("xcode")) {
            return .xcode
        }
        else {
            return .androidStudio
        }
    }
    
    @ViewBuilder
    var contentView: some View {
        switch item.type {
        case .text:
            Text(item.displayString)
                .font(.system(size: settings.scaledFont(14)))
                .foregroundColor(.primary)
                .padding(12)
        case .code:
            codeView
        case .url:
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "link")
                    .font(.system(size: settings.scaledFont(32)))
                    .foregroundColor(.blue)
                Text(item.displayString)
                    .font(.system(size: settings.scaledFont(12)))
                    .foregroundColor(.primary)
                    .lineLimit(4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(12)
        case .email:
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: settings.scaledFont(32)))
                    .foregroundColor(.cyan)
                Text(item.displayString)
                    .font(.system(size: settings.scaledFont(14)))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(12)
        case .phone:
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "phone.fill")
                    .font(.system(size: settings.scaledFont(32)))
                    .foregroundColor(.green)
                Text(item.displayString)
                    .font(.system(size: settings.scaledFont(16), weight: .medium))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(12)
        case .json:
            ScrollView {
                Text(item.displayString)
                    .font(.system(size: settings.scaledFont(11), design: .monospaced))
                    .foregroundColor(.primary)
                    .padding(12)
            }
        case .image:
            if let imageData = item.content as? Data,
               let nsImage = NSImage(data: imageData) {
                GeometryReader { geometry in
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: geometry.size.width - 24, maxHeight: geometry.size.height - 24)
                        .background(Color(NSColor.textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(12)
                }
            }
        case .color:
            if let colorString = item.content as? String {
                let color = colorFromItem() ?? Color.gray
                ZStack {
                    color
                    Text(colorString)
                        .font(.system(size: settings.scaledFont(20), weight: .bold))
                        .foregroundColor(color.contrastingTextColor(colorString))
                }
            }
        case .file:
            VStack(alignment: .leading, spacing: 10) {
                // File icon
                if let url = item.content as? URL {
                    let fileExtension = url.pathExtension.lowercased()
                    let iconName = getFileIconName(for: fileExtension)

                    Image(systemName: iconName)
                        .font(.system(size: 40))
                        .foregroundColor(getFileIconColor(for: fileExtension))
                } else {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                }

                // File name
                Text(item.displayString)
                    .font(.system(size: settings.scaledFont(13), weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                // File path
                if let url = item.content as? URL {
                    Text(url.path)
                        .font(.system(size: settings.scaledFont(10)))
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    // File info
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                       let fileSize = attributes[.size] as? Int64 {
                        Text(formatFileSize(fileSize))
                            .font(.system(size: settings.scaledFont(10)))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(12)
        case .richText:
            RichTextPreviewView(richTextInfo: item.content as? [String: Any])
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(12)
        }
    }

    private func getFileIconName(for extension: String) -> String {
        switch `extension` {
        case "pdf": return "doc.text.fill"
        case "doc", "docx": return "doc.richtext.fill"
        case "xls", "xlsx": return "tablecells.fill"
        case "ppt", "pptx": return "rectangle.stack.fill"
        case "zip", "rar", "7z": return "archivebox.fill"
        case "jpg", "jpeg", "png", "gif", "bmp": return "photo.fill"
        case "mp4", "mov", "avi": return "video.fill"
        case "mp3", "wav", "m4a": return "music.note"
        case "swift", "js", "py", "java", "cpp": return "chevron.left.forwardslash.chevron.right"
        default: return "doc.fill"
        }
    }

    private func getFileIconColor(for extension: String) -> Color {
        switch `extension` {
        case "pdf": return .red
        case "doc", "docx": return .blue
        case "xls", "xlsx": return .green
        case "ppt", "pptx": return .orange
        case "zip", "rar", "7z": return .purple
        case "jpg", "jpeg", "png", "gif", "bmp": return .cyan
        case "mp4", "mov", "avi": return .pink
        case "mp3", "wav", "m4a": return .purple
        case "swift", "js", "py", "java", "cpp": return .mint
        default: return .gray
        }
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}


struct RichTextPreviewView: View {
    let richTextInfo: [String: Any]?

    var body: some View {
        if let info = richTextInfo,
           let rtfData = info["rtfData"] as? Data {
            RichTextNSViewRepresentable(rtfData: rtfData)
        } else if let info = richTextInfo,
                  let plainText = info["plainText"] as? String {
            Text(plainText)
                .font(.system(size: SettingsManager.shared.scaledFont(12)))
                .foregroundColor(.primary)
                .lineLimit(6)
        } else {
            Text("Rich Text")
                .foregroundColor(.gray)
        }
    }
}

struct RichTextNSViewRepresentable: NSViewRepresentable {
    let rtfData: Data

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = false
        textView.backgroundColor = .clear
        textView.drawsBackground = false

        if let attrStr = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
            let mutable = NSMutableAttributedString(attributedString: attrStr)
            // Scale font for preview
            let fullRange = NSRange(location: 0, length: mutable.length)
            mutable.enumerateAttribute(.font, in: fullRange) { value, range, _ in
                if let font = value as? NSFont {
                    let newFont = NSFont(descriptor: font.fontDescriptor, size: min(font.pointSize, 11)) ?? NSFont.systemFont(ofSize: 11)
                    mutable.addAttribute(.font, value: newFont, range: range)
                }
            }
            textView.textStorage?.setAttributedString(mutable)
        }

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {}
}

class ClipboardItemWrapper: NSObject, NSItemProviderWriting, NSItemProviderReading {
    static var writableTypeIdentifiersForItemProvider: [String] {
            return [UTType.utf8PlainText.identifier, UTType.image.identifier]
        }
        
        static var readableTypeIdentifiersForItemProvider: [String] {
            return [UTType.utf8PlainText.identifier, UTType.image.identifier]
        }
        
        let item: ClipboardItem
        
        required init(_ item: ClipboardItem) {
            self.item = item
            super.init()
        }
    
    func loadData(withTypeIdentifier typeIdentifier: String, forItemProviderCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void) -> Progress? {

        switch item.type {
        case .text, .code, .color, .url, .email, .phone, .json:
            if typeIdentifier == UTType.utf8PlainText.identifier,
               let stringContent = item.content as? String,
               let data = stringContent.data(using: .utf8) {
                completionHandler(data, nil)
            } else {
                completionHandler(nil, NSError(domain: "ClipboardItemError", code: -1, userInfo: nil))
            }
        case .richText:
            if typeIdentifier == UTType.utf8PlainText.identifier,
               let info = item.content as? [String: Any],
               let plainText = info["plainText"] as? String,
               let data = plainText.data(using: .utf8) {
                completionHandler(data, nil)
            } else {
                completionHandler(nil, NSError(domain: "ClipboardItemError", code: -1, userInfo: nil))
            }
        case .image:
            if typeIdentifier == UTType.image.identifier,
               let imageData = item.content as? Data {
                completionHandler(imageData, nil)
            } else {
                completionHandler(nil, NSError(domain: "ClipboardItemError", code: -1, userInfo: nil))
            }
        case .file:
            if let url = item.content as? URL,
               let data = url.absoluteString.data(using: .utf8) {
                completionHandler(data, nil)
            } else {
                completionHandler(nil, NSError(domain: "ClipboardItemError", code: -1, userInfo: nil))
            }
        }
        return nil
    }
    
    static func object(withItemProviderData data: Data, typeIdentifier: String) throws -> Self {
            let content: Any
            let type: ClipboardItem.ItemType
            if typeIdentifier == UTType.utf8PlainText.identifier {
                guard let string = String(data: data, encoding: .utf8) else {
                    throw NSError(domain: "ClipboardItemError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode text data"])
                }
                content = string
                type = .text // You might want to determine if it's .code or .color based on the content
            } else if typeIdentifier == UTType.image.identifier {
                content = data
                type = .image
            } else {
                throw NSError(domain: "ClipboardItemError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unsupported type identifier"])
            }
            
            let clipboardItem = ClipboardItem(content: content, type: type, timestamp: Date(), sourceApplication: nil)
            return self.init(clipboardItem)
        }
}
