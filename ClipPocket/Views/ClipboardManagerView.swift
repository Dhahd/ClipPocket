import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ClipboardManagerView: View {
    @StateObject private var dragDropManager = DragDropManager()

    var body: some View {
        ClipboardManagerContent()
            .environmentObject(dragDropManager)
    }
}

struct ClipboardManagerContent: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @EnvironmentObject var pinnedManager: PinnedClipboardManager
    @EnvironmentObject var dragDropManager: DragDropManager
    @State private var hoveredItemId: UUID?
    @State private var searchText: String = ""
    @State private var selectedSection: ClipboardSection = .recent
    @State private var selectedIndex: Int = 0
    @FocusState private var searchFieldFocused: Bool
    @State private var isSearchFieldFocused: Bool = false
    @State private var filterType: ClipboardItem.ItemType?

    enum ClipboardSection: String, CaseIterable {
        case pinned = "Pinned"
        case recent = "Recent"
        case history = "History"

        var displayName: String {
            return self.rawValue
        }
    }

    var filteredRecentItems: [ClipboardItem] {
        var items = Array(appDelegate.clipboardItems.prefix(20)) // Recent = last 20 items

        // Filter by type if selected
        if let type = filterType {
            items = items.filter { $0.type == type }
        }

        // Filter by search text with fuzzy matching
        if !searchText.isEmpty {
            items = items.filter { item in
                fuzzyMatch(searchText, in: item.displayString)
            }
        }

        return items
    }

    var filteredHistoryItems: [ClipboardItem] {
        var items = appDelegate.clipboardItems

        // Filter by type if selected
        if let type = filterType {
            items = items.filter { $0.type == type }
        }

        // Filter by search text with fuzzy matching
        if !searchText.isEmpty {
            items = items.filter { item in
                fuzzyMatch(searchText, in: item.displayString)
            }
        }

        return items
    }

    var filteredPinnedItems: [PinnedClipboardItem] {
        var items = pinnedManager.pinnedItems

        // Filter by type if selected
        if let type = filterType {
            items = items.filter { $0.contentType == type }
        }

        // Filter by search text
        if !searchText.isEmpty {
            items = items.filter { item in
                fuzzyMatch(searchText, in: item.displayString) ||
                fuzzyMatch(searchText, in: item.displayTitle)
            }
        }

        return items
    }

    func fuzzyMatch(_ query: String, in text: String) -> Bool {
        let query = query.lowercased()
        let text = text.lowercased()

        // First try simple contains
        if text.contains(query) {
            return true
        }

        // Then try fuzzy matching
        var queryIndex = query.startIndex
        var textIndex = text.startIndex

        while queryIndex < query.endIndex && textIndex < text.endIndex {
            if query[queryIndex] == text[textIndex] {
                queryIndex = query.index(after: queryIndex)
            }
            textIndex = text.index(after: textIndex)
        }

        return queryIndex == query.endIndex
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header with search and controls
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        SearchBar(text: $searchText, isFocused: $searchFieldFocused)
                            .frame(minWidth: 300)

                        // Type filter
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                TypeFilterButton(
                                    title: "All",
                                    icon: "square.grid.2x2",
                                    isSelected: filterType == nil,
                                    action: { filterType = nil }
                                )

                                ForEach([ClipboardItem.ItemType.text, .code, .url, .email, .image, .file, .color, .json], id: \.self) { type in
                                    TypeFilterButton(
                                        title: type.typeDisplayName,
                                        icon: type.rawValue,
                                        isSelected: filterType == type,
                                        action: { filterType = type }
                                    )
                                }
                            }
                        }
                    }

                    Spacer()

                    // Section selector
                    HStack(spacing: 4) {
                        ForEach(ClipboardSection.allCases, id: \.self) { section in
                            SectionButton(
                                title: section.displayName,
                                isSelected: selectedSection == section,
                                pinnedCount: section == .pinned ? pinnedManager.pinnedItems.count : nil
                            ) {
                                selectedSection = section
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.06))
                    )

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
                .background(
                    ZStack {
                        // Glass header with blur
                        Color.white.opacity(0.05)

                        // Top border shimmer
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 1)
                        .frame(maxHeight: .infinity, alignment: .top)
                    }
                )
                
                // Content based on selected section
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        switch selectedSection {
                        case .pinned:
                            // Pinned items section
                            if filteredPinnedItems.isEmpty {
                                EmptyPinnedView()
                            } else {
                                ForEach(filteredPinnedItems) { pinnedItem in
                                    DraggableClipboardItemCard(item: pinnedItem.originalItem)
                                        .scaleEffect(hoveredItemId == pinnedItem.id ? 1.05 : 1.0)
                                        .animation(.easeInOut(duration: 0.2), value: hoveredItemId)
                                        .onHover { isHovered in
                                            hoveredItemId = isHovered ? pinnedItem.id : nil
                                        }
                                        .onTapGesture {
                                            appDelegate.copyItemToClipboard(pinnedItem.originalItem)
                                            NSApp.sendAction(#selector(AppDelegate.hideClipboardManager), to: nil, from: nil)
                                        }
                                        .contextMenu {
                                            Button("Unpin") {
                                                pinnedManager.unpinItem(pinnedItem)
                                            }

                                            // Text transformations for text items
                                            if case .text = pinnedItem.originalItem.type, let text = pinnedItem.originalItem.content as? String {
                                                Divider()

                                                Menu("Transform Text") {
                                                    ForEach(TextTransformation.allCases, id: \.self) { transformation in
                                                        Button(action: {
                                                            let transformed = transformation.apply(to: text)
                                                            let newItem = ClipboardItem(
                                                                content: transformed,
                                                                type: .text,
                                                                timestamp: Date(),
                                                                sourceApplication: pinnedItem.originalItem.sourceApplication
                                                            )
                                                            appDelegate.clipboardItems.insert(newItem, at: 0)
                                                            appDelegate.copyItemToClipboard(newItem)
                                                        }) {
                                                            Label(transformation.rawValue, systemImage: transformation.icon)
                                                        }
                                                    }
                                                }
                                            }

                                            // Quick Actions
                                            Divider()

                                            Menu("Quick Actions") {
                                                Button(action: {
                                                    QuickActions.shared.exportToFile(pinnedItem.originalItem)
                                                }) {
                                                    Label("Save to File", systemImage: "square.and.arrow.down")
                                                }

                                                if case .text = pinnedItem.originalItem.type, let text = pinnedItem.originalItem.content as? String {
                                                    Button(action: {
                                                        QuickActions.shared.showQRCode(for: pinnedItem.originalItem)
                                                    }) {
                                                        Label("Generate QR Code", systemImage: "qrcode")
                                                    }

                                                    Divider()

                                                    Button(action: {
                                                        QuickActions.shared.copyAsJSON(text)
                                                    }) {
                                                        Label("Copy as JSON", systemImage: "curlybraces")
                                                    }

                                                    Button(action: {
                                                        QuickActions.shared.copyAsBase64(text)
                                                    }) {
                                                        Label("Copy as Base64", systemImage: "lock.shield")
                                                    }
                                                }
                                            }

                                            Divider()

                                            Button("Delete", role: .destructive) {
                                                appDelegate.deleteClipboardItem(pinnedItem.originalItem)
                                                pinnedManager.unpinItem(pinnedItem)
                                            }
                                        }
                                }
                            }

                        case .recent:
                            // Recent items section (last 20 items)
                            if filteredRecentItems.isEmpty {
                                EmptyStateView(
                                    icon: "clock",
                                    title: "No Recent Items",
                                    subtitle: "Your recent clipboard items will appear here"
                                )
                            } else {
                                ForEach(filteredRecentItems) { item in
                                    DraggableClipboardItemCard(item: item)
                                        .scaleEffect(hoveredItemId == item.id ? 1.05 : 1.0)
                                        .animation(.easeInOut(duration: 0.2), value: hoveredItemId)
                                        .onHover { isHovered in
                                            hoveredItemId = isHovered ? item.id : nil
                                        }
                                        .onTapGesture {
                                            appDelegate.copyItemToClipboard(item)
                                            NSApp.sendAction(#selector(AppDelegate.hideClipboardManager), to: nil, from: nil)
                                        }
                                        .contextMenu {
                                            if !pinnedManager.isPinned(item) {
                                                Button("Pin Item") {
                                                    pinnedManager.pinItem(item)
                                                }
                                            } else {
                                                Button("Unpin Item") {
                                                    pinnedManager.unpinItem(withOriginalId: item.id)
                                                }
                                            }

                                            // Text transformations for text items
                                            if case .text = item.type, let text = item.content as? String {
                                                Divider()

                                                Menu("Transform Text") {
                                                    ForEach(TextTransformation.allCases, id: \.self) { transformation in
                                                        Button(action: {
                                                            let transformed = transformation.apply(to: text)
                                                            let newItem = ClipboardItem(
                                                                content: transformed,
                                                                type: .text,
                                                                timestamp: Date(),
                                                                sourceApplication: item.sourceApplication
                                                            )
                                                            appDelegate.clipboardItems.insert(newItem, at: 0)
                                                            appDelegate.copyItemToClipboard(newItem)
                                                        }) {
                                                            Label(transformation.rawValue, systemImage: transformation.icon)
                                                        }
                                                    }
                                                }
                                            }

                                            // Quick Actions
                                            Divider()

                                            Menu("Quick Actions") {
                                                Button(action: {
                                                    QuickActions.shared.exportToFile(item)
                                                }) {
                                                    Label("Save to File", systemImage: "square.and.arrow.down")
                                                }

                                                if case .text = item.type, let text = item.content as? String {
                                                    Button(action: {
                                                        QuickActions.shared.showQRCode(for: item)
                                                    }) {
                                                        Label("Generate QR Code", systemImage: "qrcode")
                                                    }

                                                    Divider()

                                                    Button(action: {
                                                        QuickActions.shared.copyAsJSON(text)
                                                    }) {
                                                        Label("Copy as JSON", systemImage: "curlybraces")
                                                    }

                                                    Button(action: {
                                                        QuickActions.shared.copyAsBase64(text)
                                                    }) {
                                                        Label("Copy as Base64", systemImage: "lock.shield")
                                                    }
                                                }
                                            }

                                            Divider()

                                            Button("Delete", role: .destructive) {
                                                appDelegate.deleteClipboardItem(item)
                                            }
                                        }
                                }
                            }

                        case .history:
                            // History section (all items)
                            if filteredHistoryItems.isEmpty {
                                EmptyStateView(
                                    icon: "archivebox",
                                    title: "No History",
                                    subtitle: "Your clipboard history is empty"
                                )
                            } else {
                                ForEach(filteredHistoryItems) { item in
                                    DraggableClipboardItemCard(item: item)
                                        .scaleEffect(hoveredItemId == item.id ? 1.05 : 1.0)
                                        .animation(.easeInOut(duration: 0.2), value: hoveredItemId)
                                        .onHover { isHovered in
                                            hoveredItemId = isHovered ? item.id : nil
                                        }
                                        .onTapGesture {
                                            appDelegate.copyItemToClipboard(item)
                                            NSApp.sendAction(#selector(AppDelegate.hideClipboardManager), to: nil, from: nil)
                                        }
                                        .contextMenu {
                                            if !pinnedManager.isPinned(item) {
                                                Button("Pin Item") {
                                                    pinnedManager.pinItem(item)
                                                }
                                            } else {
                                                Button("Unpin Item") {
                                                    pinnedManager.unpinItem(withOriginalId: item.id)
                                                }
                                            }

                                            // Text transformations for text items
                                            if case .text = item.type, let text = item.content as? String {
                                                Divider()

                                                Menu("Transform Text") {
                                                    ForEach(TextTransformation.allCases, id: \.self) { transformation in
                                                        Button(action: {
                                                            let transformed = transformation.apply(to: text)
                                                            let newItem = ClipboardItem(
                                                                content: transformed,
                                                                type: .text,
                                                                timestamp: Date(),
                                                                sourceApplication: item.sourceApplication
                                                            )
                                                            appDelegate.clipboardItems.insert(newItem, at: 0)
                                                            appDelegate.copyItemToClipboard(newItem)
                                                        }) {
                                                            Label(transformation.rawValue, systemImage: transformation.icon)
                                                        }
                                                    }
                                                }
                                            }

                                            // Quick Actions
                                            Divider()

                                            Menu("Quick Actions") {
                                                Button(action: {
                                                    QuickActions.shared.exportToFile(item)
                                                }) {
                                                    Label("Save to File", systemImage: "square.and.arrow.down")
                                                }

                                                if case .text = item.type, let text = item.content as? String {
                                                    Button(action: {
                                                        QuickActions.shared.showQRCode(for: item)
                                                    }) {
                                                        Label("Generate QR Code", systemImage: "qrcode")
                                                    }

                                                    Divider()

                                                    Button(action: {
                                                        QuickActions.shared.copyAsJSON(text)
                                                    }) {
                                                        Label("Copy as JSON", systemImage: "curlybraces")
                                                    }

                                                    Button(action: {
                                                        QuickActions.shared.copyAsBase64(text)
                                                    }) {
                                                        Label("Copy as Base64", systemImage: "lock.shield")
                                                    }
                                                }
                                            }

                                            Divider()

                                            Button("Delete", role: .destructive) {
                                                appDelegate.deleteClipboardItem(item)
                                            }
                                        }
                                }
                            }
                        }
                    }
                    .padding()
                }
                Spacer(minLength: 0)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            .background(
                ZStack {
                    // Liquid glass background
                    VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)

                    // Subtle gradient overlay for depth
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.05),
                            Color.clear,
                            Color.black.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .onAppear {
                searchFieldFocused = true
                isSearchFieldFocused = true
            }
            .onChange(of: searchFieldFocused) { newValue in
                isSearchFieldFocused = newValue
            }
        }
        .background(LocalEventMonitorView(
            searchFieldFocused: $isSearchFieldFocused,
            onEscape: {
                NSApp.sendAction(#selector(AppDelegate.hideClipboardManager), to: nil, from: nil)
            },
            onEnter: {
                copySelectedItem()
            },
            onDelete: {
                deleteSelectedItem()
            }
        ))
    }

    func copySelectedItem() {
        switch selectedSection {
        case .recent:
            if selectedIndex < filteredRecentItems.count {
                appDelegate.copyItemToClipboard(filteredRecentItems[selectedIndex])
                NSApp.sendAction(#selector(AppDelegate.hideClipboardManager), to: nil, from: nil)
            }
        case .history:
            if selectedIndex < filteredHistoryItems.count {
                appDelegate.copyItemToClipboard(filteredHistoryItems[selectedIndex])
                NSApp.sendAction(#selector(AppDelegate.hideClipboardManager), to: nil, from: nil)
            }
        case .pinned:
            if selectedIndex < filteredPinnedItems.count {
                appDelegate.copyItemToClipboard(filteredPinnedItems[selectedIndex].originalItem)
                NSApp.sendAction(#selector(AppDelegate.hideClipboardManager), to: nil, from: nil)
            }
        }
    }

    func deleteSelectedItem() {
        switch selectedSection {
        case .recent:
            if selectedIndex < filteredRecentItems.count {
                let item = filteredRecentItems[selectedIndex]
                if let index = appDelegate.clipboardItems.firstIndex(where: { $0.id == item.id }) {
                    appDelegate.clipboardItems.remove(at: index)
                }
            }
        case .history:
            if selectedIndex < filteredHistoryItems.count {
                let item = filteredHistoryItems[selectedIndex]
                if let index = appDelegate.clipboardItems.firstIndex(where: { $0.id == item.id }) {
                    appDelegate.clipboardItems.remove(at: index)
                }
            }
        case .pinned:
            if selectedIndex < filteredPinnedItems.count {
                pinnedManager.unpinItem(filteredPinnedItems[selectedIndex])
            }
        }
        selectedIndex = max(0, selectedIndex - 1)
    }
}

struct LocalEventMonitorView: NSViewRepresentable {
    @Binding var searchFieldFocused: Bool
    let onEscape: () -> Void
    let onEnter: () -> Void
    let onDelete: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        // Use local event monitor to intercept keyboard events
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Always allow Escape to close the window
            if event.keyCode == 53 { // Escape
                DispatchQueue.main.async {
                    self.onEscape()
                }
                return nil // Event handled
            }

            // For other keys, check if search field is focused
            // If search field is focused, let the event pass through
            if self.searchFieldFocused {
                return event // Let the search field handle it
            }

            // Handle navigation keys when search field is not focused
            switch event.keyCode {
            case 36: // Return/Enter
                DispatchQueue.main.async {
                    self.onEnter()
                }
                return nil
            case 51: // Delete
                DispatchQueue.main.async {
                    self.onDelete()
                }
                return nil
            default:
                return event
            }
        }

        context.coordinator.monitor = monitor
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var monitor: Any?

        deinit {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}

struct TypeFilterButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.05))
            )
            .foregroundColor(isSelected ? .white : .white.opacity(0.6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        Color.white.opacity(isSelected ? 0.3 : 0),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

struct SectionButton: View {
    let title: String
    let isSelected: Bool
    let pinnedCount: Int?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))

                if let count = pinnedCount, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(isSelected ? .white.opacity(0.9) : .white.opacity(0.5))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(isSelected ? 0.2 : 0.1))
                        )
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(isSelected ? 0.15 : 0))
            )
            .foregroundColor(isSelected ? .white : .white.opacity(0.5))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        Color.white.opacity(isSelected ? 0.2 : 0),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

struct PinnedClipboardItemCard: View {
    let pinnedItem: PinnedClipboardItem
    @EnvironmentObject var pinnedManager: PinnedClipboardManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: pinnedItem.contentType.rawValue)
                    .foregroundColor(.white)
                    .font(.system(size: 16))
                
                Spacer()
                
                // Pin indicator
                Image(systemName: "pin.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 12))
            }
            
            if let customTitle = pinnedItem.customTitle {
                Text(customTitle)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                Text(pinnedItem.displayString)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(3)
            } else {
                Text(pinnedItem.displayString)
                    .font(.body)
                    .foregroundColor(.white)
                    .lineLimit(4)
            }
            
            Spacer()
            
            HStack {
                if let sourceIcon = pinnedItem.originalItem.sourceIcon {
                    Image(nsImage: sourceIcon)
                        .resizable()
                        .frame(width: 16, height: 16)
                }
                
                Spacer()
                
                Text(DateFormatter.timeOnly.string(from: pinnedItem.pinnedDate))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(12)
        .frame(width: 200, height: 120)
        .background(
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)

                // Glass gradient with yellow tint for pinned items
                LinearGradient(
                    colors: [
                        Color.yellow.opacity(0.08),
                        Color.clear,
                        Color.black.opacity(0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.yellow.opacity(0.5),
                            Color.yellow.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color.yellow.opacity(0.1), radius: 6, x: 0, y: 3)
        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}

struct EmptyPinnedView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "pin")
                .font(.system(size: 40))
                .foregroundColor(.gray)

            Text("No Pinned Items")
                .font(.headline)
                .foregroundColor(.white)

            Text("Right-click on any clipboard item to pin it")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(width: 250, height: 120)
        .background(Color.black.opacity(0.2))
        .cornerRadius(12)
        .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                )
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.6))
                .shadow(color: .white.opacity(0.3), radius: 8)

            Text(title)
                .font(.headline)
                .foregroundColor(.white)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(width: 250, height: 120)
        .background(
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.05),
                        Color.clear,
                        Color.black.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 1.5, dash: [8, 4])
                )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

struct SearchBar: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(isFocused ? .white.opacity(0.9) : .white.opacity(0.5))
                .font(.system(size: 15, weight: .medium))

            TextField("Search clipboard...", text: $text)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .foregroundColor(.white)
                .font(.system(size: 14, weight: .regular))

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.5))
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(isFocused ? 0.12 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    Color.white.opacity(isFocused ? 0.25 : 0.12),
                    lineWidth: 1
                )
        )
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}

struct LiquidGlassShimmer: View {
    @State private var animationOffset: CGFloat = -200

    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.white.opacity(0.03),
                    Color.clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 200)
            .offset(x: animationOffset)
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 3)
                        .repeatForever(autoreverses: false)
                ) {
                    animationOffset = geometry.size.width + 200
                }
            }
        }
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

        // Enhanced liquid glass effect
        if let layer = visualEffectView.layer {
            layer.cornerRadius = 20
            layer.masksToBounds = true

            // Add subtle shadow for depth
            layer.shadowColor = NSColor.black.cgColor
            layer.shadowOffset = CGSize(width: 0, height: 10)
            layer.shadowRadius = 30
            layer.shadowOpacity = 0.3

            // Add border with gradient-like shimmer
            layer.borderWidth = 1
            layer.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor
        }

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

extension DateFormatter {
    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}
