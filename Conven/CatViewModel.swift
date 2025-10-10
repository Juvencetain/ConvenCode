import Foundation
import SwiftUI

// 使用 ObservableObject，这样 SwiftUI 视图才能监视其变化
class CatViewModel: ObservableObject {
    
    // @Published 会在属性值改变时自动通知所有观察者（即我们的UI）
    @Published var mood: Double = 100.0
    @Published var hunger: Double = 100.0
    @Published var cleanliness: Double = 100.0
    @Published var isAlive: Bool = true
    
    private var timer: Timer?

    init() {
        // 启动一个定时器，每 30 分钟（1800秒）调用一次 reduceStats 方法
        // 为了方便测试，你可以暂时设置为一个较短的时间，比如 10 秒
        timer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { _ in
            self.reduceStats()
        }
    }
    
    // 降低数值的函数
    func reduceStats() {
        guard isAlive else { return } // 如果猫死了，就停止
        
        // SwiftUI 会在主线程更新UI，所以我们在这里确保数值更新也在主线程
        DispatchQueue.main.async {
            // 每次减 1，并确保不会低于 0
            self.mood = max(0, self.mood - 1)
            self.hunger = max(0, self.hunger - 1)
            self.cleanliness = max(0, self.cleanliness - 1)
            
            self.checkLiveness()
        }
    }
    
    // 检查小猫的存活状态
    func checkLiveness() {
        let zeroStatsCount = [mood, hunger, cleanliness].filter { $0 == 0 }.count
        if zeroStatsCount >= 2 {
            isAlive = false
            timer?.invalidate() // 猫死了，停止定时器
        }
    }
    
    // MARK: - User Actions
    
    func play() {
        guard isAlive else { return }
        mood = min(100, mood + 15) // 增加心情，但不超过100
    }
    
    func feed() {
        guard isAlive else { return }
        hunger = min(100, hunger + 15) // 增加饥饿度
    }
    
    func clean() {
        guard isAlive else { return }
        cleanliness = min(100, cleanliness + 15) // 增加清洁度
    }
    
    // 重置游戏
    func restart() {
        mood = 100
        hunger = 100
        cleanliness = 100
        isAlive = true
        // 重新启动定时器
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { _ in
            self.reduceStats()
        }
    }
}