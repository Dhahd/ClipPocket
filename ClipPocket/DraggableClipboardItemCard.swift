
struct DraggableClipboardItemCard: View {
    let item: ClipboardItem
    @EnvironmentObject var dragDropManager: DragDropManager
    
    var body: some View {
        ClipboardItemCard(item: item)
            .onDrag {
                self.dragDropManager.draggedItem = self.item
                
                let provider = NSItemProvider()
                
                switch item.type {
                case .text, .code, .color:
                    if let stringContent = item.content as? String {
                        provider.registerObject(stringContent as NSString, visibility: .all)
                    }
                case .image:
                    if let imageData = item.content as? Data,
                       let image = NSImage(data: imageData) {
                        provider.registerObject(image, visibility: .all)
                    }
                }
                
                return provider
            } preview: {
                ClipboardItemCard(item: item)
                    .frame(width: 240, height: 180)
            }
    }
}
class DragDropManager: ObservableObject {
    @Published var draggedItem: ClipboardItem?
}
