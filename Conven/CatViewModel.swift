import Combine
import Foundation
import SwiftUI
import UserNotifications

class CatViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var mood: Double
    @Published var hunger: Double
    @Published var cleanliness: Double
    @Published var isAlive: Bool
    @Published var liveDays: String
    
    // MARK: - Private Properties
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let userDefaults = UserDefaults.standard
    
    // 用于存储数据的 Key
    private enum Keys {
        static let mood = "cat_mood"
        static let hunger = "cat_hunger"
        static let cleanliness = "cat_cleanliness"
        static let isAlive = "cat_isAlive"
        static let lastSavedDate = "cat_lastSavedDate"
        static let liveDays = "cat_liveDays"
    }
    
    init() {
        
        self.mood = userDefaults.object(forKey: Keys.mood) as? Double ?? 100.0
        self.hunger = userDefaults.object(forKey: Keys.hunger) as? Double ?? 100.0
        self.cleanliness = userDefaults.object(forKey: Keys.cleanliness) as? Double ?? 100.0
        self.isAlive = userDefaults.object(forKey: Keys.isAlive) as? Bool ?? true
        
        // 尝试从 UserDefaults 获取 liveDays
        if let savedLiveDays = userDefaults.string(forKey: Keys.liveDays) {
            // 如果有值，直接使用
            self.liveDays = savedLiveDays
        } else {
            // 如果为空，保存当前时间，并重新赋值
            self.liveDays = Self.saveStartTime(userDefaults: userDefaults)
        }
        
        applyOfflinePenalty()
        checkLiveness()
        
        if isAlive {
            startTimer()
        }
        
        setupSubscribers()
    }
    
    // 计算离线惩罚
    private func applyOfflinePenalty() {
        guard let lastDate = userDefaults.object(forKey: Keys.lastSavedDate) as? Date else { return }
        
        let timePassed = Date().timeIntervalSince(lastDate)
        let tenMinutesPassed = Int(timePassed / 600) // 离线多少个 10 分钟
        
        if tenMinutesPassed > 0 {
            print("离线了 \(tenMinutesPassed) 个 10 分钟")
            let totalPenalty = (1...tenMinutesPassed).reduce(0) { acc, _ in
                acc + Int.random(in: 1...5)
            }
            DispatchQueue.main.async {
                self.mood = max(0, self.mood - Double(totalPenalty))
                self.hunger = max(0, self.hunger - Double(totalPenalty))
                self.cleanliness = max(0, self.cleanliness - Double(totalPenalty))
            }
        }
    }
    
    private func notifyIfLow(_ name: String, value: Double) {
        guard value < 20 else { return }  // 阈值 < 20 时才通知
        
        let content = UNMutableNotificationContent()
        content.title = "小猫提醒"
        content.body = "\(name) 太低啦！快去照顾一下它吧 🐱"
        content.sound = .default
        
        // 立即触发
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ 通知发送失败: \(error)")
            }
        }
    }
    
    
    // 订阅状态变化以自动保存
    private func setupSubscribers() {
        Publishers.CombineLatest3($mood, $hunger, $cleanliness)
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.saveData() }
            .store(in: &cancellables)
        
        $isAlive
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.saveData() }
            .store(in: &cancellables)
    }
    
    // 保存数据
    private func saveData() {
        userDefaults.set(mood, forKey: Keys.mood)
        userDefaults.set(hunger, forKey: Keys.hunger)
        userDefaults.set(cleanliness, forKey: Keys.cleanliness)
        userDefaults.set(isAlive, forKey: Keys.isAlive)
        userDefaults.set(Date(), forKey: Keys.lastSavedDate)
    }
    
    //保存开始时间用来计算存活时长
    private static func saveStartTime(userDefaults: UserDefaults) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let currentStartTime = formatter.string(from: Date())
        userDefaults.set(currentStartTime, forKey: Keys.liveDays)
        return currentStartTime
    }
    
    func getLiveDays() -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        // 安全解包 startDateTime
        if let startDateTime = formatter.date(from: self.liveDays) {
            let calendar = Calendar.current
            let now = Date()
            let components = calendar.dateComponents([.day], from: startDateTime, to: now)
            return components.day ?? 0
        } else {
            // 如果解析失败，返回0天
            return 0
        }
    }
    
    // 每分钟执行一次
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { _ in
            self.reduceStats()
        }
    }
    
    // 每分钟减少 1-5 点
    func reduceStats() {
        guard isAlive else { return }
        
        DispatchQueue.main.async {
            let penalty1 = Double(Int.random(in: 1...3))
            let penalty2 = Double(Int.random(in: 1...3))
            let penalty3 = Double(Int.random(in: 1...3))
            self.mood = max(0, self.mood - penalty1)
            self.hunger = max(0, self.hunger - penalty2)
            self.cleanliness = max(0, self.cleanliness - penalty3)
            
            // 检查是否需要通知
            self.notifyIfLow("心情", value: self.mood)
            self.notifyIfLow("饥饿", value: self.hunger)
            self.notifyIfLow("清洁", value: self.cleanliness)
            
            self.checkLiveness()
            print("每10分钟状态减少 \(Int(penalty1))、\(Int(penalty2))、\(Int(penalty3)) 点")
        }
    }
    
    func checkLiveness() {
        let zeroStatsCount = [mood, hunger, cleanliness].filter { $0 == 0 }.count
        if zeroStatsCount >= 2 {
            isAlive = false
            timer?.invalidate()
        }
    }
    
    // MARK: - User Actions
    func play() {
        guard isAlive else { return }
        mood = min(100, mood + 15)
    }
    
    func feed() {
        guard isAlive else { return }
        hunger = min(100, hunger + 15)
    }
    
    func clean() {
        guard isAlive else { return }
        cleanliness = min(100, cleanliness + 15)
    }
    
    func restart() {
        mood = 100
        hunger = 100
        cleanliness = 100
        isAlive = true
        startTimer()
        saveData()
        self.liveDays = Self.saveStartTime(userDefaults: userDefaults)
    }
    
}
