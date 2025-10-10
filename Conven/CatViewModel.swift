import Combine
import Foundation
import SwiftUI

class CatViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var mood: Double
    @Published var hunger: Double
    @Published var cleanliness: Double
    @Published var isAlive: Bool
    
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
    }

    init() {
        self.mood = userDefaults.object(forKey: Keys.mood) as? Double ?? 100.0
        self.hunger = userDefaults.object(forKey: Keys.hunger) as? Double ?? 100.0
        self.cleanliness = userDefaults.object(forKey: Keys.cleanliness) as? Double ?? 100.0
        self.isAlive = userDefaults.object(forKey: Keys.isAlive) as? Bool ?? true
        
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
        let minutesPassed = Int(timePassed / 60) // 离线多少分钟
        
        if minutesPassed > 0 {
            print("离线了 \(minutesPassed) 分钟")
            let totalPenalty = (1...minutesPassed).reduce(0) { acc, _ in
                acc + Int.random(in: 1...5)
            }
            DispatchQueue.main.async {
                self.mood = max(0, self.mood - Double(totalPenalty))
                self.hunger = max(0, self.hunger - Double(totalPenalty))
                self.cleanliness = max(0, self.cleanliness - Double(totalPenalty))
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

    // 每分钟执行一次
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            self.reduceStats()
        }
    }
    
    // 每分钟减少 1-5 点
    func reduceStats() {
        guard isAlive else { return }
        
        DispatchQueue.main.async {
            let penalty1 = Double(Int.random(in: 1...5))
            let penalty2 = Double(Int.random(in: 1...5))
            let penalty3 = Double(Int.random(in: 1...5))
            self.mood = max(0, self.mood - penalty1)
            self.hunger = max(0, self.hunger - penalty2)
            self.cleanliness = max(0, self.cleanliness - penalty3)
            self.checkLiveness()
            print("每分钟状态减少 \(Int(penalty1))、\(Int(penalty2))、\(Int(penalty3)) 点")
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
    }
    
}
