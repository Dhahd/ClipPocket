struct ClipboardItemCard: View {
    @EnvironmentObject var appDelegate: AppDelegate

    let item: ClipboardItem
    @State private var headerColor: Color = .blue
    @State private var isHovered: Bool = false
    var body: some View {
        VStack(spacing: 0) {
            // Header
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
                    Text(item.type.rawValue)
                        .font(.system(size: 14, weight: .bold))
                    Text(item.timestamp, style: .relative)
                        .font(.system(size: 12, weight: .thin))
                }
                .padding(.trailing, 12)
            }
            .frame(height: 48)
            .foregroundColor(.white)
            .background(headerColor)
            
            // Content area
            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 240, height: 180)
        .background(
            ZStack {
                VisualEffectView(material: .fullScreenUI, blendingMode: .behindWindow)
                Color(red: 0.12, green: 0.12, blue: 0.12).opacity(0.3)
            }
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(isHovered ? 0.3 : 0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(isHovered ? 0.2 : 0), radius: 10, x: 0, y: 5)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            if let sourceIcon = item.sourceIcon {
                headerColor = Color(vibrantColorFrom: sourceIcon)
            }
        }
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
                .font(.system(size: 14))
                .foregroundColor(Color(red: 0.8, green: 0.8, blue: 0.8))
                .padding(12)
        case .code:
            codeView
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
            if let colorString = item.content as? String,
               let color = Color(hex: colorString) {
                ZStack {
                    color
                    Text(colorString)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(color.contrastingTextColor(colorString))
                }
            }
        }
    }
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
        case .text, .code, .color:
            if typeIdentifier == UTType.utf8PlainText.identifier,
               let stringContent = item.content as? String,
               let data = stringContent.data(using: .utf8) {
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