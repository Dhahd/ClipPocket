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
                            .cornerRadius(8)
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
            if item.type == .text {
                Text(item.displayString)
                    .lineLimit(3)
                    .font(.system(size: 12))
            } else if item.type == .image,
                      let imageData = item.content as? Data,
                      let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .padding(5)
    }
}
