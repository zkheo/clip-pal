# CODEBUDDY.md This file provides guidance to CodeBuddy when working with code in this repository.

## 常用命令

### 构建与运行
- 使用 Xcode 15.0+ 打开 `ClipFlow.xcodeproj`，选择目标设备后按 `⌘R` 运行项目
- `⌘B` 仅构建项目
- `⌘.` 停止运行

### 测试
- 在 Xcode 中按 `⌘U` 运行所有测试
- 在 Test Navigator 中右键单个测试用例并选择 "Run" 运行单个测试

## 代码架构

### 核心架构
ClipFlow 是一个基于 SwiftUI 和 AppKit 的 macOS 菜单栏应用，采用 MVVM 架构模式。应用通过以下三个核心管理层协调功能：

**AppDelegate** 作为应用生命周期管理器，负责初始化并协调各个组件：
- 初始化 `NSStatusItem` 创建菜单栏图标
- 管理 `NSPopover` 实现点击菜单栏弹出的下拉界面
- 通过 `HotKeyManager` 注册全局快捷键（Carbon API）
- 创建 `ClipboardManager` 实例并通过 `@EnvironmentObject` 注入到视图层

**ClipboardManager** 是核心业务逻辑层，继承自 `ObservableObject`，作为单一数据源：
- 定时轮询 `NSPasteboard`（0.5秒间隔）检测剪贴板变化
- 使用 Combine 的 `$items` 和 `$pinnedItems` 发布器，配合 `debounce` 实现自动保存（延迟1秒）
- 维护两个数组：`items`（历史记录）和 `pinnedItems`（固定项），`allItems` 计算属性将两者合并显示
- `paste()` 方法通过 CGEvent 模拟 `⌘V` 实现粘贴，同时更新 `lastChangeCount` 避免重复捕获
- 支持四种剪贴板类型：文本、URL、图片（PNG格式）、文件路径数组

**StorageManager** 负责数据持久化：
- 将数据存储在 `~/Library/Application Support/ClipFlow/clipboard_data.json`
- 使用 JSON 编码/解码，支持 ISO8601 日期格式
- 提供导出/导入功能用于数据迁移

### 视图层架构
应用有两个主要界面：

**MenuBarView**：菜单栏弹出视图（320×450），包含：
- 搜索栏、类型筛选器（FilterChip）、内容列表（区分固定项和最近复制）
- 使用 `ClipboardItemRow` 显示每个项目，支持悬停时显示操作按钮
- 点击项目调用 `copyToClipboard()`，双击项目调用 `paste()`

**PopupWindow**：全局快捷键唤出的搜索窗口（600×400），特点：
- 自定义 `PopupPanel` 继承 `NSPanel`，设置 `.floating` 窗口级别和 `.nonactivatingPanel` 风格
- 重写 `keyDown` 方法处理键盘事件：ESC 关闭、↑↓ 选择、Return 粘贴
- 使用 `PopupViewModel` 管理选择状态和搜索过滤
- 搜索框自动聚焦（`@FocusState`），支持回车直接粘贴选中项

### 数据模型
- `ClipboardItem` 结构体包含类型、内容、创建时间、固定状态、标签数组、来源应用等字段
- 实现 `Equatable` 协议，通过内容而非 ID 比较是否重复，用于去重逻辑
- 静态工厂方法 `fromText()` / `fromImage()` / `fromFiles()` 处理不同类型的剪贴板内容
- `Tag` 结构体支持颜色标签，`defaultTags` 提供预置标签

### 快捷键与权限
- 全局快捷键注册使用 Carbon API（`RegisterEventHotKey` / `InstallEventHandler`）
- 需要在系统偏好设置 → 隐私与安全性 → 辅助功能 中授予权限
- 应用使用 `ClipFlow.entitlements` 配置权限（如果存在辅助功能需求）

### 设置持久化
使用 `@AppStorage` 包装器将设置保存到 UserDefaults：
- `maxHistoryCount`：最大历史记录数（50/100/200/500/1000）
- `clearOnQuit`：退出时清空
- `ignoreConsecutiveDuplicates`：忽略连续重复
- `playSoundOnCopy`：复制时播放提示音
- `launchAtLogin`：开机启动（需要实现 Launch Services 集成）
