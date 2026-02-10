import Foundation
import AppKit
import Combine
import SwiftUI

class ClipboardManager: ObservableObject {
    // MARK: - Published Properties
    @Published var items: [ClipboardItem] = []
    @Published var pinnedItems: [ClipboardItem] = []
    @Published var searchQuery: String = ""
    @Published var selectedType: ClipboardItemType? = nil
    @Published var availableTags: [Tag] = Tag.defaultTags
    
    // 使用缓存避免重复计算
    private var filteredItemsCache: [UUID: ClipboardItem] = [:]
    private var lastFilterType: ClipboardItemType?
    private var lastFilterTime: Date = Date.distantPast
    
    // 标记是否正在重置搜索状态，用于跳过debounce触发
    private var isResettingSearch = false

    // MARK: - Settings (sync with UserDefaults)
    @AppStorage("maxHistoryCount") var maxHistoryCount: Int = 100
    @AppStorage("clearOnQuit") var clearOnQuit: Bool = false
    @AppStorage("ignoreConsecutiveDuplicates") var ignoreDuplicates: Bool = true
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false

    // MARK: - Private Properties
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let pasteboard = NSPasteboard.general
    private let storageManager = StorageManager()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Search Service
    private let searchService = SearchService.shared

    // MARK: - Published Search Results
    @Published var searchResults: [SearchResult] = []
    
    // MARK: - Computed Properties
    /// 获取过滤后的项目列表（优化版本）
    var filteredItems: [ClipboardItem] {
        // 如果有搜索查询，直接返回搜索结果
        if !searchQuery.isEmpty {
            return searchResults.map { $0.item }
        }
        
        // 检查是否需要刷新缓存
        let shouldRefreshCache = selectedType != lastFilterType || 
                                 Date().timeIntervalSince(lastFilterTime) > 1.0
        
        if !shouldRefreshCache && !filteredItemsCache.isEmpty {
            // 从缓存返回（保持顺序）
            var result: [ClipboardItem] = []
            result.reserveCapacity(pinnedItems.count + items.count)
            
            // 先添加固定项
            for item in pinnedItems {
                if let cached = filteredItemsCache[item.id] {
                    result.append(cached)
                }
            }
            
            // 再添加非固定项
            for item in items {
                if let cached = filteredItemsCache[item.id] {
                    result.append(cached)
                }
            }
            
            return result
        }
        
        // 重新计算并缓存结果
        filteredItemsCache.removeAll()
        lastFilterType = selectedType
        lastFilterTime = Date()
        
        var result: [ClipboardItem] = []
        result.reserveCapacity(pinnedItems.count + items.count)
        
        // 合并固定项和非固定项
        let allItems = pinnedItems + items
        
        // Filter by type
        if let type = selectedType {
            for item in allItems where item.type == type {
                result.append(item)
                filteredItemsCache[item.id] = item
            }
        } else {
            for item in allItems {
                result.append(item)
                filteredItemsCache[item.id] = item
            }
        }
        
        return result
    }
    
    /// 获取项目的搜索结果（包含高亮信息）
    func searchResult(for item: ClipboardItem) -> SearchResult? {
        return searchResults.first { $0.item.id == item.id }
    }
    
    /// 获取项目的索引（在所有项目中）
    func index(of item: ClipboardItem) -> Int? {
        let allItems = pinnedItems + items
        return allItems.firstIndex { $0.id == item.id }
    }
    
    var allItems: [ClipboardItem] {
        pinnedItems + items
    }
    
    // MARK: - Initialization
    init() {
        loadData()
        setupBindings()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Auto-save when items change
        $items
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveData()
            }
            .store(in: &cancellables)
        
        $pinnedItems
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveData()
            }
            .store(in: &cancellables)
        
        // 搜索功能 - 使用防抖避免频繁搜索（增加到300ms以获得更好的用户体验）
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self, !self.isResettingSearch else { return }
                self.performSearch()
            }
            .store(in: &cancellables)
        
        // 当类型筛选改变时也触发搜索
        $selectedType
            .sink { [weak self] _ in
                self?.performSearch()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Search
    private var searchOperationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.clipflow.search"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()
    
    private var lastSearchQuery: String = ""
    private var lastSearchType: ClipboardItemType?
    
    /// 完全重置搜索状态
    func resetSearchState() {
        // 设置标志位，防止debounce触发搜索
        isResettingSearch = true
        
        searchOperationQueue.cancelAllOperations()
        searchQuery = ""
        selectedType = nil
        searchResults = []
        lastSearchQuery = ""
        lastSearchType = nil
        // 强制重置缓存时间，确保下次 filteredItems 重新计算
        lastFilterTime = Date.distantPast
        filteredItemsCache.removeAll()
        
        // 延迟重置标志位（在debounce时间之后）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.isResettingSearch = false
        }
    }
    
    private func performSearch() {
        // 取消之前的搜索操作
        searchOperationQueue.cancelAllOperations()
        
        // 使用当前的 searchQuery 和 selectedType，确保数据一致性
        let currentQuery = self.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentType = self.selectedType
        
        guard !currentQuery.isEmpty else {
            searchResults = []
            return
        }
        
        // 如果查询和类型都没有变化，跳过搜索
        if currentQuery == lastSearchQuery && currentType == lastSearchType && !searchResults.isEmpty {
            return
        }
        
        // 先按类型筛选（包括固定项和非固定项）
        let allItems = pinnedItems + items
        let itemsToSearch: [ClipboardItem]
        if let type = currentType {
            itemsToSearch = allItems.filter { $0.type == type }
        } else {
            itemsToSearch = allItems
        }
        
        // 限制搜索数量以提高性能
        let limitedItems = Array(itemsToSearch.prefix(100))
        
        // 捕获当前查询字符串的快照
        let querySnapshot = currentQuery
        let typeSnapshot = currentType
        
        // 创建搜索操作
        let searchOperation = BlockOperation { [weak self] in
            guard let self = self, !self.searchOperationQueue.isSuspended else { return }
            
            // 在后台线程执行搜索
            let results = self.searchService.search(querySnapshot, in: limitedItems)
            
            // 检查操作是否被取消
            if self.searchOperationQueue.isSuspended {
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // 只有当查询和类型都没有被修改时才更新结果
                let currentTrimmedQuery = self.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                let currentSelectedType = self.selectedType
                
                if currentTrimmedQuery == querySnapshot && currentSelectedType == typeSnapshot {
                    self.searchResults = results
                    self.lastSearchQuery = querySnapshot
                    self.lastSearchType = typeSnapshot
                }
            }
        }
        
        searchOperationQueue.addOperation(searchOperation)
    }
    
    // MARK: - Monitoring
    func startMonitoring() {
        lastChangeCount = pasteboard.changeCount
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        
        if clearOnQuit {
            clearAll()
        }
        saveData()
    }
    
    private func checkClipboard() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        
        // Get current frontmost app
        let appSource = NSWorkspace.shared.frontmostApplication?.localizedName
        
        // Try to get clipboard content
        if let item = extractClipboardItem(appSource: appSource) {
            addItem(item)
        }
    }
    
    /// 文本内容最大长度限制
    static let maxTextLength = 500
    
    private func extractClipboardItem(appSource: String?) -> ClipboardItem? {
        // Check for files first
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !fileURLs.isEmpty {
            let paths = fileURLs.map { $0.path }
            return ClipboardItem.fromFiles(paths, appSource: appSource)
        }

        // Check for image
        if let image = NSImage(pasteboard: pasteboard) {
            return ClipboardItem.fromImage(image, appSource: appSource)
        }

        // Check for text/URL
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            // 统一的文本长度检查
            guard ClipboardManager.validateTextLength(text) else {
                return nil
            }
            return ClipboardItem.fromText(text, appSource: appSource)
        }

        return nil
    }
    
    /// 验证文本长度是否在限制范围内
    static func validateTextLength(_ text: String) -> Bool {
        return text.count <= maxTextLength
    }
    
    // MARK: - Item Management
    func addItem(_ item: ClipboardItem) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Check for consecutive duplicates (使用更高效的比较方式)
            if self.ignoreDuplicates {
                if let lastItem = self.items.first {
                    // 对于大文本，只比较前100个字符来判断是否重复
                    let shouldSkip: Bool
                    switch (lastItem.type, item.type) {
                    case (.text, .text):
                        let lastText = lastItem.textContent?.prefix(100) ?? ""
                        let newText = item.textContent?.prefix(100) ?? ""
                        shouldSkip = (lastText == newText)
                    case (.url, .url):
                        shouldSkip = (lastItem.urlString == item.urlString)
                    case (.image, .image):
                        shouldSkip = (lastItem.imageDataHash == item.imageDataHash)
                    case (.file, .file):
                        shouldSkip = (lastItem.filePaths == item.filePaths)
                    default:
                        shouldSkip = false
                    }
                    
                    if shouldSkip {
                        return
                    }
                }
            }

            // Remove existing duplicate
            self.items.removeAll { $0.id == item.id }

            // Add to beginning
            self.items.insert(item, at: 0)

            // Trim history
            if self.items.count > self.maxHistoryCount {
                self.items = Array(self.items.prefix(self.maxHistoryCount))
            }
        }
    }
    
    func deleteItem(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        pinnedItems.removeAll { $0.id == item.id }
        // 从搜索结果中移除已删除的项目
        searchResults.removeAll { $0.item.id == item.id }
    }
    
    func togglePin(_ item: ClipboardItem) {
        // 检查项目在 pinnedItems 中（取消固定）
        if let pinnedIndex = pinnedItems.firstIndex(where: { $0.id == item.id }) {
            // Unpin: 从 pinnedItems 移到 items
            var unpinnedItem = pinnedItems.remove(at: pinnedIndex)
            unpinnedItem.isPinned = false
            items.insert(unpinnedItem, at: 0)
            saveData()
            return
        }
        
        // 检查项目在 items 中（固定）
        if let itemsIndex = items.firstIndex(where: { $0.id == item.id }) {
            // Pin: 从 items 移到 pinnedItems
            var pinnedItem = items.remove(at: itemsIndex)
            pinnedItem.isPinned = true
            pinnedItems.append(pinnedItem)
            saveData()
            return
        }
    }

    func addTag(_ tagName: String, to item: ClipboardItem) {
        func updateTags(in items: inout [ClipboardItem]) {
            if let index = items.firstIndex(where: { $0.id == item.id }),
               !items[index].tags.contains(tagName) {
                items[index].tags.append(tagName)
            }
        }
        updateTags(in: &items)
        updateTags(in: &pinnedItems)
    }

    func removeTag(_ tagName: String, from item: ClipboardItem) {
        func updateTags(in items: inout [ClipboardItem]) {
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index].tags.removeAll { $0 == tagName }
            }
        }
        updateTags(in: &items)
        updateTags(in: &pinnedItems)
    }
    
    /// 清空所有非固定历史记录
    func clearUnpinned() {
        items.removeAll()
        // 清理后如果正在搜索，需要更新搜索结果
        if !searchQuery.isEmpty {
            performSearch()
        } else {
            searchResults = []
        }
        saveData()
    }
    
    /// 清空所有历史记录（包括固定项）
    func clearAll() {
        items.removeAll()
        pinnedItems.removeAll()
        searchResults = []
        saveData()
    }
    
    /// 清空指定天数之前的历史记录
    func clearHistory(olderThan days: Int) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        
        // 只清理非固定项
        items.removeAll { item in
            item.createdAt < cutoffDate && !item.isPinned
        }
        
        // 清理后如果正在搜索，需要更新搜索结果
        if !searchQuery.isEmpty {
            performSearch()
        } else {
            searchResults = []
        }
        
        saveData()
    }
    
    /// 清空特定类型的历史记录
    func clearHistory(ofType type: ClipboardItemType) {
        items.removeAll { $0.type == type }
        
        // 清理后如果正在搜索，需要更新搜索结果
        if !searchQuery.isEmpty {
            performSearch()
        } else {
            searchResults = []
        }
        
        saveData()
    }
    
    // MARK: - Paste Action
    func paste(_ item: ClipboardItem) {
        // Write to pasteboard
        pasteboard.clearContents()
        
        switch item.type {
        case .text:
            if let text = item.textContent {
                pasteboard.setString(text, forType: .string)
            }
        case .url:
            if let urlString = item.urlString {
                pasteboard.setString(urlString, forType: .string)
            }
        case .image:
            if let data = item.imageData, let image = NSImage(data: data) {
                pasteboard.writeObjects([image])
            }
        case .file:
            if let paths = item.filePaths {
                let urls = paths.compactMap { URL(fileURLWithPath: $0) }
                pasteboard.writeObjects(urls as [NSURL])
            }
        }
        
        // Update change count to avoid re-capturing
        lastChangeCount = pasteboard.changeCount
        
        // Simulate Cmd+V
        simulatePaste()
        
        // Move to top if not pinned
        if !item.isPinned {
            items.moveToFront { $0.id == item.id }
        }
    }
    
    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)
        
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // V key
        keyDown?.flags = .maskCommand
        
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand
        
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
    
    // MARK: - Copy to Clipboard Only (without paste)
    func copyToClipboard(_ item: ClipboardItem) {
        pasteboard.clearContents()
        
        switch item.type {
        case .text:
            if let text = item.textContent {
                pasteboard.setString(text, forType: .string)
            }
        case .url:
            if let urlString = item.urlString {
                pasteboard.setString(urlString, forType: .string)
            }
        case .image:
            if let data = item.imageData, let image = NSImage(data: data) {
                pasteboard.writeObjects([image])
            }
        case .file:
            if let paths = item.filePaths {
                let urls = paths.compactMap { URL(fileURLWithPath: $0) }
                pasteboard.writeObjects(urls as [NSURL])
            }
        }
        
        lastChangeCount = pasteboard.changeCount
    }
    
    // MARK: - Persistence
    private func loadData() {
        if let data = storageManager.loadClipboardData() {
            self.items = data.items
            self.pinnedItems = data.pinnedItems
            self.availableTags = data.tags
        }
    }
    
    private func saveData() {
        let data = ClipboardData(items: items, pinnedItems: pinnedItems, tags: availableTags)
        storageManager.saveClipboardData(data)
    }
}

// MARK: - Clipboard Data Container
struct ClipboardData: Codable {
    let items: [ClipboardItem]
    let pinnedItems: [ClipboardItem]
    let tags: [Tag]
}

// MARK: - Array Extension for Identifiable Elements
extension Array where Element: Identifiable {
    mutating func moveToFront(where predicate: (Element) throws -> Bool) rethrows {
        if let index = try firstIndex(where: predicate) {
            let item = remove(at: index)
            insert(item, at: 0)
        }
    }
}

// MARK: - Search Service
// 简化的搜索服务 - 只支持基本的文本包含匹配
class SearchService {
    static let shared = SearchService()
    
    func search(_ query: String, in items: [ClipboardItem]) -> [SearchResult] {
        guard !query.isEmpty else {
            return items.map { SearchResult(item: $0, score: 0, highlightedRanges: []) }
        }
        
        let lowerQuery = query.lowercased()
        var results: [SearchResult] = []
        
        for item in items {
            let searchableText = item.searchableText.lowercased()
            
            // 简单的包含匹配
            if let range = searchableText.range(of: lowerQuery) {
                let lowerBound = searchableText.distance(from: searchableText.startIndex, to: range.lowerBound)
                let upperBound = searchableText.distance(from: searchableText.startIndex, to: range.upperBound) - 1
                results.append(SearchResult(
                    item: item,
                    score: 0.0,
                    highlightedRanges: [lowerBound...upperBound]
                ))
            }
        }
        
        return results
    }
}
