import Foundation
import AppKit
import CoreData

class ClipboardMonitor {
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let persistenceController: PersistenceController
    
    // 配置常量
    private let maxStringLength: Int = 3000  // 最大字符串长度
    private let maxHistoryCount: Int = 1000   // 最大历史记录数
    private let duplicateCheckCount: Int = 20 // 检查最近多少条记录是否重复
    
    // 上次保存的内容
    private var lastSavedContent: String?
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        self.lastChangeCount = NSPasteboard.general.changeCount
    }
    
    // 开始监控剪贴板
    func startMonitoring() {
        // 每 10 秒检查一次剪贴板
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
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
                // 跳过空内容
                if clipboardString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    print("⚠️ 剪贴板内容为空，跳过保存")
                    return
                }
                
                // 检查长度
                if clipboardString.count > maxStringLength {
                    print("⚠️ 剪贴板内容过长 (\(clipboardString.count) 字符)，已跳过保存")
                    return
                }
                
                // 检查是否与上次保存的内容相同
                if clipboardString == lastSavedContent {
                    print("⚠️ 剪贴板内容与上次保存相同，跳过保存")
                    return
                }
                
                // 检查是否在历史记录中已存在
                if isContentAlreadySaved(clipboardString) {
                    print("⚠️ 剪贴板内容已在历史记录中存在，跳过保存")
                    return
                }
                
                // 保存内容并更新上次保存的内容
                saveToDatabase(data: clipboardString)
                lastSavedContent = clipboardString
            }
        }
    }
    
    // 检查内容是否已在历史记录中存在
    private func isContentAlreadySaved(_ content: String) -> Bool {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<Paste> = Paste.fetchRequest()
        
        // 只检查最近的记录，避免全表扫描
        fetchRequest.predicate = NSPredicate(format: "data == %@", content)
        fetchRequest.fetchLimit = duplicateCheckCount
        
        do {
            let existingItems = try context.fetch(fetchRequest)
            return !existingItems.isEmpty
        } catch {
            print("❌ 检查重复内容失败: \(error.localizedDescription)")
            return false
        }
    }
    
    // 保存到 Core Data 数据库
    private func saveToDatabase(data: String) {
        let context = persistenceController.container.viewContext
        
        // 创建新的 Item 对象
        let newItem = Paste(context: context)
        newItem.data = data
        newItem.time = Date()
        
        // 保存到数据库
        do {
            try context.save()
            print("✅ 剪贴板内容已保存: \(data.prefix(50))...")
            
            // 保存后立即清理旧记录
            cleanupOldRecordsIfNeeded(context: context)
        } catch {
            print("❌ 保存失败: \(error.localizedDescription)")
        }
    }
    
    /// 检查记录数量，如果超过限制则删除最旧的记录
    private func cleanupOldRecordsIfNeeded(context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<Paste> = Paste.fetchRequest()
        
        do {
            let count = try context.count(for: fetchRequest)
            print("当前记录数: \(count), 最大允许记录数: \(maxHistoryCount)")
            
            // 如果记录数已达到或超过限制，删除最旧的记录
            if count > maxHistoryCount {
                let deleteCount = count - maxHistoryCount
                print("需要删除的记录数: \(deleteCount)")
                
                // 获取最旧的记录
                fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Paste.time, ascending: true)]
                fetchRequest.fetchLimit = deleteCount
                
                let oldestItems = try context.fetch(fetchRequest)
                print("找到要删除的最旧记录数: \(oldestItems.count)")
                
                // 批量删除
                for item in oldestItems {
                    context.delete(item)
                }
                
                try context.save()
                print("🗑️ 已删除 \(deleteCount) 条最旧的记录（删除后记录总数应为: \(count - deleteCount)）")
            }
        } catch {
            print("❌ 清理旧记录失败: \(error.localizedDescription)")
        }
    }
    
    // 获取所有保存的数据（用于测试）
    func fetchAllItems() -> [Paste] {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<Paste> = Paste.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Paste.time, ascending: false)]
        
        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("❌ 获取数据失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 获取当前数据库中的记录总数
    func getCurrentCount() -> Int {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<Paste> = Paste.fetchRequest()
        
        do {
            return try context.count(for: fetchRequest)
        } catch {
            print("❌ 获取记录数失败: \(error.localizedDescription)")
            return 0
        }
    }
}
