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



import SwiftUI

struct ClipboardItemView: View {
    let item: ClipboardItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with source app icon
            HStack {
                Text(item.type.rawValue)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                sourceAppIcon
            }
            
            // Content
            contentView
            
            // Footer
            HStack {
                Image(systemName: item.icon)
                    .foregroundColor(.secondary)
                if item.type != .image {
                    Text("\(item.displayString.count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(item.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .frame(width: 200, height: 150)
        .background(Color(.textBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var sourceAppIcon: some View {
        Group {
            if let icon = item.sourceApplication?.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
            } else {
                Image(systemName: "app.dashed")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var contentView: some View {
        Group {
            switch item.type {
            case .text, .code:
                Text(item.displayString)
                    .lineLimit(4)
                    .font(.system(size: 12, design: .monospaced))
            case .image:
                if let imageData = item.content as? Data,
                   let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 80)
                } else {
                    Text("Invalid Image")
                        .foregroundColor(.red)
                }
            case .color:
                if let colorString = item.content as? String,
                   let color = Color(hex: colorString) {
                    HStack {
                        Rectangle()
                            .fill(color)
                            .frame(width: 20, height: 20)
                        Text(colorString)
                            .font(.caption2)
                    }
                } else {
                    Text("Invalid Color")
                        .foregroundColor(.red)
                }
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
