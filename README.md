# ClipPal - 剪贴板管理器

一款简洁高效的 macOS 剪贴板管理工具，支持菜单栏常驻和全局快捷键唤出。

<img width="3024" height="1964" alt="89A0ED82-C5F5-43E3-A4FA-32E487711522" src="https://github.com/user-attachments/assets/05fa1e1b-1760-4ff5-9c0b-efb24cf4e4de" />

<img width="3024" height="1964" alt="99C0F2F9-0D47-45FE-B05C-AFC73524D031" src="https://github.com/user-attachments/assets/115ac159-fe71-456d-b9e6-f5ff8decd57e" />



## 功能特性

- **剪贴板历史记录** - 自动记录复制的文本、图片、文件和链接
- **菜单栏快速访问** - 点击菜单栏图标即可查看历史记录
- **全局快捷键** - 按 `⌘⇧V` 快速打开搜索窗口
- **搜索功能** - 快速搜索历史记录
- **固定常用项** - 将常用内容固定在顶部
- **分类筛选** - 按类型（文本/图片/文件/链接）筛选
- **标签管理** - 为剪贴板项目添加标签
- **数据持久化** - 历史记录自动保存

## 系统要求

- macOS 13.0 或更高版本
- Apple Silicon (M1/M2/M3) 或 Intel 处理器

## 安装

1. 使用 Xcode 15.0 或更高版本打开 `ClipFlow.xcodeproj`
2. 选择您的开发者团队进行签名
3. 编译并运行

## 使用说明

### 菜单栏操作
- 点击菜单栏图标 📋 打开剪贴板历史
- 单击历史记录项复制到剪贴板
- 双击历史记录项直接粘贴

### 快捷键
| 快捷键 | 功能 |
|--------|------|
| `⌘⇧V` | 打开搜索窗口 |
| `↑` `↓` | 选择上/下一项 |
| `↵` Return | 粘贴选中项 |
| `ESC` | 关闭窗口 |

### 权限设置
应用需要"辅助功能"权限才能使用全局快捷键和自动粘贴功能：
1. 打开 **系统偏好设置** → **隐私与安全性** → **辅助功能**
2. 点击锁图标解锁
3. 添加 ClipFlow 应用并启用

## 项目结构

```
ClipFlow/
├── ClipFlowApp.swift        # 应用入口
├── AppDelegate.swift        # 应用代理
├── ContentView.swift        # 主视图
├── Models/
│   └── ClipboardItem.swift  # 数据模型
├── Views/
│   ├── MenuBarView.swift    # 菜单栏视图
│   ├── PopupWindow.swift    # 弹窗视图
│   ├── ClipboardItemView.swift  # 列表项视图
│   ├── SearchView.swift     # 搜索视图
│   └── SettingsView.swift   # 设置视图
├── Managers/
│   ├── ClipboardManager.swift   # 剪贴板管理
│   ├── HotKeyManager.swift      # 快捷键管理
│   └── StorageManager.swift     # 存储管理
└── Extensions/
    └── Extensions.swift     # 扩展方法
```

## 技术栈

- SwiftUI
- AppKit
- Carbon (全局快捷键)

## 许可证

MIT License
