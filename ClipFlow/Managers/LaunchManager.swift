import Foundation
import ServiceManagement
import os.log

/// 管理应用开机自启动
class LaunchManager {
    static let shared = LaunchManager()
    
    private let logger = Logger(subsystem: "com.ClipFlow.app", category: "LaunchManager")
    private let suiteName = "com.ClipFlow.app"
    
    private init() {}
    
    /// 检查应用是否已设置为开机自启动
    var isLaunchAtLoginEnabled: Bool {
        get {
            // 检查 SMAppService 状态
            let service = SMAppService.mainApp
            return service.status == .enabled
        }
    }
    
    /// 设置开机自启动状态
    /// - Parameter enabled: true 启用，false 禁用
    /// - Returns: 是否设置成功
    @discardableResult
    func setLaunchAtLogin(enabled: Bool) -> Bool {
        let service = SMAppService.mainApp
        
        do {
            if enabled {
                try service.register()
                logger.info("✅ 已启用开机自启动")
            } else {
                try service.unregister()
                logger.info("✅ 已禁用开机自启动")
            }
            return true
        } catch {
            logger.error("❌ 设置开机自启动失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 切换开机自启动状态
    /// - Returns: 切换后的状态
    @discardableResult
    func toggleLaunchAtLogin() -> Bool {
        let newState = !isLaunchAtLoginEnabled
        _ = setLaunchAtLogin(enabled: newState)
        return newState
    }
}

// MARK: - 用户默认值扩展
extension UserDefaults {
    var launchAtLogin: Bool {
        get {
            // 使用 SMAppService 的实际状态，而不是 UserDefaults
            return LaunchManager.shared.isLaunchAtLoginEnabled
        }
        set {
            _ = LaunchManager.shared.setLaunchAtLogin(enabled: newValue)
        }
    }
}
