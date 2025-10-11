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
    @Published var startDateTime: String
    @Published var catName: String
    
    // MARK: - Statistics
    @Published var totalPlayCount: Int
    @Published var totalFeedCount: Int
    @Published var totalCleanCount: Int
    
    // MARK: - Private Properties
    private var timer: Timer?
    private var aiTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let userDefaults = UserDefaults.standard
    private let aiAssistant: CatAIAssistant = DefaultCatAI()
    
    init() {
        // 初始化所有 @Published 属性
        let savedMood = userDefaults.double(forKey: CatConfig.StorageKeys.mood)
        self.mood = savedMood > 0 ? savedMood : CatConfig.GamePlay.initialMood
        
        let savedHunger = userDefaults.double(forKey: CatConfig.StorageKeys.hunger)
        self.hunger = savedHunger > 0 ? savedHunger : CatConfig.GamePlay.initialHunger
        
        let savedCleanliness = userDefaults.double(forKey: CatConfig.StorageKeys.cleanliness)
        self.cleanliness = savedCleanliness > 0 ? savedCleanliness : CatConfig.GamePlay.initialCleanliness
        
        // 加载存活状态
        if userDefaults.object(forKey: CatConfig.StorageKeys.isAlive) != nil {
            self.isAlive = userDefaults.bool(forKey: CatConfig.StorageKeys.isAlive)
        } else {
            self.isAlive = true
        }
        
        // 加载名字
        self.catName = userDefaults.string(forKey: CatConfig.StorageKeys.catName) ?? CatConfig.Info.name
        
        // 加载统计数据
        self.totalPlayCount = userDefaults.integer(forKey: CatConfig.StorageKeys.totalPlayCount)
        self.totalFeedCount = userDefaults.integer(forKey: CatConfig.StorageKeys.totalFeedCount)
        self.totalCleanCount = userDefaults.integer(forKey: CatConfig.StorageKeys.totalCleanCount)
        
        // 加载或创建开始时间
        if let savedDateTime = userDefaults.string(forKey: CatConfig.StorageKeys.startDateTime) {
            self.startDateTime = savedDateTime
        } else {
            self.startDateTime = Self.createStartTime()
            userDefaults.set(self.startDateTime, forKey: CatConfig.StorageKeys.startDateTime)
        }
        
        // 初始化完成后执行其他操作
        applyOfflinePenalty()
        checkLiveness()
        
        if isAlive {
            startTimer()
            startAITimer()
        }
        
        setupSubscribers()
    }
    
    // MARK: - Offline Penalty
    private func applyOfflinePenalty() {
        guard let lastDate = userDefaults.object(forKey: CatConfig.StorageKeys.lastSavedDate) as? Date else { return }
        
        let timePassed = Date().timeIntervalSince(lastDate)
        let intervalsPassed = Int(timePassed / CatConfig.GamePlay.decayInterval)
        
        if intervalsPassed > 0 {
            print("⏰ 离线了 \(intervalsPassed) 个周期")
            let totalPenalty = (1...intervalsPassed).reduce(0) { acc, _ in
                acc + Int.random(in: CatConfig.GamePlay.offlineDecayMin...CatConfig.GamePlay.offlineDecayMax)
            }
            
            DispatchQueue.main.async {
                self.mood = max(0, self.mood - Double(totalPenalty))
                self.hunger = max(0, self.hunger - Double(totalPenalty))
                self.cleanliness = max(0, self.cleanliness - Double(totalPenalty))
            }
        }
    }
    
    // MARK: - Notification System
    private func notifyIfLow(_ statName: String, value: Double, message: String) {
        guard value < CatConfig.Notification.lowValueThreshold else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "\(catName)需要你啦！"
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "low_\(statName)_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ 通知发送失败: \(error)")
            }
        }
    }
    
    // MARK: - AI Notification Timer
    private func startAITimer() {
        guard CatConfig.Notification.aiPushEnabled else { return }
        
        aiTimer?.invalidate()
        aiTimer = Timer.scheduledTimer(withTimeInterval: CatConfig.Notification.aiPushInterval, repeats: true) { [weak self] _ in
            self?.sendAIDailyMessage()
        }
    }
    
    private func sendAIDailyMessage() {
        guard aiAssistant.shouldSendNotification() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "\(catName)的日常"
        content.body = aiAssistant.generateDailyMessage()
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "ai_daily_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Data Persistence
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
    
    private func saveData() {
        userDefaults.set(mood, forKey: CatConfig.StorageKeys.mood)
        userDefaults.set(hunger, forKey: CatConfig.StorageKeys.hunger)
        userDefaults.set(cleanliness, forKey: CatConfig.StorageKeys.cleanliness)
        userDefaults.set(isAlive, forKey: CatConfig.StorageKeys.isAlive)
        userDefaults.set(Date(), forKey: CatConfig.StorageKeys.lastSavedDate)
        userDefaults.set(totalPlayCount, forKey: CatConfig.StorageKeys.totalPlayCount)
        userDefaults.set(totalFeedCount, forKey: CatConfig.StorageKeys.totalFeedCount)
        userDefaults.set(totalCleanCount, forKey: CatConfig.StorageKeys.totalCleanCount)
    }
    
    private static func createStartTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }
    
    func getLiveDays() -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        guard let startDate = formatter.date(from: startDateTime) else { return 1 }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startDate, to: Date())
        return (components.day ?? 0) + 1
    }
    
    // MARK: - Game Loop
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: CatConfig.GamePlay.decayInterval, repeats: true) { [weak self] _ in
            self?.reduceStats()
        }
    }
    
    func reduceStats() {
        guard isAlive else { return }
        
        DispatchQueue.main.async {
            let penalty1 = Double(Int.random(in: CatConfig.GamePlay.minDecayValue...CatConfig.GamePlay.maxDecayValue))
            let penalty2 = Double(Int.random(in: CatConfig.GamePlay.minDecayValue...CatConfig.GamePlay.maxDecayValue))
            let penalty3 = Double(Int.random(in: CatConfig.GamePlay.minDecayValue...CatConfig.GamePlay.maxDecayValue))
            
            self.mood = max(0, self.mood - penalty1)
            self.hunger = max(0, self.hunger - penalty2)
            self.cleanliness = max(0, self.cleanliness - penalty3)
            
            // 发送低属性通知
            self.notifyIfLow("mood", value: self.mood, message: CatConfig.Notification.lowMoodMessage)
            self.notifyIfLow("hunger", value: self.hunger, message: CatConfig.Notification.lowHungerMessage)
            self.notifyIfLow("cleanliness", value: self.cleanliness, message: CatConfig.Notification.lowCleanlinessMessage)
            
            self.checkLiveness()
            print("📉 属性衰减: 心情-\(Int(penalty1)) 饥饿-\(Int(penalty2)) 清洁-\(Int(penalty3))")
        }
    }
    
    func checkLiveness() {
        let zeroStatsCount = [mood, hunger, cleanliness].filter { $0 == 0 }.count
        if zeroStatsCount >= CatConfig.GamePlay.deathThreshold {
            isAlive = false
            timer?.invalidate()
            aiTimer?.invalidate()
        }
    }
    
    // MARK: - User Actions
    func play() {
        guard isAlive else { return }
        withAnimation(.spring(response: CatConfig.UI.springResponse, dampingFraction: CatConfig.UI.springDamping)) {
            mood = min(100, mood + CatConfig.GamePlay.playIncrement)
            totalPlayCount += 1
        }
    }
    
    func feed() {
        guard isAlive else { return }
        withAnimation(.spring(response: CatConfig.UI.springResponse, dampingFraction: CatConfig.UI.springDamping)) {
            hunger = min(100, hunger + CatConfig.GamePlay.feedIncrement)
            totalFeedCount += 1
        }
    }
    
    func clean() {
        guard isAlive else { return }
        withAnimation(.spring(response: CatConfig.UI.springResponse, dampingFraction: CatConfig.UI.springDamping)) {
            cleanliness = min(100, cleanliness + CatConfig.GamePlay.cleanIncrement)
            totalCleanCount += 1
        }
    }
    
    func restart() {
        mood = CatConfig.GamePlay.initialMood
        hunger = CatConfig.GamePlay.initialHunger
        cleanliness = CatConfig.GamePlay.initialCleanliness
        isAlive = true
        startDateTime = Self.createStartTime()
        userDefaults.set(startDateTime, forKey: CatConfig.StorageKeys.startDateTime)
        
        totalPlayCount = 0
        totalFeedCount = 0
        totalCleanCount = 0
        
        startTimer()
        startAITimer()
        saveData()
    }
    
    func updateCatName(_ newName: String) {
        catName = newName
        CatConfig.Info.updateName(newName)
        userDefaults.set(newName, forKey: CatConfig.StorageKeys.catName)
    }
}
