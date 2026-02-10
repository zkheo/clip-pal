import SwiftUI

struct SearchView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @Binding var searchText: String
    @FocusState.Binding var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜索...", text: $searchText)
                .textFieldStyle(.plain)
                .focused($isFocused)
            
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
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Advanced Search View
struct AdvancedSearchView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @Binding var searchText: String
    @Binding var selectedType: ClipboardItemType?
    @Binding var selectedTags: Set<String>
    @Binding var dateRange: DateRange
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Search Input
            SearchInputField(text: $searchText)
            
            // Type Filter
            TypeFilterSection(selectedType: $selectedType)
            
            // Tag Filter
            TagFilterSection(
                availableTags: clipboardManager.availableTags,
                selectedTags: $selectedTags
            )
            
            // Date Range Filter
            DateRangeSection(dateRange: $dateRange)
        }
        .padding()
    }
}

// MARK: - Search Input Field
struct SearchInputField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.title3)
            
            TextField("搜索剪贴板内容...", text: $text)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($isFocused)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .onAppear {
            isFocused = true
        }
    }
}

// MARK: - Type Filter Section
struct TypeFilterSection: View {
    @Binding var selectedType: ClipboardItemType?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("类型")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                TypeFilterButton(
                    title: "全部",
                    icon: "tray.full",
                    isSelected: selectedType == nil
                ) {
                    selectedType = nil
                }
                
                ForEach(ClipboardItemType.allCases, id: \.self) { type in
                    TypeFilterButton(
                        title: type.displayName,
                        icon: type.icon,
                        isSelected: selectedType == type
                    ) {
                        selectedType = type
                    }
                }
            }
        }
    }
}

// MARK: - Type Filter Button
struct TypeFilterButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tag Filter Section
struct TagFilterSection: View {
    let availableTags: [Tag]
    @Binding var selectedTags: Set<String>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("标签")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            FlowLayout(spacing: 6) {
                ForEach(availableTags) { tag in
                    TagButton(
                        tag: tag,
                        isSelected: selectedTags.contains(tag.name)
                    ) {
                        if selectedTags.contains(tag.name) {
                            selectedTags.remove(tag.name)
                        } else {
                            selectedTags.insert(tag.name)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Tag Button
struct TagButton: View {
    let tag: Tag
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(tag.name)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Color(hex: tag.color) : Color.secondary.opacity(0.15))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Date Range Section
struct DateRangeSection: View {
    @Binding var dateRange: DateRange
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("时间范围")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Picker("", selection: $dateRange) {
                ForEach(DateRange.allCases, id: \.self) { range in
                    Text(range.displayName).tag(range)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

// MARK: - Date Range Enum
enum DateRange: String, CaseIterable {
    case all = "all"
    case today = "today"
    case week = "week"
    case month = "month"
    
    var displayName: String {
        switch self {
        case .all: return "全部"
        case .today: return "今天"
        case .week: return "本周"
        case .month: return "本月"
        }
    }
    
    var startDate: Date? {
        let calendar = Calendar.current
        switch self {
        case .all: return nil
        case .today: return calendar.startOfDay(for: Date())
        case .week: return calendar.date(byAdding: .day, value: -7, to: Date())
        case .month: return calendar.date(byAdding: .month, value: -1, to: Date())
        }
    }
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, spacing: spacing, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, spacing: spacing, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            guard index < result.positions.count else { break }
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                     y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in width: CGFloat, spacing: CGFloat, subviews: Subviews) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var maxHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > width && x > 0 {
                    x = 0
                    y += maxHeight + spacing
                    maxHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                maxHeight = max(maxHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: width, height: y + maxHeight)
        }
    }
}
