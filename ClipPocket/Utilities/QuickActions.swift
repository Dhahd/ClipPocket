import Foundation
import AppKit
import CoreImage
import UniformTypeIdentifiers
import UserNotifications

class QuickActions {
    static let shared = QuickActions()

    private init() {}

    // MARK: - Export
    func exportToFile(_ item: ClipboardItem) {
        DispatchQueue.main.async {
            let savePanel = NSSavePanel()
            let exportInfo = self.exportInfo(for: item)
            savePanel.nameFieldStringValue = exportInfo.fileName
            savePanel.allowedContentTypes = exportInfo.allowedTypes

            savePanel.begin { response in
                if response == .OK, let url = savePanel.url {
                    self.saveItem(item, to: url)
                }
            }
        }
    }

    private func exportInfo(for item: ClipboardItem) -> (fileName: String, allowedTypes: [UTType]) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let dateString = dateFormatter.string(from: item.timestamp)

        switch item.type {
        case .text, .code, .json:
            return ("clipboard-\(dateString).txt", [.plainText, .utf8PlainText])
        case .image:
            return ("clipboard-\(dateString).png", [.png])
        case .url, .email, .phone:
            return ("clipboard-\(dateString).txt", [.plainText, .utf8PlainText])
        case .color:
            return ("clipboard-\(dateString).txt", [.plainText, .utf8PlainText])
        case .file:
            if let fileURL = item.content as? URL {
                let utType = UTType(filenameExtension: fileURL.pathExtension) ?? .data
                return (fileURL.lastPathComponent, [utType])
            }
            return ("clipboard-\(dateString).txt", [.data])
        }
    }

    private func saveItem(_ item: ClipboardItem, to url: URL) {
        do {
            switch item.type {
            case .text, .code, .url, .email, .phone, .json, .color:
                if let text = item.content as? String {
                    try text.write(to: url, atomically: true, encoding: .utf8)
                } else {
                    throw NSError(domain: "ClipPocket", code: 1, userInfo: [NSLocalizedDescriptionKey: "No text content to export."])
                }
            case .image:
                if let imageData = item.content as? Data {
                    try imageData.write(to: url)
                } else {
                    throw NSError(domain: "ClipPocket", code: 2, userInfo: [NSLocalizedDescriptionKey: "No image data to export."])
                }
            case .file:
                if let fileURL = item.content as? URL {
                    if FileManager.default.fileExists(atPath: url.path) {
                        try FileManager.default.removeItem(at: url)
                    }
                    try FileManager.default.copyItem(at: fileURL, to: url)
                } else if let path = item.content as? String {
                    let sourceURL = URL(fileURLWithPath: path)
                    if FileManager.default.fileExists(atPath: url.path) {
                        try FileManager.default.removeItem(at: url)
                    }
                    try FileManager.default.copyItem(at: sourceURL, to: url)
                } else {
                    throw NSError(domain: "ClipPocket", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unable to resolve file to export."])
                }
            }

            // Show success notification
            showNotification(title: "Saved Successfully", message: "Item saved to \(url.lastPathComponent)")
        } catch {
            showNotification(title: "Save Failed", message: error.localizedDescription)
        }
    }

    // MARK: - QR Code
    func generateQRCode(for text: String) -> NSImage? {
        let data = text.data(using: .utf8)

        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")

        guard let ciImage = filter.outputImage else { return nil }

        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledCIImage = ciImage.transformed(by: transform)

        let rep = NSCIImageRep(ciImage: scaledCIImage)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)

        return nsImage
    }

    func showQRCode(for item: ClipboardItem) {
        guard case .text = item.type else { return }
        guard let text = item.content as? String else { return }

        DispatchQueue.main.async {
            if let qrImage = self.generateQRCode(for: text) {
                // Create a window to display QR code
                let window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 400, height: 450),
                    styleMask: [.titled, .closable],
                    backing: .buffered,
                    defer: false
                )
                window.title = "QR Code"
                window.center()

                let imageView = NSImageView(frame: NSRect(x: 50, y: 50, width: 300, height: 300))
                imageView.image = qrImage
                imageView.imageScaling = .scaleProportionallyUpOrDown

                let saveButton = NSButton(frame: NSRect(x: 150, y: 10, width: 100, height: 30))
                saveButton.title = "Save QR Code"
                saveButton.bezelStyle = .rounded
                saveButton.target = self
                saveButton.action = #selector(self.saveQRCode(_:))
                saveButton.tag = qrImage.hashValue

                window.contentView?.addSubview(imageView)
                window.contentView?.addSubview(saveButton)
                window.makeKeyAndOrderFront(nil)

                // Store image for save action
                self.qrCodeCache[qrImage.hashValue] = qrImage
            }
        }
    }

    private var qrCodeCache: [Int: NSImage] = [:]

    @objc private func saveQRCode(_ sender: NSButton) {
        guard let qrImage = qrCodeCache[sender.tag] else { return }

        DispatchQueue.main.async {
            let savePanel = NSSavePanel()
            savePanel.nameFieldStringValue = "qrcode.png"
            savePanel.allowedContentTypes = [.png]

            savePanel.begin { response in
                if response == .OK, let url = savePanel.url {
                    if let tiffData = qrImage.tiffRepresentation,
                       let bitmapRep = NSBitmapImageRep(data: tiffData),
                       let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                        try? pngData.write(to: url)
                        self.showNotification(title: "QR Code Saved", message: "Saved to \(url.lastPathComponent)")
                    }
                }
            }
        }
    }

    // MARK: - Share
    func shareItem(_ item: ClipboardItem, from view: NSView) {
        var itemsToShare: [Any] = []

        switch item.type {
        case .text, .code, .url, .email, .phone, .json, .color:
            if let text = item.content as? String {
                itemsToShare.append(text)
            }
        case .image:
            if let imageData = item.content as? Data,
               let image = NSImage(data: imageData) {
                itemsToShare.append(image)
            }
        case .file:
            if let url = item.content as? URL {
                itemsToShare.append(url)
            }
        }

        guard !itemsToShare.isEmpty else { return }

        let picker = NSSharingServicePicker(items: itemsToShare)
        picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    }

    // MARK: - Copy as Different Format
    func copyAsJSON(_ text: String) {
        let jsonString = text.replacingOccurrences(of: "\"", with: "\\\"")
        let formatted = "\"\(jsonString)\""

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(formatted, forType: .string)

        showNotification(title: "Copied as JSON", message: "Text copied as JSON string")
    }

    func copyAsBase64(_ text: String) {
        if let data = text.data(using: .utf8) {
            let base64 = data.base64EncodedString()

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(base64, forType: .string)

            showNotification(title: "Copied as Base64", message: "Text copied as Base64")
        }
    }

    // MARK: - Notifications
    private func showNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
