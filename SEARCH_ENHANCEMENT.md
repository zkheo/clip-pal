# 🔍 搜索功能增强说明

## 功能概述

已成功集成增强搜索功能，包含以下特性：

1. **模糊搜索 (Fuzzy Search)** - 使用 Bitap 算法，支持拼写容错
2. **拼音搜索** - 支持中文内容拼音匹配
3. **高亮显示** - 搜索结果自动高亮匹配部分
4. **匹配度排序** - 结果按匹配分数排序，而非时间
5. **防抖优化** - 150ms 防抖避免频繁搜索

## 文件变更

### 代码位置

搜索功能代码已整合到现有文件中：

```
ClipFlow/ClipFlow/
├── Extensions/Extensions.swift          # PinyinConverter 拼音转换器
├── Managers/ClipboardManager.swift      # SearchService + Fuse 搜索实现
└── Models/ClipboardItem.swift           # SearchResult 搜索结果模型
```

### 修改文件

1. **ClipboardManager.swift**
   - 添加 `searchResults` 发布属性
   - 集成 `SearchService` 进行模糊搜索
   - 添加搜索防抖逻辑

2. **ClipboardItemView.swift**
   - `ClipboardItemRow` 支持高亮显示匹配文本
   - 新增 `highlightedRanges` 参数

3. **MenuBarView.swift**
   - 传递搜索信息到列表项
   - 搜索结果标题显示为"搜索结果"

4. **PopupWindow.swift**
   - `PopupViewModel` 使用 `SearchService`
   - `PopupItemRow` 支持高亮显示

5. **AGENTS.md**
   - 更新依赖说明，添加搜索增强文档

## 技术实现

### 搜索算法

使用简化的 Fuse.js（Bitap 算法）：

- **编辑距离计算** - Levenshtein 距离
- **模糊匹配** - 支持容错匹配
- **阈值控制** - 匹配分数阈值 0.4（严格模式）

### 拼音搜索

```swift
// 支持全拼和首字母搜索
"jianqieban" 匹配 "剪贴板"
"jtb" 匹配 "剪贴板"
```

### 搜索优先级

1. 原始文本精确匹配（权重最高）
2. 原始文本模糊匹配
3. 拼音全拼匹配（权重降低 0.1）
4. 拼音首字母匹配（权重降低 0.2）

### 高亮显示

匹配结果使用黄色背景高亮：
- 匹配字符：黄色背景（40% 透明度）
- 非匹配字符：正常显示
- 自动合并重叠的匹配范围

## 使用方法

### 在视图中显示高亮

```swift
// 获取搜索结果的匹配信息
let searchResult = clipboardManager.searchResult(for: item)

// 传递给 ClipboardItemRow
ClipboardItemRow(
    item: item,
    isHovered: hoveredItemId == item.id,
    searchQuery: clipboardManager.searchQuery,
    highlightedRanges: searchResult?.highlightedRanges ?? [],
    // ... other parameters
)
```

### 搜索服务直接使用

```swift
import Foundation

let searchService = SearchService.shared

// 搜索剪贴板项目
let results = searchService.search("query", in: items)

// 高亮文本
let attributedString = searchService.highlightMatches(
    in: text,
    ranges: ranges,
    highlightColor: .systemYellow
)
```

## 性能优化

- **防抖处理** - 150ms 延迟避免频繁搜索
- **懒加载** - 使用 `LazyVStack` 优化大列表
- **范围合并** - 自动合并重叠的高亮范围减少渲染
- **限制文本长度** - 剪贴板文本限制 500 字符

## 未来扩展

- [ ] 支持自定义匹配阈值
- [ ] 添加搜索历史（已禁用）
- [ ] 支持正则表达式搜索
- [ ] 多字段权重配置（标题、内容、标签）

## 注意事项

1. 拼音库为简化版本，包含常用汉字映射
2. 复杂中文或生僻字可能无法正确转拼音
3. 搜索性能取决于剪贴板历史数量（建议保持 <1000 条）

## 调试技巧

在 `SearchService.search()` 方法中添加日志：

```swift
print("搜索查询: \(query)")
print("找到 \(results.count) 个结果")
for result in results.prefix(5) {
    print("  - \(result.item.previewText): \(result.score)")
}
```
