import Foundation
import AppKit
import CoreData

class ClipboardMonitor {
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let persistenceController: PersistenceController
    
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
                saveToDatabase(data: clipboardString)
            }
        }
    }
    
    // 保存到 Core Data 数据库
    private func saveToDatabase(data: String) {
        let context = persistenceController.container.viewContext
        
        // 创建新的 Item 对象
        let newItem = Item(context: context)
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
    
    // 获取所有保存的数据（用于测试）
    func fetchAllItems() -> [Item] {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<Item> = Item.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Item.time, ascending: false)]
        
        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("❌ 获取数据失败: \(error.localizedDescription)")
            return []
        }
    }
}