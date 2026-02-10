import SwiftUI
import AppKit
import Combine

class PopupWindowController: ObservableObject {
    private var window: PopupPanel?
    private var clipboardManager: ClipboardManager
    private var viewModel: PopupViewModel?
    private var isVisible = false
    private var eventMonitor: Any?
    private var focusObserver: Any?

    init(clipboardManager: ClipboardManager) {
        self.clipboardManager = clipboardManager
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let observer = focusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func toggle() {
        if isVisible {
            hideWindow()
        } else {
            showWindow()
        }
    }

    func showWindow() {
        if window == nil {
            createWindow()
        }

        viewModel?.reset()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.showWindowInternal()
        }
    }

    private func showWindowInternal() {
        guard let win = window else { return }

        win.setIsVisible(false)
        win.orderOut(nil)

        positionWindowOnCurrentScreen()

        win.setIsVisible(true)
        win.orderFrontRegardless()
        win.makeKey()

        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            win.makeFirstResponder(win.contentViewController?.view)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.viewModel?.focusSearch()
        }

        addFocusObserver()
        startEventMonitor()
        isVisible = true
    }

    private func positionWindowOnCurrentScreen() {
        guard let win = window else { return }

        let mouseLocation = NSEvent.mouseLocation

        guard let currentScreen = NSScreen.screens.first(where: { screen in
            let frame = screen.frame
            return mouseLocation.x >= frame.minX && mouseLocation.x <= frame.maxX &&
                   mouseLocation.y >= frame.minY && mouseLocation.y <= frame.maxY
        }) else {
            return
        }

        let visibleFrame = currentScreen.visibleFrame
        let windowSize = NSSize(width: 600, height: 400)

        let x = visibleFrame.midX - windowSize.width / 2
        let y = visibleFrame.midY - windowSize.height / 2 + 50

        win.setFrame(NSRect(x: x, y: y, width: windowSize.width, height: windowSize.height), display: false)
    }

    private func addFocusObserver() {
        if let observer = focusObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        focusObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                if self?.isVisible == true {
                    self?.hideWindow()
                }
            }
        }
    }

    private func startEventMonitor() {
        stopEventMonitor()

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isVisible, let viewModel = self.viewModel else {
                return event
            }

            switch event.keyCode {
            case 53:
                viewModel.dismiss()
                return nil
            case 126:
                viewModel.moveSelection(up: true)
                return nil
            case 125:
                viewModel.moveSelection(up: false)
                return nil
            case 36, 76:
                viewModel.pasteSelected()
                return nil
            default:
                return event
            }
        }
    }

    private func stopEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    func hideWindow() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.stopEventMonitor()

            if let observer = self.focusObserver {
                NotificationCenter.default.removeObserver(observer)
                self.focusObserver = nil
            }

            self.window?.setIsVisible(false)
            self.window?.orderOut(nil)
            self.isVisible = false
        }
    }

    private func createWindow() {
        viewModel = PopupViewModel(
            clipboardManager: clipboardManager,
            onDismiss: { [weak self] in
                self?.hideWindow()
            }
        )

        let contentView = PopupWindowView(viewModel: viewModel!)
            .environmentObject(clipboardManager)

        window = PopupPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        let hostingController = NSHostingController(rootView: contentView)
        hostingController.view.wantsLayer = true

        window?.contentViewController = hostingController
        window?.contentView?.wantsLayer = true
        window?.contentView?.layer?.cornerRadius = 12
        window?.contentView?.layer?.masksToBounds = true
        window?.backgroundColor = .clear
        window?.isOpaque = false
        window?.level = .floating
        window?.hasShadow = true
        window?.isMovableByWindowBackground = false
        window?.hidesOnDeactivate = false
        window?.showsToolbarButton = false
        window?.showsResizeIndicator = false
        window?.collectionBehavior = [.canJoinAllSpaces]
        window?.viewModel = viewModel
    }
}

class PopupPanel: NSPanel {
    weak var viewModel: PopupViewModel?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.keyCode == 53 {
            viewModel?.dismiss()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        let location = event.locationInWindow

        if let contentView = contentViewController?.view,
           !contentView.frame.contains(location) {
            viewModel?.dismiss()
            return
        }

        super.mouseDown(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        viewModel?.dismiss()
    }
}

class PopupViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedIndex = 0
    @Published var shouldFocusSearch = false
    @Published var refreshTrigger = UUID()

    let clipboardManager: ClipboardManager
    let onDismiss: () -> Void

    init(clipboardManager: ClipboardManager, onDismiss: @escaping () -> Void) {
        self.clipboardManager = clipboardManager
        self.onDismiss = onDismiss

        $searchText
            .sink { [weak self] text in
                self?.clipboardManager.searchQuery = text
            }
            .store(in: &cancellables)

        clipboardManager.$searchResults
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.selectedIndex = 0
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    var filteredItems: [ClipboardItem] {
        clipboardManager.filteredItems
    }

    func searchResult(for item: ClipboardItem) -> SearchResult? {
        return clipboardManager.searchResult(for: item)
    }

    func focusSearch() {
        shouldFocusSearch.toggle()
    }

    func reset() {
        searchText = ""
        selectedIndex = 0
        refreshTrigger = UUID()
        clipboardManager.searchQuery = ""
    }

    func dismiss() {
        onDismiss()
    }

    func moveSelection(up: Bool) {
        let count = filteredItems.count
        guard count > 0 else { return }

        if up {
            selectedIndex = selectedIndex > 0 ? selectedIndex - 1 : count - 1
        } else {
            selectedIndex = selectedIndex < count - 1 ? selectedIndex + 1 : 0
        }
    }

    func pasteSelected() {
        guard selectedIndex < filteredItems.count else { return }
        let item = filteredItems[selectedIndex]

        DispatchQueue.main.async { [weak self] in
            self?.dismiss()
            self?.clipboardManager.paste(item)
        }
    }

    func selectAndPaste(at index: Int) {
        guard index >= 0 && index < filteredItems.count else { return }
        selectedIndex = index
        pasteSelected()
    }
}

struct PopupWindowView: View {
    @ObservedObject var viewModel: PopupViewModel
    @EnvironmentObject var clipboardManager: ClipboardManager
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            resultsList
            Divider()
            hintsBar
        }
        .frame(width: 600, height: 400)
        .background(
            ZStack {
                VisualEffectView(material: .popover, blendingMode: .behindWindow)
                Color(NSColor.windowBackgroundColor).opacity(0.95)
            }
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isSearchFocused = true
            }
        }
        .onChange(of: viewModel.shouldFocusSearch) { _ in
            isSearchFocused = true
        }
        .onChange(of: viewModel.searchText) { _ in
            viewModel.selectedIndex = 0
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title2)
                .foregroundColor(.secondary)

            TextField("搜索剪贴板历史...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($isSearchFocused)
                .onSubmit {
                    viewModel.pasteSelected()
                }

            if !viewModel.searchText.isEmpty {
                Button(action: { viewModel.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text("ESC")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(viewModel.filteredItems.enumerated()), id: \.offset) { index, item in
                        let searchResult = viewModel.searchResult(for: item)
                        PopupItemRow(
                            item: item,
                            index: index,
                            isSelected: index == viewModel.selectedIndex,
                            searchQuery: clipboardManager.searchQuery,
                            highlightedRanges: searchResult?.highlightedRanges ?? []
                        )
                        .id("item_\(index)")
                        .onTapGesture {
                            viewModel.selectAndPaste(at: index)
                        }
                    }

                    if viewModel.filteredItems.isEmpty {
                        emptyState
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .onChange(of: viewModel.selectedIndex) { newValue in
                withAnimation(.easeInOut(duration: 0.1)) {
                    proxy.scrollTo("item_\(newValue)", anchor: .center)
                }
            }
            .onChange(of: viewModel.filteredItems.count) { _ in
                let maxIndex = max(0, viewModel.filteredItems.count - 1)
                if viewModel.selectedIndex > maxIndex {
                    viewModel.selectedIndex = 0
                }
            }
            .id(viewModel.refreshTrigger)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("未找到匹配的记录")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var hintsBar: some View {
        HStack(spacing: 16) {
            HintItem(keys: "↑↓", action: "选择")
            HintItem(keys: "↵", action: "粘贴")
            HintItem(keys: "ESC", action: "关闭")

            Spacer()

            Text("\(viewModel.filteredItems.count) 条记录")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct PopupItemRow: View {
    let item: ClipboardItem
    let index: Int
    let isSelected: Bool
    let searchQuery: String
    let highlightedRanges: [ClosedRange<Int>]

    init(item: ClipboardItem, index: Int, isSelected: Bool, searchQuery: String = "", highlightedRanges: [ClosedRange<Int>] = []) {
        self.item = item
        self.index = index
        self.isSelected = isSelected
        self.searchQuery = searchQuery
        self.highlightedRanges = highlightedRanges
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20)

            Image(systemName: item.type.icon)
                .font(.system(size: 14))
                .foregroundColor(typeColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                if item.type == .image, let image = item.image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 40)
                        .cornerRadius(4)
                } else if !searchQuery.isEmpty && !highlightedRanges.isEmpty {
                    highlightedText
                } else {
                    Text(item.previewText)
                        .font(.system(size: 13))
                        .lineLimit(2)
                        .foregroundColor(.primary)
                }

                HStack(spacing: 6) {
                    Text(item.formattedDate)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if let app = item.appSource {
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(app)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(8)
        .contentShape(Rectangle())
        .frame(minHeight: 60)
    }

    private var highlightedText: some View {
        let text = item.previewText
        var components: [(String, Bool)] = []
        var currentIndex = 0

        let mergedRanges = mergeRanges(highlightedRanges)

        for range in mergedRanges {
            if currentIndex < range.lowerBound && range.lowerBound <= text.count {
                let start = text.index(text.startIndex, offsetBy: currentIndex)
                let end = text.index(text.startIndex, offsetBy: min(range.lowerBound, text.count))
                components.append((String(text[start..<end]), false))
            }

            if range.lowerBound < text.count {
                let start = text.index(text.startIndex, offsetBy: range.lowerBound)
                let end = text.index(text.startIndex, offsetBy: min(range.upperBound + 1, text.count))
                components.append((String(text[start..<end]), true))
            }

            currentIndex = range.upperBound + 1
        }

        if currentIndex < text.count {
            let start = text.index(text.startIndex, offsetBy: currentIndex)
            components.append((String(text[start...]), false))
        }

        return Text(buildAttributedString(from: components))
            .font(.system(size: 13))
            .lineLimit(2)
    }

    private func mergeRanges(_ ranges: [ClosedRange<Int>]) -> [ClosedRange<Int>] {
        guard !ranges.isEmpty else { return [] }

        let sorted = ranges.sorted { $0.lowerBound < $1.lowerBound }
        var merged: [ClosedRange<Int>] = [sorted[0]]

        for range in sorted.dropFirst() {
            if let last = merged.last, range.lowerBound <= last.upperBound + 1 {
                merged[merged.count - 1] = last.lowerBound...max(last.upperBound, range.upperBound)
            } else {
                merged.append(range)
            }
        }

        return merged
    }

    private func buildAttributedString(from components: [(String, Bool)]) -> AttributedString {
        var result = AttributedString()

        for (text, isHighlighted) in components {
            var part = AttributedString(text)
            if isHighlighted {
                part.backgroundColor = .yellow.opacity(0.4)
                part.foregroundColor = .primary
            } else {
                part.foregroundColor = .primary
            }
            result.append(part)
        }

        return result
    }

    private var typeColor: Color {
        switch item.type {
        case .text: return .blue
        case .image: return .purple
        case .file: return .orange
        case .url: return .green
        }
    }
}

struct HintItem: View {
    let keys: String
    let action: String

    var body: some View {
        HStack(spacing: 4) {
            Text(keys)
                .font(.caption)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(3)

            Text(action)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
