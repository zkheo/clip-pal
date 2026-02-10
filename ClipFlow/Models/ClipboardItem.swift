import Foundation
import AppKit

// MARK: - Clipboard Item Type
enum ClipboardItemType: String, Codable, CaseIterable {
    case text = "text"
    case image = "image"
    case file = "file"
    case url = "url"
    
    var icon: String {
        switch self {
        case .text: return "doc.text"
        case .image: return "photo"
        case .file: return "folder"
        case .url: return "link"
        }
    }
    
    var displayName: String {
        switch self {
        case .text: return "文本"
        case .image: return "图片"
        case .file: return "文件"
        case .url: return "链接"
        }
    }
}

// MARK: - Clipboard Item
struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    let type: ClipboardItemType
    let textContent: String?
    let imageData: Data?
    let filePaths: [String]?
    let urlString: String?
    let createdAt: Date
    var isPinned: Bool
    var tags: [String]
    var appSource: String?
    
    init(
        id: UUID = UUID(),
        type: ClipboardItemType,
        textContent: String? = nil,
        imageData: Data? = nil,
        filePaths: [String]? = nil,
        urlString: String? = nil,
        createdAt: Date = Date(),
        isPinned: Bool = false,
        tags: [String] = [],
        appSource: String? = nil
    ) {
        self.id = id
        self.type = type
        self.textContent = textContent
        self.imageData = imageData
        self.filePaths = filePaths
        self.urlString = urlString
        self.createdAt = createdAt
        self.isPinned = isPinned
        self.tags = tags
        self.appSource = appSource
    }
    
    // MARK: - Computed Properties
    var displayText: String {
        switch type {
        case .text:
            return textContent ?? ""
        case .url:
            return urlString ?? ""
        case .image:
            return "📷 图片"
        case .file:
            if let paths = filePaths, let first = paths.first {
                let filename = (first as NSString).lastPathComponent
                return paths.count > 1 ? "\(filename) 等 \(paths.count) 个文件" : filename
            }
            return "📁 文件"
        }
    }
    
    var previewText: String {
        let text = displayText
        if text.count > 100 {
            return String(text.prefix(100)) + "..."
        }
        return text
    }
    
    var searchableText: String {
        var parts: [String] = []
        if let text = textContent { parts.append(text) }
        if let url = urlString { parts.append(url) }
        if let paths = filePaths { parts.append(contentsOf: paths) }
        parts.append(contentsOf: tags)
        return parts.joined(separator: " ").lowercased()
    }
    
    var formattedDate: String {
        return ClipboardItem.dateFormatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    // 复用 DateFormatter 实例，避免频繁创建
    private static let dateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter
    }()
    
    var image: NSImage? {
        guard let data = imageData else { return nil }
        
        // 先从缓存获取
        if let cachedImage = ImageCache.shared.image(for: id) {
            return cachedImage
        }
        
        // 同步解码（小图片）或返回占位符
        guard let image = NSImage(data: data) else { return nil }
        
        // 缓存图片
        ImageCache.shared.setImage(image, for: id)
        
        return image
    }
    
    // MARK: - Factory Methods
    static func fromText(_ text: String, appSource: String? = nil) -> ClipboardItem {
        // Check if it's a URL
        if let url = URL(string: text), url.scheme != nil {
            return ClipboardItem(type: .url, urlString: text, appSource: appSource)
        }
        return ClipboardItem(type: .text, textContent: text, appSource: appSource)
    }
    
    static func fromImage(_ image: NSImage, appSource: String? = nil) -> ClipboardItem? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        return ClipboardItem(type: .image, imageData: pngData, appSource: appSource)
    }
    
    static func fromFiles(_ paths: [String], appSource: String? = nil) -> ClipboardItem {
        return ClipboardItem(type: .file, filePaths: paths, appSource: appSource)
    }
    
    // MARK: - Equatable
    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        // Compare by content, not by ID
        // 使用哈希值比较大数据，避免直接比较Data数组
        switch (lhs.type, rhs.type) {
        case (.text, .text):
            return lhs.textContent == rhs.textContent
        case (.url, .url):
            return lhs.urlString == rhs.urlString
        case (.image, .image):
            // 比较图片数据的哈希值而不是完整数据，提升性能
            return lhs.imageDataHash == rhs.imageDataHash
        case (.file, .file):
            return lhs.filePaths == rhs.filePaths
        default:
            return false
        }
    }
    
    // MARK: - Internal Helpers
    /// 图片数据的哈希值，用于快速比较
    var imageDataHash: Int {
        guard let data = imageData else { return 0 }
        // 使用数据的长度和前64字节的组合作为哈希
        var hash = data.count
        let prefixLength = min(64, data.count)
        if prefixLength > 0 {
            let prefix = data.prefix(prefixLength)
            hash = prefix.withUnsafeBytes { buffer in
                var h = hash
                for i in stride(from: 0, to: prefixLength, by: 4) {
                    if i + 4 <= prefixLength {
                        h ^= Int(buffer.load(fromByteOffset: i, as: UInt32.self))
                    }
                }
                return h
            }
        }
        return hash
    }
}

// MARK: - Tag
struct Tag: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var color: String // Hex color
    
    init(id: UUID = UUID(), name: String, color: String = "#007AFF") {
        self.id = id
        self.name = name
        self.color = color
    }
    
    static let defaultTags: [Tag] = [
        Tag(name: "工作", color: "#FF3B30"),
        Tag(name: "代码", color: "#5856D6"),
        Tag(name: "链接", color: "#007AFF"),
        Tag(name: "重要", color: "#FF9500")
    ]
}

// MARK: - Search Result
// 搜索结果模型，用于模糊搜索和高亮显示
struct SearchResult: Identifiable {
    let id: UUID
    let item: ClipboardItem
    let score: Double  // 匹配分数，越低越匹配
    let highlightedRanges: [ClosedRange<Int>]  // 高亮范围
    
    init(item: ClipboardItem, score: Double, highlightedRanges: [ClosedRange<Int>]) {
        self.id = item.id
        self.item = item
        self.score = score
        self.highlightedRanges = highlightedRanges
    }
}
