import SwiftUI

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isHovered: Bool
    let searchQuery: String
    let highlightedRanges: [ClosedRange<Int>]
    let onPaste: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void
    
    @State private var showActions = false
    @State private var loadedImage: NSImage? = nil
    @State private var isLoadingImage = false
    
    init(item: ClipboardItem, isHovered: Bool, searchQuery: String = "", highlightedRanges: [ClosedRange<Int>] = [], onPaste: @escaping () -> Void, onCopy: @escaping () -> Void, onDelete: @escaping () -> Void, onTogglePin: @escaping () -> Void) {
        self.item = item
        self.isHovered = isHovered
        self.searchQuery = searchQuery
        self.highlightedRanges = highlightedRanges
        self.onPaste = onPaste
        self.onCopy = onCopy
        self.onDelete = onDelete
        self.onTogglePin = onTogglePin
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Type Icon
            typeIcon
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                contentView
                metadataView
            }
            
            Spacer()
            
            // Actions
            if isHovered || showActions {
                actionButtons
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onPaste()
        }
        .contextMenu {
            contextMenuItems
        }
    }
    
    // MARK: - Type Icon
    private var typeIcon: some View {
        ZStack {
            Circle()
                .fill(typeColor.opacity(0.15))
                .frame(width: 28, height: 28)
            
            Image(systemName: item.type.icon)
                .font(.system(size: 12))
                .foregroundColor(typeColor)
        }
    }
    
    private var typeColor: Color {
        switch item.type {
        case .text: return .blue
        case .image: return .purple
        case .file: return .orange
        case .url: return .green
        }
    }
    
    // MARK: - Content View
    @ViewBuilder
    private var contentView: some View {
        switch item.type {
        case .image:
            imageContent
        default:
            if !searchQuery.isEmpty && !highlightedRanges.isEmpty {
                // 显示高亮文本
                highlightedText
            } else {
                Text(item.previewText)
                    .font(.subheadline)
                    .lineLimit(2)
                    .foregroundColor(.primary)
            }
        }
    }
    
    private var imageContent: some View {
        Group {
            if let image = loadedImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 60)
                    .cornerRadius(4)
            } else if isLoadingImage {
                ProgressView()
                    .frame(width: 60, height: 40)
            } else {
                Text("📷 图片")
                    .font(.subheadline)
                    .lineLimit(2)
            }
        }
        .onAppear {
            loadImageIfNeeded()
        }
        .onDisappear {
            // 取消加载任务以节省资源
            if isLoadingImage {
                AsyncImageLoader.shared.cancelLoading(for: item.id)
            }
        }
    }
    
    private func loadImageIfNeeded() {
        guard item.type == .image,
              loadedImage == nil,
              !isLoadingImage,
              let imageData = item.imageData else { return }
        
        isLoadingImage = true
        
        AsyncImageLoader.shared.loadImage(from: imageData, id: item.id) { image in
            self.loadedImage = image
            self.isLoadingImage = false
        }
    }
    
    // MARK: - Highlighted Text
    private var highlightedText: some View {
        let text = item.previewText
        var components: [(String, Bool)] = []
        var currentIndex = 0
        
        // 合并重叠的范围
        let mergedRanges = mergeRanges(highlightedRanges)
        
        for range in mergedRanges {
            // 添加范围前的普通文本
            if currentIndex < range.lowerBound && range.lowerBound <= text.count {
                let start = text.index(text.startIndex, offsetBy: currentIndex)
                let end = text.index(text.startIndex, offsetBy: min(range.lowerBound, text.count))
                components.append((String(text[start..<end]), false))
            }
            
            // 添加高亮文本
            if range.lowerBound < text.count {
                let start = text.index(text.startIndex, offsetBy: range.lowerBound)
                let end = text.index(text.startIndex, offsetBy: min(range.upperBound + 1, text.count))
                components.append((String(text[start..<end]), true))
            }
            
            currentIndex = range.upperBound + 1
        }
        
        // 添加剩余文本
        if currentIndex < text.count {
            let start = text.index(text.startIndex, offsetBy: currentIndex)
            components.append((String(text[start...]), false))
        }
        
        return Text(buildAttributedString(from: components))
            .font(.subheadline)
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
    
    // MARK: - Metadata View
    private var metadataView: some View {
        HStack(spacing: 6) {
            // Time
            Text(item.formattedDate)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            // App Source
            if let app = item.appSource {
                Text("•")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(app)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Tags
            if !item.tags.isEmpty {
                Text("•")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                ForEach(item.tags.prefix(2), id: \.self) { tag in
                    Text(tag)
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.2))
                        .cornerRadius(3)
                }
            }
            
            // Pin indicator
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 4) {
            ActionButton(icon: "doc.on.doc", tooltip: "复制") {
                onCopy()
            }
            
            ActionButton(icon: item.isPinned ? "pin.slash" : "pin", tooltip: item.isPinned ? "取消固定" : "固定") {
                onTogglePin()
            }
            
            ActionButton(icon: "trash", tooltip: "删除", isDestructive: true) {
                onDelete()
            }
        }
    }
    
    // MARK: - Context Menu
    @ViewBuilder
    private var contextMenuItems: some View {
        Button(action: onPaste) {
            Label("粘贴", systemImage: "doc.on.clipboard")
        }
        
        Button(action: onCopy) {
            Label("复制到剪贴板", systemImage: "doc.on.doc")
        }
        
        Divider()
        
        Button(action: onTogglePin) {
            Label(item.isPinned ? "取消固定" : "固定", systemImage: item.isPinned ? "pin.slash" : "pin")
        }
        
        Divider()
        
        Button(role: .destructive, action: onDelete) {
            Label("删除", systemImage: "trash")
        }
    }
}

// MARK: - Action Button
struct ActionButton: View {
    let icon: String
    let tooltip: String
    var isDestructive: Bool = false
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(isDestructive && isHovered ? .red : .secondary)
                .frame(width: 22, height: 22)
                .background(isHovered ? Color.secondary.opacity(0.2) : Color.clear)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Preview
#Preview {
    VStack {
        ClipboardItemRow(
            item: ClipboardItem.fromText("这是一段测试文本内容，用于预览剪贴板项目的显示效果。"),
            isHovered: true,
            onPaste: {},
            onCopy: {},
            onDelete: {},
            onTogglePin: {}
        )
        
        ClipboardItemRow(
            item: ClipboardItem(type: .url, urlString: "https://www.apple.com"),
            isHovered: false,
            onPaste: {},
            onCopy: {},
            onDelete: {},
            onTogglePin: {}
        )
    }
    .padding()
    .frame(width: 320)
}
