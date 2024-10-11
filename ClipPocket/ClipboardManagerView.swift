import SwiftUI
import AppKit

struct ClipboardManagerView: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @State private var hoveredItemId: UUID?
    @State private var searchText: String = ""
    
    var filteredItems: [ClipboardItem] {
        appDelegate.clipboardItems.filter { item in
            searchText.isEmpty || item.displayString.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Top bar with search and buttons
                HStack {
                    SearchBar(text: $searchText)
                        .frame(width: 200)
                    
                    Spacer()
                    
                    Button(action: {
                        NSApp.sendAction(#selector(AppDelegate.openSettings), to: nil, from: nil)
                    }) {
                        Image(systemName: "gearshape")
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Open Settings")
                    
                    Button(action: {
                        NSApp.sendAction(#selector(AppDelegate.hideClipboardManager), to: nil, from: nil)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Close")
                }
                .padding()
                .background(Color.black.opacity(0.2))
                
                // Clipboard items
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(filteredItems) { item in
                            ClipboardItemCard(item: item)
                                .onHover { isHovered in
                                    hoveredItemId = isHovered ? item.id : nil
                                }
                                .scaleEffect(hoveredItemId == item.id ? 1.05 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: hoveredItemId)
                                .onTapGesture {
                                    appDelegate.copyItemToClipboard(item)
                                    NSApp.sendAction(#selector(AppDelegate.hideClipboardManager), to: nil, from: nil)
                                }
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer(minLength: 0) // This ensures content stays at the top
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            .background(VisualEffectView(material: .windowBackground, blendingMode: .behindWindow))
        }
    }
}

struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white)
            TextField("Search", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(.white)
        }
        .padding(8)
        .background(Color.white.opacity(0.2))
        .cornerRadius(8)
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }
    
    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}

struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(isSelected ? Color.blue : Color.clear)
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(15)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ClipboardItemCard: View {
    let item: ClipboardItem
    @State private var headerColor: Color = .blue // Default color
    
    var body: some View {
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 0) {
                    if let sourceIcon = item.sourceIcon {
                        Image(nsImage: sourceIcon)
                            .resizable()
                            .offset(x: -10)
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 65, height: 55) // Match header height
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
                .frame(height: 48) // Fixed header height
                .foregroundColor(.white)
                .background(headerColor)
                
                // Content area
                contentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(width: 240, height: 180)
            .background(Color(red: 0.12, green: 0.12, blue: 0.12))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .onAppear {
                if let sourceIcon = item.sourceIcon {
                    headerColor = Color(vibrantColorFrom: sourceIcon)
                }
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
            ScrollView {
                SyntaxHighlightedText(text: item.displayString)
                    .padding(12)
            }
        case .image:
            if let imageData = item.content as? Data,
               let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .padding(12)
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

import SwiftUI

struct SyntaxHighlightedText: View {
    let text: String
    
    var body: some View {
        Text(AttributedString(highlightSyntax(text)))
            .font(.system(size: 12, design: .monospaced))
    }
    
    private func highlightSyntax(_ code: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: code)
        
        // Define patterns and colors for syntax highlighting
        let patterns: [(String, Color)] = [
            // Keywords
            ("\\b(func|let|var|if|else|for|while|return|struct|class|enum|switch|case|import|guard|defer|do|try|catch|throw|where|in|init|self|super|true|false|nil)\\b", .pink),
            
            // Types and Class names
            ("\\b[A-Z][A-Za-z0-9_]*\\b", .blue),
            
            // Function calls
            ("\\b[a-z][A-Za-z0-9_]*(?=\\()", .green),
            
            // Strings
            ("\".*?\"", .red),
            
            // Numbers
            ("\\b\\d+(\\.\\d+)?\\b", .orange),
            
            // Comments
            ("//.*", .gray),
            ("/\\*[\\s\\S]*?\\*/", .gray),
            
            // Attributes
            ("@\\w+", .purple),
            
            // Operators
            ("(\\+|-|\\*|/|%|=|>|<|\\?|\\!|:|&|\\|)", .yellow),
            
            // Parentheses and Brackets
            ("(\\(|\\)|\\{|\\}|\\[|\\])", .cyan)
        ]
        
        for (pattern, color) in patterns {
            let regex = try? NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(location: 0, length: code.utf16.count)
            regex?.enumerateMatches(in: code, options: [], range: range) { match, _, _ in
                if let matchRange = match?.range {
                    attributedString.addAttribute(.foregroundColor, value: NSColor(color), range: matchRange)
                }
            }
        }
        
        return attributedString
    }
}
extension Color {
    func contrastingTextColor(_ colorString: String) -> Color {
        let luminance = self.luminance(colorString)
        return luminance > 0.5 ? .black : .white
    }
    
    func luminance(_ colorString: String) -> Double {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        
        if let color = NSColor(hex: colorString) {
            red = color.redComponent
            green = color.greenComponent
            blue = color.blueComponent
        }
        
        return 0.299 * Double(red) + 0.587 * Double(green) + 0.114 * Double(blue)
    }
}

// Extension to create Color from NSImage

import CoreImage


extension Color {
    init(vibrantColorFrom image: NSImage) {
        let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        let inputImage = CIImage(cgImage: cgImage)
        let extentVector = CIVector(x: inputImage.extent.origin.x, y: inputImage.extent.origin.y, z: inputImage.extent.size.width, w: inputImage.extent.size.height)

        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]) else {
            self.init(.blue) // Fallback color
            return
        }
        guard let outputImage = filter.outputImage else {
            self.init(.blue) // Fallback color
            return
        }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull!])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        // Convert to HSB
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        NSColor(red: CGFloat(bitmap[0]) / 255, green: CGFloat(bitmap[1]) / 255, blue: CGFloat(bitmap[2]) / 255, alpha: 1).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)

        // Adjust HSB values for more vibrant colors
        saturation = min(saturation * 1.7, 1.0)  // Increase saturation by 70%
        brightness = min(brightness * 1.3, 1.0)  // Increase brightness by 30%

        // Convert back to RGB
        let color = NSColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: nil)

        // Set the final color
        self.init(red: Double(red), green: Double(green), blue: Double(blue))
    }
}
