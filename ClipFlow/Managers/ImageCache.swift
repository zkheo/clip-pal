import Foundation
import AppKit

// MARK: - Image Cache
/// 图片缓存管理器，使用LRU策略管理内存中的图片
final class ImageCache {
    static let shared = ImageCache()
    
    private var cache: [UUID: NSImage] = [:]
    private var accessOrder: [UUID] = []
    private let lock = NSLock()
    private let maxCacheSize = 50 // 最多缓存50张图片
    private let maxMemorySize: Int = 50 * 1024 * 1024 // 50MB内存限制
    private var currentMemorySize: Int = 0
    
    private init() {}
    
    /// 从缓存获取图片
    func image(for id: UUID) -> NSImage? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let image = cache[id] else { return nil }
        
        // 更新访问顺序（LRU）
        if let index = accessOrder.firstIndex(of: id) {
            accessOrder.remove(at: index)
            accessOrder.append(id)
        }
        
        return image
    }
    
    /// 缓存图片
    func setImage(_ image: NSImage, for id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        
        // 计算图片大小
        let imageSize = estimateImageSize(image)
        
        // 如果单张图片超过10MB，不缓存
        guard imageSize < 10 * 1024 * 1024 else { return }
        
        // 清理缓存直到有足够空间
        while currentMemorySize + imageSize > maxMemorySize && !cache.isEmpty {
            evictLRU()
        }
        
        // 如果缓存已满，移除最久未使用的
        if cache.count >= maxCacheSize && !cache.keys.contains(id) {
            evictLRU()
        }
        
        // 如果已存在，更新大小
        if let existingImage = cache[id] {
            currentMemorySize -= estimateImageSize(existingImage)
            if let index = accessOrder.firstIndex(of: id) {
                accessOrder.remove(at: index)
            }
        }
        
        cache[id] = image
        accessOrder.append(id)
        currentMemorySize += imageSize
    }
    
    /// 移除缓存的图片
    func removeImage(for id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        
        if let image = cache.removeValue(forKey: id) {
            currentMemorySize -= estimateImageSize(image)
            accessOrder.removeAll { $0 == id }
        }
    }
    
    /// 清空所有缓存
    func clearCache() {
        lock.lock()
        defer { lock.unlock() }
        
        cache.removeAll()
        accessOrder.removeAll()
        currentMemorySize = 0
    }
    
    /// 获取缓存统计信息
    var stats: (count: Int, memorySize: String) {
        lock.lock()
        defer { lock.unlock() }
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return (cache.count, formatter.string(fromByteCount: Int64(currentMemorySize)))
    }
    
    // MARK: - Private Methods
    
    private func evictLRU() {
        guard let oldestId = accessOrder.first else { return }
        
        if let image = cache.removeValue(forKey: oldestId) {
            currentMemorySize -= estimateImageSize(image)
        }
        accessOrder.removeFirst()
    }
    
    private func estimateImageSize(_ image: NSImage) -> Int {
        // 估算图片内存占用
        let size = image.size
        let bytesPerPixel = 4 // RGBA
        return Int(size.width * size.height) * bytesPerPixel
    }
}

// MARK: - Async Image Loader
/// 异步图片加载器，避免主线程阻塞
final class AsyncImageLoader {
    static let shared = AsyncImageLoader()
    
    private let queue = DispatchQueue(label: "com.clipflow.imageLoader", qos: .userInitiated)
    private var loadingTasks: [UUID: DispatchWorkItem] = [:]
    private let lock = NSLock()
    
    private init() {}
    
    /// 异步加载图片
    func loadImage(from data: Data, id: UUID, completion: @escaping (NSImage?) -> Void) {
        // 先检查缓存
        if let cachedImage = ImageCache.shared.image(for: id) {
            completion(cachedImage)
            return
        }
        
        // 取消之前的加载任务
        cancelLoading(for: id)
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            // 在后台线程解码图片
            guard let image = NSImage(data: data) else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            // 如果图片太大，进行压缩
            let processedImage = self.processImage(image)
            
            // 存入缓存
            ImageCache.shared.setImage(processedImage, for: id)
            
            // 清理任务引用
            self.lock.lock()
            self.loadingTasks.removeValue(forKey: id)
            self.lock.unlock()
            
            DispatchQueue.main.async {
                completion(processedImage)
            }
        }
        
        lock.lock()
        loadingTasks[id] = workItem
        lock.unlock()
        
        queue.async(execute: workItem)
    }
    
    /// 取消加载任务
    func cancelLoading(for id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        
        loadingTasks[id]?.cancel()
        loadingTasks.removeValue(forKey: id)
    }
    
    // MARK: - Private Methods
    
    private func processImage(_ image: NSImage) -> NSImage {
        let maxSize: CGFloat = 800 // 最大边长
        let size = image.size
        
        // 如果图片不大，直接返回
        guard max(size.width, size.height) > maxSize else { return image }
        
        // 计算新尺寸
        let scale = maxSize / max(size.width, size.height)
        let newSize = NSSize(width: size.width * scale, height: size.height * scale)
        
        // 创建压缩后的图片
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: size),
                   operation: .copy,
                   fraction: 1.0)
        newImage.unlockFocus()
        
        return newImage
    }
}
