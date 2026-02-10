import Foundation
import Carbon.HIToolbox
import AppKit

// MARK: - HotKey Manager
/// 全局热键管理器，支持快捷键注册和反注册
final class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyID: EventHotKeyID
    private var callback: (() -> Void)?
    private var isRegistered = false
    
    init() {
        hotKeyID = EventHotKeyID(signature: OSType(0x434C4950), id: 1) // "CLIP"
        // 注册到全局管理器，使用弱引用避免循环
        HotKeyGlobalManager.shared.register(self)
    }
    
    deinit {
        unregister()
        HotKeyGlobalManager.shared.unregister(self)
    }
    
    func register(keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) {
        // 如果已经注册，先反注册
        if isRegistered {
            unregister()
        }
        
        self.callback = callback
        
        // Convert to Carbon modifiers
        var carbonMods: UInt32 = 0
        if modifiers & UInt32(cmdKey) != 0 { carbonMods |= UInt32(cmdKey) }
        if modifiers & UInt32(shiftKey) != 0 { carbonMods |= UInt32(shiftKey) }
        if modifiers & UInt32(optionKey) != 0 { carbonMods |= UInt32(optionKey) }
        if modifiers & UInt32(controlKey) != 0 { carbonMods |= UInt32(controlKey) }
        
        // 确保事件处理器已安装（全局只安装一次）
        HotKeyGlobalManager.shared.installEventHandlerIfNeeded()
        
        // Register hotkey
        let status = RegisterEventHotKey(
            keyCode,
            carbonMods,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        isRegistered = (status == noErr)
        
        if status != noErr {
            print("Failed to register hotkey, status: \(status)")
        }
    }
    
    func unregister() {
        guard isRegistered else { return }
        
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        
        isRegistered = false
        callback = nil
    }
    
    func handleHotKey() {
        DispatchQueue.main.async { [weak self] in
            self?.callback?()
        }
    }
}

// MARK: - Global HotKey Manager
/// 全局热键管理器，负责安装事件处理器和管理所有热键实例
private final class HotKeyGlobalManager {
    static let shared = HotKeyGlobalManager()
    
    private var managers: [WeakHotKeyManager] = []
    private var isHandlerInstalled = false
    private let lock = NSLock()
    
    private init() {}
    
    func installEventHandlerIfNeeded() {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isHandlerInstalled else { return }
        
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventHandler,
            1,
            &eventSpec,
            nil,
            nil
        )
        
        isHandlerInstalled = true
    }
    
    func register(_ manager: HotKeyManager) {
        lock.lock()
        defer { lock.unlock() }
        
        // 清理已释放的引用
        managers.removeAll { $0.manager == nil }
        
        // 添加新引用
        managers.append(WeakHotKeyManager(manager: manager))
    }
    
    func unregister(_ manager: HotKeyManager) {
        lock.lock()
        defer { lock.unlock() }
        
        managers.removeAll { $0.manager === manager || $0.manager == nil }
    }
    
    func handleHotKey() {
        lock.lock()
        let activeManagers = managers.compactMap { $0.manager }
        lock.unlock()
        
        // 调用所有活动的热键管理器
        activeManagers.forEach { $0.handleHotKey() }
    }
}

// MARK: - Weak Reference Wrapper
private struct WeakHotKeyManager {
    weak var manager: HotKeyManager?
}

// MARK: - Event Handler
private func hotKeyEventHandler(_: EventHandlerCallRef?, event: EventRef?, _: UnsafeMutableRawPointer?) -> OSStatus {
    HotKeyGlobalManager.shared.handleHotKey()
    return noErr
}

// MARK: - Keyboard Shortcut Helper
struct KeyboardShortcut {
    let keyCode: UInt32
    let modifiers: UInt32
    let displayString: String
    
    static let defaultShortcut = KeyboardShortcut(
        keyCode: UInt32(kVK_ANSI_V),
        modifiers: UInt32(cmdKey | shiftKey),
        displayString: "⌘⇧V"
    )
}
