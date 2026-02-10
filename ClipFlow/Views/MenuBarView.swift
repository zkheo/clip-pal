import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @State private var searchText = ""
    @State private var hoveredItemId: UUID?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Search Bar
            searchBarView
            
            Divider()
            
            // Filter Tabs
            filterTabsView
            
            Divider()
            
            // Content List
            contentListView
            
            Divider()
            
            // Footer
            footerView
        }
        .frame(width: 320, height: 450)
        .background(Color(NSColor.windowBackgroundColor))
        .onChange(of: clipboardManager.searchQuery) { newValue in
            // 当外部清空搜索时，同步更新本地搜索文本
            if newValue.isEmpty && !searchText.isEmpty {
                searchText = ""
            }
        }
        .onAppear {
            // 视图出现时，同步当前搜索状态
            searchText = clipboardManager.searchQuery
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage(systemSymbolName: "doc.on.clipboard.fill", accessibilityDescription: nil)!)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 22, height: 22)
                .cornerRadius(4)
            Text("ClipPal")
                .font(.headline)
            Spacer()
            Text("⌘⇧V")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
    
    // MARK: - Search Bar
    private var searchBarView: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜索剪贴板历史...", text: $searchText)
                .textFieldStyle(.plain)
                .onChange(of: searchText) { newValue in
                    clipboardManager.searchQuery = newValue
                }
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    // MARK: - Filter Tabs
    private var filterTabsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                FilterChip(
                    title: "全部",
                    icon: "tray.full",
                    isSelected: clipboardManager.selectedType == nil
                ) {
                    clipboardManager.selectedType = nil
                }
                
                ForEach(ClipboardItemType.allCases, id: \.self) { type in
                    FilterChip(
                        title: type.displayName,
                        icon: type.icon,
                        isSelected: clipboardManager.selectedType == type
                    ) {
                        clipboardManager.selectedType = type
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }
    
    // MARK: - Content List
    private var contentListView: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                // Pinned Section
                if !clipboardManager.pinnedItems.isEmpty {
                    sectionHeader("固定项", icon: "pin.fill")
                    
                    ForEach(clipboardManager.pinnedItems) { item in
                        let searchResult = clipboardManager.searchResult(for: item)
                        ClipboardItemRow(
                            item: item,
                            isHovered: hoveredItemId == item.id,
                            searchQuery: clipboardManager.searchQuery,
                            highlightedRanges: searchResult?.highlightedRanges ?? [],
                            onPaste: { clipboardManager.paste(item) },
                            onCopy: { clipboardManager.copyToClipboard(item) },
                            onDelete: { clipboardManager.deleteItem(item) },
                            onTogglePin: { clipboardManager.togglePin(item) }
                        )
                        .onHover { isHovered in
                            hoveredItemId = isHovered ? item.id : nil
                        }
                    }
                }
                
                // Recent Section
                if !clipboardManager.searchQuery.isEmpty {
                    sectionHeader("搜索结果", icon: "magnifyingglass")
                } else {
                    sectionHeader("最近复制", icon: "clock")
                }
                
                if clipboardManager.filteredItems.isEmpty {
                    emptyStateView
                } else {
                    ForEach(clipboardManager.filteredItems.filter { !$0.isPinned }) { item in
                        let searchResult = clipboardManager.searchResult(for: item)
                        ClipboardItemRow(
                            item: item,
                            isHovered: hoveredItemId == item.id,
                            searchQuery: clipboardManager.searchQuery,
                            highlightedRanges: searchResult?.highlightedRanges ?? [],
                            onPaste: { clipboardManager.paste(item) },
                            onCopy: { clipboardManager.copyToClipboard(item) },
                            onDelete: { clipboardManager.deleteItem(item) },
                            onTogglePin: { clipboardManager.togglePin(item) }
                        )
                        .onHover { isHovered in
                            hoveredItemId = isHovered ? item.id : nil
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Section Header
    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
            Spacer()
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("暂无剪贴板记录")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("复制内容后会自动显示在这里")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Footer
    private var footerView: some View {
        HStack {
            Button(action: {
                clipboardManager.clearUnpinned()
            }) {
                Label("清空历史", systemImage: "trash")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: {
                NotificationCenter.default.post(name: .showSettingsWindow, object: nil)
            }) {
                Image(systemName: "gear")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Image(systemName: "power")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .padding(.leading, 8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    MenuBarView()
        .environmentObject(ClipboardManager())
}
