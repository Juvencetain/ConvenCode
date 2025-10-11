import Foundation
import AppKit
import CoreData

class ClipboardMonitor {
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let persistenceController: PersistenceController
    
    // ========== ⭐ 新增：配置常量 ==========
    private let maxStringLength: Int = 1000  // 最大字符串长度
    private let maxHistoryCount: Int = 2000  // 最大历史记录数
    // ======================================
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        self.lastChangeCount = NSPasteboard.general.changeCount
    }
    
    // 开始监控剪贴板
    func startMonitoring() {
        // 每 3 秒检查一次剪贴板
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
        
        // 确保 timer 在 common run loop mode 下运行
        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
        }
        
        print("剪贴板监控已启动")
    }
    
    // 停止监控
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        print("剪贴板监控已停止")
    }
    
    // 检查剪贴板内容
    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount
        
        // 如果剪贴板内容有变化
        if currentChangeCount != lastChangeCount {
            lastChangeCount = currentChangeCount
            
            // 读取剪贴板中的字符串
            if let clipboardString = pasteboard.string(forType: .string) {
                // ========== ⭐ 新增：长度检查 ==========
                if clipboardString.count > maxStringLength {
                    print("⚠️ 剪贴板内容过长 (\(clipboardString.count) 字符)，已跳过保存")
                    return
                }
                // ======================================
                
                saveToDatabase(data: clipboardString)
            }
        }
    }
    
    // 保存到 Core Data 数据库
    private func saveToDatabase(data: String) {
        let context = persistenceController.container.viewContext
        
        // ========== ⭐ 新增：检查并清理超出限制的历史记录 ==========
        cleanupOldRecordsIfNeeded(context: context)
        // =======================================================
        
        // 创建新的 Item 对象
        let newItem = Paste(context: context)
        newItem.data = data
        newItem.time = Date()
        
        // 保存到数据库
        do {
            try context.save()
            print("✅ 剪贴板内容已保存: \(data.prefix(50))...")
        } catch {
            print("❌ 保存失败: \(error.localizedDescription)")
        }
    }
    
    // ========== ⭐ 新增：清理旧记录的方法 ==========
    /// 检查记录数量，如果超过限制则删除最旧的记录
    private func cleanupOldRecordsIfNeeded(context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<Item> = Item.fetchRequest()
        
        do {
            let count = try context.count(for: fetchRequest)
            
            // 如果记录数已达到或超过限制，删除最旧的记录
            if count >= maxHistoryCount {
                let deleteCount = count - maxHistoryCount + 1  // 删除多少条以腾出空间
                
                // 获取最旧的记录
                fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Paste.time, ascending: true)]
                fetchRequest.fetchLimit = deleteCount
                
                let oldestItems = try context.fetch(fetchRequest)
                
                // 批量删除
                for item in oldestItems {
                    context.delete(item)
                }
                
                try context.save()
                print("🗑️ 已删除 \(deleteCount) 条最旧的记录（当前总数: \(count)）")
            }
        } catch {
            print("❌ 清理旧记录失败: \(error.localizedDescription)")
        }
    }
    // ==============================================
    
    // 获取所有保存的数据（用于测试）
    func fetchAllItems() -> [Item] {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<Item> = Item.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Paste.time, ascending: false)]
        
        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("❌ 获取数据失败: \(error.localizedDescription)")
            return []
        }
    }
    
    // ========== ⭐ 新增：获取当前记录数量 ==========
    /// 获取当前数据库中的记录总数
    func getCurrentCount() -> Int {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<Item> = Item.fetchRequest()
        
        do {
            return try context.count(for: fetchRequest)
        } catch {
            print("❌ 获取记录数失败: \(error.localizedDescription)")
            return 0
        }
    }
    // ==============================================
}
