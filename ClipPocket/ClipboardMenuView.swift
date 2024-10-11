import SwiftUI

struct ClipboardMenuView: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @State private var hoveredItemId: UUID?
    
    var body: some View {
        VStack {
            Spacer()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(appDelegate.clipboardItems) { item in
                        ClipboardItemView(item: item)
                            .frame(width: 180, height: 100)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(30)
                            .shadow(radius: 2)
                            .onHover { isHovered in
                                hoveredItemId = isHovered ? item.id : nil
                            }
                            .scaleEffect(hoveredItemId == item.id ? 1.05 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: hoveredItemId)
                            .onTapGesture {
                                appDelegate.copyItemToClipboard(item)
                            }
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 120)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 600, height: 150)
    }
}

struct ClipboardItemView: View {
    let item: ClipboardItem
    
    var body: some View {
        VStack {
            switch item.type {
            case .text:
                textView
            case .image:
                imageView
            case .color:
                colorView
            case .code:
                codeView
            }
        }
        .frame(width: 180, height: 100)
        .background(backgroundForType)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var textView: some View {
        Text(item.displayString)
            .font(.system(size: 12))
            .padding(5)
            .lineLimit(4)
    }
    
    private var imageView: some View {
        Group {
            if let imageData = item.content as? Data,
               let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 170, height: 90)
            } else {
                Text("Invalid Image")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    private var colorView: some View {
        Group {
            if let colorString = item.content as? String,
               let color = Color(hex: colorString) {
                let textColor = color.contrastingTextColor(_color: item.content as! String) // Choose light or dark text based on background color
                
                VStack {
                    Rectangle()
                        .fill(color)
                        .frame(width: 170, height: 70)
                    Text(colorString)
                        .font(.caption)
                        .foregroundColor(textColor)
                        .multilineTextAlignment(.center) // Center the text
                }
            } else {
                Text("Invalid Color")
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(width: 180, height: 100)
    }
    
    private var codeView: some View {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 10, height: 10)
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                    Spacer()
                    Text("Code Snippet")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: "#2b2b2b"))
                
                ScrollView {
                    Text(applySyntaxHighlighting(to: item.displayString))
                        .font(.system(size: 10, design: .monospaced))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(Color(hex: "#1e1e1e"))
            .cornerRadius(8)
        }
    
    private func applySyntaxHighlighting(to code: String) -> AttributedString {
            var attributedString = AttributedString(code)
            
            let keywords = ["func", "var", "let", "if", "else", "for", "while", "return", "class", "struct", "enum"]
            let types = ["String", "Int", "Double", "Bool", "Array", "Dictionary"]
            
            for keyword in keywords {
                if let range = attributedString.range(of: keyword) {
                    attributedString[range].foregroundColor = .purple
                    attributedString[range].font = .system(size: 10, weight: .bold, design: .monospaced)
                }
            }
            
            for type in types {
                if let range = attributedString.range(of: type) {
                    attributedString[range].foregroundColor = .blue
                }
            }
            
            // Highlight string literals
            let stringPattern = "\"[^\"]*\""
            if let regex = try? NSRegularExpression(pattern: stringPattern) {
                let nsRange = NSRange(code.startIndex..., in: code)
                for match in regex.matches(in: code, options: [], range: nsRange) {
                    if let range = Range(match.range, in: code) {
                        let matchedString = String(code[range])
                        if let attributedRange = attributedString.range(of: matchedString) {
                            attributedString[attributedRange].foregroundColor = .green
                        }
                    }
                }
            }
            
            return attributedString
        }
    
    private var backgroundForType: some View {
            Group {
                switch item.type {
                case .text:
                    Color(NSColor.textBackgroundColor)
                case .image:
                    Color(NSColor.windowBackgroundColor)
                case .color:
                    Color(NSColor.windowBackgroundColor)
                case .code:
                    Color(hex: "#1e1e1e") // Dark background for code
                }
            }
        }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
    func luminance(_color: String) -> Double {
           var red: CGFloat = 0
           var green: CGFloat = 0
           var blue: CGFloat = 0
           
        if let cgColor = Color.init(hex: _color)?.cgColor?.components {
               red = cgColor[0]
               green = cgColor[1]
               blue = cgColor[2]
           }
           
           // Luminance formula for sRGB colors
           return 0.299 * Double(red) + 0.587 * Double(green) + 0.114 * Double(blue)
       }
       
       // Choose light or dark based on the luminance
    func contrastingTextColor(_color: String) -> Color {
        return self.luminance(_color: _color) > 0.5 ? .black : .white
       }
}
