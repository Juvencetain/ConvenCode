import Foundation
import Combine

// MARK: - 金币记录管理器
class CoinHistoryManager: ObservableObject {
    static let shared = CoinHistoryManager()
    
    @Published var records: [CoinRecord] = []
    @Published var hourlyIncome: [HourlyIncomeRecord] = []
    @Published var currentHourIncome: Double = 0  // 改为 @Published 属性
    
    private let maxRecords = 500
    private let recordsKey = "coin_history_records"
    private let hourlyKey = "coin_hourly_income"
    
    private var lastHourlyUpdate: Date?
    
    private init() {
        loadRecords()
        setupHourlyTimer()
    }
    
    // MARK: - 保存和加载
    
    private func saveRecords() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            // 限制记录数量
            let recordsToSave = Array(self.records.prefix(self.maxRecords))
            
            if let encoded = try? JSONEncoder().encode(recordsToSave) {
                UserDefaults.standard.set(encoded, forKey: self.recordsKey)
            }
            
            if let hourlyEncoded = try? JSONEncoder().encode(self.hourlyIncome) {
                UserDefaults.standard.set(hourlyEncoded, forKey: self.hourlyKey)
            }
        }
    }
    
    private func loadRecords() {
        if let data = UserDefaults.standard.data(forKey: recordsKey),
           let decoded = try? JSONDecoder().decode([CoinRecord].self, from: data) {
            records = decoded
        }
        
        if let hourlyData = UserDefaults.standard.data(forKey: hourlyKey),
           let hourlyDecoded = try? JSONDecoder().decode([HourlyIncomeRecord].self, from: hourlyData) {
            hourlyIncome = hourlyDecoded
        }
    }
    
    // MARK: - 添加记录
    
    /// 添加收入记录（每秒自动增长）
    func addIncomeRecord(amount: Double, balance: Double) {
        currentHourIncome += amount
        // 不立即创建记录，等待每小时汇总
    }
    
    /// 添加支出记录（购买物品）
    func addExpenseRecord(amount: Double, balance: Double, item: String) {
        let record = CoinRecord(
            type: .expense,
            amount: amount,
            balance: balance,
            description: "购买\(item)"
        )
        addRecord(record)
    }
    
    /// 添加奖励记录（使用工具）
    func addRewardRecord(amount: Double, balance: Double, toolName: String) {
        let record = CoinRecord(
            type: .reward,
            amount: amount,
            balance: balance,
            description: "使用\(toolName)获得奖励"
        )
        addRecord(record)
    }
    
    private func addRecord(_ record: CoinRecord) {
        DispatchQueue.main.async {
            self.records.insert(record, at: 0)
            
            // 限制记录数量
            if self.records.count > self.maxRecords {
                self.records = Array(self.records.prefix(self.maxRecords))
            }
            
            self.saveRecords()
        }
    }
    
    // MARK: - 每小时汇总
    
    private func setupHourlyTimer() {
        // 计算到下一个整点的时间
        let now = Date()
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour], from: now)
        components.hour! += 1
        components.minute = 0
        components.second = 0
        
        guard let nextHour = calendar.date(from: components) else { return }
        let timeInterval = nextHour.timeIntervalSince(now)
        
        // 先等待到下一个整点
        DispatchQueue.main.asyncAfter(deadline: .now() + timeInterval) { [weak self] in
            self?.updateHourlySummary()
            
            // 然后每小时执行一次
            Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
                self?.updateHourlySummary()
            }
        }
    }
    
    private func updateHourlySummary() {
        guard currentHourIncome > 0 else { return }
        
        DispatchQueue.main.async {
            let now = Date()
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day, .hour], from: now)
            components.minute = 0
            components.second = 0
            
            guard let hourTime = calendar.date(from: components) else { return }
            
            let hourlyRecord = HourlyIncomeRecord(
                hour: hourTime,
                totalIncome: self.currentHourIncome
            )
            
            self.hourlyIncome.insert(hourlyRecord, at: 0)
            
            // 限制每小时记录数量（保留最近100条）
            if self.hourlyIncome.count > 100 {
                self.hourlyIncome = Array(self.hourlyIncome.prefix(100))
            }
            
            // 重置当前小时收入
            self.currentHourIncome = 0
            
            self.saveRecords()
            
            print("✅ 金币每小时汇总已更新: +\(String(format: "%.3f", hourlyRecord.totalIncome))")
        }
    }
    
    // MARK: - 获取记录
    
    /// 获取当前小时已累积的收入（实时显示用）
    func getCurrentHourIncome() -> Double {
        return currentHourIncome
    }
    
    /// 获取最近的操作记录（不包括每小时收入）
    func getRecentRecords(limit: Int = 20) -> [CoinRecord] {
        return Array(records.prefix(limit))
    }
    
    /// 获取最近的每小时收入记录
    func getRecentHourlyIncome(limit: Int = 10) -> [HourlyIncomeRecord] {
        return Array(hourlyIncome.prefix(limit))
    }
    
    /// 清除所有记录
    func clearAll() {
        records.removeAll()
        hourlyIncome.removeAll()
        currentHourIncome = 0
        saveRecords()
    }
}
