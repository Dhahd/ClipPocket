import SwiftUI
import AppKit

struct ClipboardManagerView: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @State private var hoveredItemId: UUID?
    @State private var searchText: String = ""

    var filteredItems: [ClipboardItem] {
        if searchText.isEmpty {
            return appDelegate.clipboardItems
        } else {
            return appDelegate.clipboardItems.filter { item in
                switch item.type {
                case .text, .code:
                    return (item.content as? String)?.localizedCaseInsensitiveContains(searchText) ?? false
                case .image:
                    // Images can't be searched by text, but we could potentially search by file name or dimensions
                    return false
                case .color:
                    if let colorString = item.content as? String {
                        // Search by color hex value
                        return colorString.localizedCaseInsensitiveContains(searchText)
                    }
                    return false
                }
            }
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.clear)
                .background(
                    VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                        .mask(RoundedRectangle(cornerRadius: 20))
                )
            
            VStack(spacing: 0) {
                HStack {
                    Text("Clipboard History")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Button(action: {
                        NSApp.sendAction(#selector(AppDelegate.openSettings), to: nil, from: nil)
                    }) {
                        Image(systemName: "gearshape")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Open Settings")
                    
                    Button(action: {
                        NSApp.sendAction(#selector(AppDelegate.hideClipboardManager), to: nil, from: nil)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Close")
                }
                .padding()
                
                // Modern Search Bar
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .frame(height: 36)
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .padding(.leading, 8)
                        
                        TextField("Search clipboard items", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(filteredItems) { item in
                            ClipboardItemView(item: item)
                                .frame(width: 180, height: 100)
                                .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
                                .cornerRadius(8)
                                .shadow(radius: 2)
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
                .frame(height: 120)
            }
            .padding(.vertical)
        }
        .frame(width: NSScreen.main?.visibleFrame.width ?? 600, height: 230)
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 { // 53 is the key code for Esc
                    NSApp.sendAction(#selector(AppDelegate.hideClipboardManager), to: nil, from: nil)
                    return nil
                }
                return event
            }
        }
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
