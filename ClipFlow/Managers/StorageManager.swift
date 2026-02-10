import Foundation

// MARK: - Storage Manager with Retry
/// 增强版存储管理器，支持重试机制和错误恢复
class StorageManager {
    private let fileManager = FileManager.default
    private let dataFileName = "clipboard_data.json"
    private let backupFileName = "clipboard_data_backup.json"
    
    private var dataDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let clipFlowDir = appSupport.appendingPathComponent("ClipFlow", isDirectory: true)
        
        if !fileManager.fileExists(atPath: clipFlowDir.path) {
            try? fileManager.createDirectory(at: clipFlowDir, withIntermediateDirectories: true)
        }
        
        return clipFlowDir
    }
    
    private var dataFileURL: URL {
        dataDirectory.appendingPathComponent(dataFileName)
    }
    
    private var backupFileURL: URL {
        dataDirectory.appendingPathComponent(backupFileName)
    }
    
    // MARK: - Retry Configuration
    private let maxRetryCount = 3
    private let retryDelay: TimeInterval = 0.5
    
    // MARK: - Save & Load with Retry
    func saveClipboardData(_ data: ClipboardData) {
        performSave(data: data, retryCount: 0)
    }
    
    private func performSave(data: ClipboardData, retryCount: Int) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(data)
            
            // 先写入临时文件
            let tempURL = dataFileURL.appendingPathExtension("tmp")
            try jsonData.write(to: tempURL, options: .atomic)
            
            // 备份旧文件
            if fileManager.fileExists(atPath: dataFileURL.path) {
                try? fileManager.removeItem(at: backupFileURL)
                try? fileManager.moveItem(at: dataFileURL, to: backupFileURL)
            }
            
            // 移动临时文件到目标位置
            try fileManager.moveItem(at: tempURL, to: dataFileURL)
            
            // 清理临时文件
            try? fileManager.removeItem(at: tempURL)
            
        } catch {
            if retryCount < maxRetryCount {
                DispatchQueue.global().asyncAfter(deadline: .now() + retryDelay) { [weak self] in
                    self?.performSave(data: data, retryCount: retryCount + 1)
                }
            } else {
                print("Failed to save clipboard data after \(maxRetryCount) retries: \(error)")
                // 通知用户保存失败
                notifySaveFailure(error: error)
            }
        }
    }
    
    func loadClipboardData() -> ClipboardData? {
        // 首先尝试加载主文件
        if let data = loadFromURL(dataFileURL) {
            return data
        }
        
        // 如果主文件加载失败，尝试备份文件
        if let backupData = loadFromURL(backupFileURL) {
            print("Recovered data from backup file")
            // 恢复备份到主文件
            try? fileManager.removeItem(at: dataFileURL)
            try? fileManager.copyItem(at: backupFileURL, to: dataFileURL)
            return backupData
        }
        
        return nil
    }
    
    private func loadFromURL(_ url: URL) -> ClipboardData? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(ClipboardData.self, from: data)
        } catch {
            print("Failed to load from \(url.lastPathComponent): \(error)")
            return nil
        }
    }
    
    // MARK: - Export & Import
    func exportData(to url: URL) throws {
        guard let data = loadClipboardData() else {
            throw StorageError.noDataToExport
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(data)
        try jsonData.write(to: url)
    }
    
    func importData(from url: URL) throws -> ClipboardData {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ClipboardData.self, from: data)
    }
    
    // MARK: - Clear Data
    func clearAllData() {
        try? fileManager.removeItem(at: dataFileURL)
        try? fileManager.removeItem(at: backupFileURL)
    }
    
    // MARK: - Storage Info
    var storageSize: String {
        let mainSize = fileSize(at: dataFileURL)
        let backupSize = fileSize(at: backupFileURL)
        let totalSize = mainSize + backupSize
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }
    
    private func fileSize(at url: URL) -> Int64 {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else {
            return 0
        }
        return size
    }
    
    // MARK: - Error Notification
    private func notifySaveFailure(error: Error) {
        // 发送通知，可以在UI中显示错误
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .storageSaveFailed,
                object: nil,
                userInfo: ["error": error]
            )
        }
    }
}

enum StorageError: LocalizedError {
    case noDataToExport
    case invalidData
    case saveFailed(underlying: Error)
    
    var errorDescription: String? {
        switch self {
        case .noDataToExport:
            return "没有可导出的数据"
        case .invalidData:
            return "数据格式无效"
        case .saveFailed(let error):
            return "保存失败: \(error.localizedDescription)"
        }
    }
}
