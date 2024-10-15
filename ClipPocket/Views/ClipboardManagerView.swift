import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ClipboardManagerView: View {
    @StateObject private var dragDropManager = DragDropManager()
    @StateObject private var clipboardManager = ClipboardManager()
    
    var body: some View {
        ClipboardManagerContent()
            .environmentObject(dragDropManager)
            .environmentObject(clipboardManager)
    }
}

struct ClipboardManagerContent: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @State private var hoveredItemId: UUID?
    @State private var searchText: String = ""
    
    var filteredItems: [ClipboardItem] {
        if searchText.isEmpty {
            return appDelegate.clipboardItems
        } else {
            return appDelegate.clipboardItems.filter { item in
                item.displayString.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Top bar with search, sections, and buttons
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
                            DraggableClipboardItemCard(item: item)
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
                    .padding()
                }
                Spacer(minLength: 0)
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
    let isEmphasized: Bool
    
    init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        isEmphasized: Bool = true
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.isEmphasized = isEmphasized
    }
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.isEmphasized = isEmphasized
        
        // Increase the blur radius
        visualEffectView.animator().alphaValue = 1
        
        return visualEffectView
    }
    
    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.isEmphasized = isEmphasized
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

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

