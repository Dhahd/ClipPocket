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
    @EnvironmentObject var snippetManager: SnippetManager
    @EnvironmentObject var dragDropManager: DragDropManager
    @ObservedObject private var settings = SettingsManager.shared
    @State private var hoveredItemId: UUID?
    @State private var searchText: String = ""
    @State private var selectedSection: ClipboardSection = .recent
    @State private var selectedIndex: Int = 0
    @FocusState private var searchFieldFocused: Bool
    @State private var isSearchFieldFocused: Bool = false
    @State private var filterType: ClipboardItem.ItemType?
    @State private var showSnippetForm: Bool = false
    @State private var activeSnippet: Snippet? = nil
    @State private var snippetValues: [String: String] = [:]
    @State private var scrollWheelMonitor = ScrollWheelMonitor()

    enum ClipboardSection: String, CaseIterable {
        case pinned = "Pinned"
        case recent = "Recent"
        case history = "History"
        case snippets = "Snippets"

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

    var filteredSnippets: [Snippet] {
        var items = snippetManager.snippets
        if !searchText.isEmpty {
            items = items.filter { snippet in
                fuzzyMatch(searchText, in: snippet.title) ||
                fuzzyMatch(searchText, in: snippet.content)
            }
        }
        return items
    }

    var availableSections: [ClipboardSection] {
        ClipboardSection.allCases.filter { section in
            if section == .snippets { return appDelegate.settingsManager.snippetsEnabled }
            return true
        }
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

                                ForEach([ClipboardItem.ItemType.text, .richText, .code, .url, .email, .image, .file, .color, .json], id: \.self) { type in
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
                        ForEach(availableSections, id: \.self) { section in
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
                ScrollViewReader { scrollProxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: settings.cardSpacing) {
                            switch selectedSection {
                            case .pinned:
                                // Pinned items section
                                if filteredPinnedItems.isEmpty {
                                    EmptyPinnedView()
                                } else {
                                    ForEach(Array(filteredPinnedItems.enumerated()), id: \.element.id) { index, pinnedItem in
                                        DraggableClipboardItemCard(item: pinnedItem.originalItem)
                                            .id(pinnedItem.id)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.blue, lineWidth: selectedIndex == index ? 3 : 0)
                                                    .animation(.easeInOut(duration: 0.15), value: selectedIndex)
                                            )
                                            .overlay(alignment: .topLeading) {
                                                if index < 10 {
                                                    Text("⌃\(index < 9 ? "\(index + 1)" : "0")")
                                                        .font(.system(size: 9, weight: .bold))
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 5)
                                                        .padding(.vertical, 2)
                                                        .background(Capsule().fill(Color.blue.opacity(0.8)))
                                                        .offset(x: 6, y: 6)
                                                }
                                            }
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

                                                if let text = pinnedItem.originalItem.content as? String,
                                                   text.range(of: "\\{[^}]+\\}", options: .regularExpression) != nil {
                                                    Divider()
                                                    Button("Save as Snippet") {
                                                        let snippet = Snippet(
                                                            title: String(text.prefix(50)),
                                                            content: text,
                                                            category: "General",
                                                            createdDate: Date()
                                                        )
                                                        snippetManager.addSnippet(snippet)
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
                                    ForEach(Array(filteredRecentItems.enumerated()), id: \.element.id) { index, item in
                                        DraggableClipboardItemCard(item: item)
                                            .id(item.id)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.blue, lineWidth: selectedIndex == index ? 3 : 0)
                                                    .animation(.easeInOut(duration: 0.15), value: selectedIndex)
                                            )
                                            .overlay(alignment: .topLeading) {
                                                if index < 10 {
                                                    Text("⌃\(index < 9 ? "\(index + 1)" : "0")")
                                                        .font(.system(size: 9, weight: .bold))
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 5)
                                                        .padding(.vertical, 2)
                                                        .background(Capsule().fill(Color.blue.opacity(0.8)))
                                                        .offset(x: 6, y: 6)
                                                }
                                            }
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

                                                if let text = item.content as? String,
                                                   text.range(of: "\\{[^}]+\\}", options: .regularExpression) != nil {
                                                    Divider()
                                                    Button("Save as Snippet") {
                                                        let snippet = Snippet(
                                                            title: String(text.prefix(50)),
                                                            content: text,
                                                            category: "General",
                                                            createdDate: Date()
                                                        )
                                                        snippetManager.addSnippet(snippet)
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
                                    ForEach(Array(filteredHistoryItems.enumerated()), id: \.element.id) { index, item in
                                        DraggableClipboardItemCard(item: item)
                                            .id(item.id)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.blue, lineWidth: selectedIndex == index ? 3 : 0)
                                                    .animation(.easeInOut(duration: 0.15), value: selectedIndex)
                                            )
                                            .overlay(alignment: .topLeading) {
                                                if index < 10 {
                                                    Text("⌃\(index < 9 ? "\(index + 1)" : "0")")
                                                        .font(.system(size: 9, weight: .bold))
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 5)
                                                        .padding(.vertical, 2)
                                                        .background(Capsule().fill(Color.blue.opacity(0.8)))
                                                        .offset(x: 6, y: 6)
                                                }
                                            }
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

                                                if let text = item.content as? String,
                                                   text.range(of: "\\{[^}]+\\}", options: .regularExpression) != nil {
                                                    Divider()
                                                    Button("Save as Snippet") {
                                                        let snippet = Snippet(
                                                            title: String(text.prefix(50)),
                                                            content: text,
                                                            category: "General",
                                                            createdDate: Date()
                                                        )
                                                        snippetManager.addSnippet(snippet)
                                                    }
                                                }

                                                Divider()

                                                Button("Delete", role: .destructive) {
                                                    appDelegate.deleteClipboardItem(item)
                                                }
                                            }
                                    }
                                }

                            case .snippets:
                                if filteredSnippets.isEmpty {
                                    VStack(spacing: 16) {
                                        EmptyStateView(
                                            icon: "doc.text.below.ecg",
                                            title: "No Snippets",
                                            subtitle: "Save text as snippets from the context menu, or load some examples to get started."
                                        )
                                        Button(action: {
                                            snippetManager.loadExamples()
                                        }) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "sparkles")
                                                Text("Load Examples")
                                            }
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.purple.opacity(0.7))
                                            .cornerRadius(8)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                } else {
                                    ForEach(Array(filteredSnippets.enumerated()), id: \.element.id) { index, snippet in
                                        SnippetCard(snippet: snippet)
                                            .id(snippet.id)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.blue, lineWidth: selectedIndex == index ? 3 : 0)
                                                    .animation(.easeInOut(duration: 0.15), value: selectedIndex)
                                            )
                                            .overlay(alignment: .topLeading) {
                                                if index < 10 {
                                                    Text("⌃\(index < 9 ? "\(index + 1)" : "0")")
                                                        .font(.system(size: 9, weight: .bold))
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 5)
                                                        .padding(.vertical, 2)
                                                        .background(Capsule().fill(Color.blue.opacity(0.8)))
                                                        .offset(x: 6, y: 6)
                                                }
                                            }
                                            .scaleEffect(hoveredItemId == snippet.id ? 1.05 : 1.0)
                                            .animation(.easeInOut(duration: 0.2), value: hoveredItemId)
                                            .onHover { isHovered in
                                                hoveredItemId = isHovered ? snippet.id : nil
                                            }
                                            .onTapGesture {
                                                handleSnippetTap(snippet)
                                            }
                                            .contextMenu {
                                                Button("Delete", role: .destructive) {
                                                    snippetManager.deleteSnippet(snippet)
                                                }
                                            }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    .onChange(of: selectedIndex) { _ in
                        scrollToSelectedItem(proxy: scrollProxy)
                    }
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
                scrollWheelMonitor.start()
            }
            .onDisappear {
                scrollWheelMonitor.stop()
            }
            .onChange(of: searchFieldFocused) { newValue in
                isSearchFieldFocused = newValue
                if newValue {
                    appDelegate.pauseDismissTimer()
                } else {
                    appDelegate.resetDismissTimer()
                }
            }
            .onChange(of: selectedSection) { _ in
                selectedIndex = 0
            }
            .onChange(of: searchText) { _ in
                selectedIndex = 0
                appDelegate.resetDismissTimer()
            }
            .onChange(of: filterType) { _ in
                selectedIndex = 0
                appDelegate.resetDismissTimer()
            }
            .onChange(of: showSnippetForm) { show in
                if show, let snippet = activeSnippet {
                    showSnippetWindow(snippet: snippet)
                }
            }
        }
        .background(LocalEventMonitorView(
            searchFieldFocused: $isSearchFieldFocused,
            onEscape: {
                NSApp.sendAction(#selector(AppDelegate.hideClipboardManager), to: nil, from: nil)
            },
            onEnter: { copySelectedItem() },
            onDelete: { deleteSelectedItem() },
            onLeftArrow: { moveSelectionLeft() },
            onRightArrow: { moveSelectionRight() },
            onUpArrow: { moveSectionUp() },
            onDownArrow: { moveSectionDown() },
            onTab: { toggleSearchFocus() },
            onNumberKey: { num in selectByNumber(num) },
            onCmdNumber: { num in switchToTabByCmd(num) }
        ))
        .preferredColorScheme(settings.resolvedColorScheme)
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
        case .snippets:
            if selectedIndex < filteredSnippets.count {
                handleSnippetTap(filteredSnippets[selectedIndex])
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
        case .snippets:
            if selectedIndex < filteredSnippets.count {
                snippetManager.deleteSnippet(filteredSnippets[selectedIndex])
            }
        }
        selectedIndex = max(0, selectedIndex - 1)
    }

    private func handleSnippetTap(_ snippet: Snippet) {
        if snippet.placeholders.isEmpty {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(snippet.content, forType: .string)
            snippetManager.markUsed(snippet)
            NSApp.sendAction(#selector(AppDelegate.hideClipboardManager), to: nil, from: nil)
        } else {
            activeSnippet = snippet
            snippetValues = Dictionary(uniqueKeysWithValues: snippet.placeholders.map { ($0, "") })
            showSnippetForm = true
        }
    }

    private func showSnippetWindow(snippet: Snippet) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Snippet — \(snippet.title)"
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.autorecalculatesKeyViewLoop = true

        let hostingView = NSHostingView(
            rootView: SnippetPlaceholderFormView(
                snippet: snippet,
                values: $snippetValues,
                onSubmit: { resolvedText in
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(resolvedText, forType: .string)
                    window.close()
                    showSnippetForm = false
                    snippetManager.markUsed(snippet)
                    NSApp.sendAction(#selector(AppDelegate.hideClipboardManager), to: nil, from: nil)
                },
                onCancel: {
                    window.close()
                    showSnippetForm = false
                }
            )
        )

        window.contentView = hostingView

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53, event.window === window {
                window.close()
                showSnippetForm = false
                return nil
            }
            return event
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeFirstResponder(hostingView)
    }

    // MARK: - Keyboard Navigation

    private var currentItemCount: Int {
        switch selectedSection {
        case .pinned: return filteredPinnedItems.count
        case .recent: return filteredRecentItems.count
        case .history: return filteredHistoryItems.count
        case .snippets: return filteredSnippets.count
        }
    }

    private func moveSelectionLeft() {
        if selectedIndex > 0 {
            selectedIndex -= 1
        }
        appDelegate.resetDismissTimer()
    }

    private func moveSelectionRight() {
        if selectedIndex < currentItemCount - 1 {
            selectedIndex += 1
        }
        appDelegate.resetDismissTimer()
    }

    private func moveSectionUp() {
        let sections = availableSections
        guard let currentIdx = sections.firstIndex(of: selectedSection),
              currentIdx > 0 else { return }
        selectedSection = sections[currentIdx - 1]
        selectedIndex = 0
        appDelegate.resetDismissTimer()
    }

    private func moveSectionDown() {
        let sections = availableSections
        guard let currentIdx = sections.firstIndex(of: selectedSection),
              currentIdx < sections.count - 1 else { return }
        selectedSection = sections[currentIdx + 1]
        selectedIndex = 0
        appDelegate.resetDismissTimer()
    }

    private func selectByNumber(_ number: Int) {
        let index = number - 1
        if index < currentItemCount {
            selectedIndex = index
            copySelectedItem()
        }
    }

    private func switchToTabByCmd(_ number: Int) {
        let sections = availableSections
        let index = number - 1
        if index < sections.count {
            selectedSection = sections[index]
            selectedIndex = 0
        }
    }

    private func toggleSearchFocus() {
        searchFieldFocused.toggle()
        isSearchFieldFocused = searchFieldFocused
        if !searchFieldFocused {
            selectedIndex = min(selectedIndex, max(0, currentItemCount - 1))
        }
    }

    private func scrollToSelectedItem(proxy: ScrollViewProxy) {
        // Get the ID of the currently selected item and scroll to it
        var targetID: UUID?
        switch selectedSection {
        case .pinned:
            if selectedIndex < filteredPinnedItems.count {
                targetID = filteredPinnedItems[selectedIndex].id
            }
        case .recent:
            if selectedIndex < filteredRecentItems.count {
                targetID = filteredRecentItems[selectedIndex].id
            }
        case .history:
            if selectedIndex < filteredHistoryItems.count {
                targetID = filteredHistoryItems[selectedIndex].id
            }
        case .snippets:
            if selectedIndex < filteredSnippets.count {
                targetID = filteredSnippets[selectedIndex].id
            }
        }
        if let id = targetID {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(id, anchor: .center)
            }
        }
    }
}

struct LocalEventMonitorView: NSViewRepresentable {
    @Binding var searchFieldFocused: Bool
    let onEscape: () -> Void
    let onEnter: () -> Void
    let onDelete: () -> Void
    let onLeftArrow: () -> Void
    let onRightArrow: () -> Void
    let onUpArrow: () -> Void
    let onDownArrow: () -> Void
    let onTab: () -> Void
    let onNumberKey: (Int) -> Void
    let onCmdNumber: (Int) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Always allow Escape to close the window
            if event.keyCode == 53 {
                DispatchQueue.main.async { self.onEscape() }
                return nil
            }

            // Cmd+number shortcuts work regardless of search focus
            if event.modifierFlags.contains(.command) {
                let cmdNumberMap: [UInt16: Int] = [18: 1, 19: 2, 20: 3, 21: 4]
                if let num = cmdNumberMap[event.keyCode] {
                    DispatchQueue.main.async { self.onCmdNumber(num) }
                    return nil
                }
            }

            // Ctrl+number for quick copy (works regardless of search focus)
            if event.modifierFlags.contains(.control) {
                let ctrlNumberMap: [UInt16: Int] = [
                    18: 1, 19: 2, 20: 3, 21: 4, 23: 5, 22: 6, 26: 7, 28: 8, 25: 9, 29: 10
                ]
                if let num = ctrlNumberMap[event.keyCode] {
                    DispatchQueue.main.async { self.onNumberKey(num) }
                    return nil
                }
            }

            // When search field is focused, arrow keys defocus search and navigate
            if self.searchFieldFocused {
                if event.keyCode == 48 { // Tab
                    DispatchQueue.main.async { self.onTab() }
                    return nil
                }
                // Arrow keys: defocus search, then handle as navigation below
                if [123, 124, 125, 126].contains(event.keyCode) {
                    DispatchQueue.main.async { self.onTab() }
                    // Fall through to navigation handling below
                } else {
                    return event
                }
            }

            // Not search-focused: handle all navigation
            switch event.keyCode {
            case 36: // Return/Enter
                DispatchQueue.main.async { self.onEnter() }
                return nil
            case 51: // Delete
                DispatchQueue.main.async { self.onDelete() }
                return nil
            case 123: // Left arrow
                DispatchQueue.main.async { self.onLeftArrow() }
                return nil
            case 124: // Right arrow
                DispatchQueue.main.async { self.onRightArrow() }
                return nil
            case 125: // Down arrow
                DispatchQueue.main.async { self.onDownArrow() }
                return nil
            case 126: // Up arrow
                DispatchQueue.main.async { self.onUpArrow() }
                return nil
            case 48: // Tab
                DispatchQueue.main.async { self.onTab() }
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
            .contentShape(Rectangle())
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
    @ObservedObject private var settings = SettingsManager.shared
    
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
        .frame(width: settings.pinnedCardWidth, height: settings.pinnedCardHeight)
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
        .cornerRadius(settings.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: settings.cardCornerRadius)
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
    private let settings = SettingsManager.shared

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
        .frame(width: settings.emptyStateWidth, height: settings.emptyStateHeight)
        .background(Color.black.opacity(0.2))
        .cornerRadius(settings.cardCornerRadius)
        .overlay(
                    RoundedRectangle(cornerRadius: settings.cardCornerRadius)
                        .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                )
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    private let settings = SettingsManager.shared

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
        .frame(width: settings.emptyStateWidth, height: settings.emptyStateHeight)
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
        .cornerRadius(settings.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: settings.cardCornerRadius)
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

/// Monitors scroll wheel events and converts vertical mouse wheel scrolling
/// to horizontal scrolling for the clipboard panel's horizontal ScrollView.
class ScrollWheelMonitor {
    private var monitor: Any?

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            // Only convert vertical-dominant scrolls (mouse wheel)
            guard abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX) else {
                return event
            }

            // Find the horizontal NSScrollView under the mouse
            guard let window = event.window,
                  let contentView = window.contentView else {
                return event
            }

            let locationInWindow = event.locationInWindow
            let locationInContent = contentView.convert(locationInWindow, from: nil)
            guard let hitView = contentView.hitTest(locationInContent) else {
                return event
            }

            // Walk up to find the horizontal NSScrollView
            var current: NSView? = hitView
            while let view = current {
                if let scrollView = view as? NSScrollView,
                   scrollView.hasHorizontalScroller || scrollView.documentView?.frame.width ?? 0 > scrollView.contentView.bounds.width {
                    let clipView = scrollView.contentView
                    var newOrigin = clipView.bounds.origin
                    newOrigin.x -= event.scrollingDeltaY * 3
                    let maxX = max(0, (scrollView.documentView?.frame.width ?? 0) - clipView.bounds.width)
                    newOrigin.x = min(max(0, newOrigin.x), maxX)
                    clipView.setBoundsOrigin(newOrigin)
                    return nil // Consume the event
                }
                current = view.superview
            }

            return event
        }
    }

    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
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
