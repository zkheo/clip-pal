import SwiftUI
import AppKit
import Carbon.HIToolbox

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var popupWindow: PopupWindowController?
    var settingsWindow: NSWindow?
    var settingsWindowController: NSWindowController?
    let clipboardManager = ClipboardManager()
    let hotKeyManager = HotKeyManager()
    var eventMonitor: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        setupHotKey()
        setupEventMonitor()
        setupNotifications()
        clipboardManager.startMonitoring()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        clipboardManager.stopMonitoring()
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    // MARK: - Status Item Setup
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "ClipFlow")
            button.action = #selector(togglePopover)
            button.target = self
        }
    }
    
    // MARK: - Popover Setup
    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 450)
        popover.behavior = .transient
        popover.animates = true
        // 注意：不在此处设置 contentViewController，每次显示时重新创建
    }
    
    private func createPopoverContent() {
        // 完全重置搜索状态
        clipboardManager.resetSearchState()
        
        // 重新创建视图控制器，确保状态完全重置
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView()
                .environmentObject(clipboardManager)
        )
    }

    // MARK: - Hot Key Setup
    private func setupHotKey() {
        // Register global hotkey: Cmd + Shift + V
        hotKeyManager.register(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | shiftKey)) { [weak self] in
            self?.showPopupWindow()
        }
    }

    // MARK: - Event Monitor
    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let popover = self?.popover, popover.isShown {
                popover.performClose(nil)
            }
        }
    }
    
    // MARK: - Notifications
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowSettings),
            name: .showSettingsWindow,
            object: nil
        )
    }
    
    @objc private func handleShowSettings() {
        showSettings()
    }

    // MARK: - Actions
    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            // 关闭快捷键的搜索窗口（如果打开），避免状态冲突
            hidePopupWindow()
            
            // 每次显示前重新创建视图内容，确保状态完全重置
            createPopoverContent()
            
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            if let window = popover.contentViewController?.view.window {
                window.makeKey()
            }
        }
    }
    
    func showPopupWindow() {
        if popupWindow == nil {
            popupWindow = PopupWindowController(clipboardManager: clipboardManager)
        }
        popupWindow?.showWindow()
    }
    
    func hidePopupWindow() {
        popupWindow?.hideWindow()
    }
    
    // MARK: - Show Settings
    @objc private func showSettings() {
        // 关闭 popover（如果打开）
        if popover.isShown {
            popover.performClose(nil)
        }
        
        // 如果窗口已存在，直接显示
        if let existingController = settingsWindowController, let window = existingController.window {
            window.makeKeyAndOrderFront(nil)
            return
        }
        
        // 创建设置窗口控制器
        let settingsView = SettingsView()
            .environmentObject(clipboardManager)
        
        let hostingController = NSHostingController(rootView: settingsView)
        hostingController.title = "设置"
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "设置"
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.center()
        window.setFrameAutosaveName("ClipFlowSettings")
        
        // 使用 NSWindowController 管理窗口生命周期
        let windowController = NSWindowController(window: window)
        windowController.showWindow(nil)
        
        settingsWindowController = windowController
        settingsWindow = window
    }
}
