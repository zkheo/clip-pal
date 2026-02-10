import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager

    @AppStorage("maxHistoryCount") private var maxHistoryCount = 100
    @AppStorage("clearOnQuit") private var clearOnQuit = false
    @AppStorage("ignoreConsecutiveDuplicates") private var ignoreDuplicates = true
    @State private var launchAtLogin = LaunchManager.shared.isLaunchAtLoginEnabled

    var body: some View {
        TabView {
            // 通用设置
            generalSettings
                .tabItem {
                    Label("通用", systemImage: "gear")
                }

            // 历史设置
            historySettings
                .tabItem {
                    Label("历史", systemImage: "clock")
                }

            // 快捷键
            shortcutsSettings
                .tabItem {
                    Label("快捷键", systemImage: "keyboard")
                }

            // 关于
            aboutView
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
        }
        .frame(width: 480, height: 340)
    }

    // MARK: - 通用设置
    private var generalSettings: some View {
        Form {
            Section("启动") {
                Toggle("开机时自动启动", isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        launchAtLogin = newValue
                        let success = LaunchManager.shared.setLaunchAtLogin(enabled: newValue)
                        if !success {
                            // 如果设置失败，恢复开关状态
                            launchAtLogin = !newValue
                        }
                    }
                ))
            }

            Section("行为") {
                Toggle("忽略连续重复内容", isOn: $ignoreDuplicates)
            }

            Section("退出") {
                Toggle("退出时清空历史（固定项除外）", isOn: $clearOnQuit)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    // MARK: - 历史设置
    private var historySettings: some View {
        Form {
            Section {
                Picker("最大历史记录数", selection: $maxHistoryCount) {
                    Text("50 条").tag(50)
                    Text("100 条").tag(100)
                    Text("200 条").tag(200)
                    Text("500 条").tag(500)
                    Text("1000 条").tag(1000)
                }
            } header: {
                Text("限制")
            } footer: {
                Text("当历史记录超过此数量时，最早的记录将被自动删除。")
            }
            
            Section {
                HStack {
                    Text("当前记录数")
                    Spacer()
                    Text("\(clipboardManager.items.count) 条")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("固定项数量")
                    Spacer()
                    Text("\(clipboardManager.pinnedItems.count) 条")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("统计")
            }
            
            Section {
                Button("清空所有历史记录", role: .destructive) {
                    clipboardManager.clearAll()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    // MARK: - 快捷键设置
    private var shortcutsSettings: some View {
        Form {
            Section("快捷键") {
                HStack {
                    Text("显示搜索窗口")
                    Spacer()
                    Text("⌘ ⇧ V")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
                
                HStack {
                    Text("粘贴选中项")
                    Spacer()
                    Text("↵")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
                
                HStack {
                    Text("关闭窗口")
                    Spacer()
                    Text("ESC")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            
            Section {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("全局快捷键需要辅助功能权限")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button("打开辅助功能设置") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            } header: {
                Text("权限")
            } footer: {
                Text("请在系统偏好设置中为 ClipPal 授予辅助功能权限，以启用全局快捷键。")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    // MARK: - 关于
    private var aboutView: some View {
        VStack(spacing: 0) {
            // App Icon & Info
            VStack(spacing: 12) {
                // App Icon
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.accentColor)
                    .shadow(color: .accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                
                // App Name
                Text("ClipPal")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                // Version
                Text("版本 1.0.0")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            .padding(.bottom, 32)
            
            Divider()
                .padding(.horizontal, 40)
            
            // Info Section
            VStack(spacing: 16) {
                // Description
                VStack(spacing: 4) {
                    Text("简洁高效的剪贴板管理工具")
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                    
                    Text("专为 macOS 设计")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                // Contact Info
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("3033453566@qq.com")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("QQ: 3033453566")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 8)
            }
            .padding(.vertical, 24)
            
            Spacer()
            
            // Bottom Actions
            VStack(spacing: 16) {
                Divider()
                    .padding(.horizontal, 40)
                
                // Quit Button
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "power")
                            .font(.system(size: 10))
                        Text("退出 ClipPal")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(PlainButtonStyle())
                .background(Color.red.opacity(0.1))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.red.opacity(0.3), lineWidth: 0.5)
                )
                
                // Copyright
                Text("© 2026 ClipPal. All rights reserved.")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.7))
                    .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Preview
#Preview {
    SettingsView()
        .environmentObject(ClipboardManager())
}
