//
//  CatAIScheduleService.swift
//  Conven
//
//  Created by 土豆星球 on 2025/10/14.
//


import Foundation
import UserNotifications

class CatAIScheduleService {
    static let shared = CatAIScheduleService()
    
    private let apiURL = "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
    private let apiKey = "sk-888be32f3ecb43c5b17c5ae4812dc171"
    
    private let storageKey = "cat_daily_schedule"
    private var currentSchedule: DailySchedule?
    
    // 标记是否正在请求，避免重复请求
    private var isFetching = false
    
    private init() {
        loadSchedule()
        setupDailyRefresh()
    }
    
    // MARK: - 加载和保存
    
    private func loadSchedule() {
        let today = getTodayDateString()
        
        // 从 UserDefaults 加载
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let schedule = try? JSONDecoder().decode(DailySchedule.self, from: data) {
            
            if schedule.date == today {
                // 是今天的日程，直接使用
                currentSchedule = schedule
                print("✅ 加载今日日程: \(schedule.events.count) 个事件")
                scheduleNotifications()
                return
            } else {
                print("📅 日期已变化，需要生成新日程")
            }
        }
        
        // 没有今天的日程，获取新日程
        fetchTodaySchedule()
    }
    
    private func saveSchedule(_ schedule: DailySchedule) {
        if let data = try? JSONEncoder().encode(schedule) {
            UserDefaults.standard.set(data, forKey: storageKey)
            print("💾 日程已保存")
        }
    }
    
    // MARK: - 获取AI日程（确保每天只请求一次）
    
    func fetchTodaySchedule() {
        // 防止重复请求
        guard !isFetching else {
            print("⚠️ 正在请求中，跳过重复请求")
            return
        }
        
        let today = getTodayDateString()
        
        // 检查是否已有今天的日程
        if let schedule = currentSchedule, schedule.date == today {
            print("✅ 今日日程已存在，无需重复请求")
            return
        }
        
        isFetching = true
        
        let request = AIRequest(
            model: "qwen-plus",
            messages: [
                AIMessage(role: "system", content: "You are a helpful assistant."),
                AIMessage(
                    role: "user",
                    content: "请你观察小猫有趣、搞笑的活动，注意时间顺序，从早上7点到晚上9点（自由大胆的发挥，小猫可以自己工作、做各种有趣的事情，这是一个奇妙的世界）。格式严格按照：数字. 时:分，描述。例如：1. 7:00，小猫起床伸懒腰。至少10个事件，每条不超过50字。"
                )
            ]
        )
        
        guard let url = URL(string: apiURL),
              let requestData = try? JSONEncoder().encode(request) else {
            print("❌ 请求构建失败")
            isFetching = false
            return
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = requestData
        
        print("🚀 正在请求AI生成今日日程...")
        
        URLSession.shared.dataTask(with: urlRequest) { [weak self] data, response, error in
            guard let self = self else { return }
            
            defer {
                self.isFetching = false
            }
            
            if let error = error {
                print("❌ 网络请求失败: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("❌ 未收到数据")
                return
            }
            
            do {
                let aiResponse = try JSONDecoder().decode(AIResponse.self, from: data)
                guard let content = aiResponse.choices.first?.message.content else {
                    print("❌ AI响应为空")
                    return
                }
                
                print("✅ AI日程生成成功")
                print("📄 原始内容:\n\(content)")
                self.parseAndSaveSchedule(content: content)
            } catch {
                print("❌ 解析响应失败: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("响应内容: \(jsonString)")
                }
            }
        }.resume()
    }
    
    private func parseAndSaveSchedule(content: String) {
        let lines = content.components(separatedBy: .newlines)
        var events: [CatScheduleEvent] = []
        
        for line in lines {
            // 匹配格式: "1. 7:00，小猫..." 或 "7:00，小猫..."
            let pattern = #"(\d{1,2}):(\d{2})[，,]\s*(.+)"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                
                if let hourRange = Range(match.range(at: 1), in: line),
                   let minuteRange = Range(match.range(at: 2), in: line),
                   let descRange = Range(match.range(at: 3), in: line) {
                    
                    let hour = String(line[hourRange])
                    let minute = String(line[minuteRange])
                    let description = String(line[descRange]).trimmingCharacters(in: .whitespaces)
                    
                    let timeString = String(format: "%02d:%02d", Int(hour) ?? 0, Int(minute) ?? 0)
                    let event = CatScheduleEvent(time: timeString, description: description)
                    events.append(event)
                    print("📝 解析事件: \(timeString) - \(description)")
                }
            }
        }
        
        if events.isEmpty {
            print("⚠️ 未能解析任何事件")
            return
        }
        
        // 按时间排序
        let sortedEvents = events.sorted { event1, event2 in
            if event1.hour != event2.hour {
                return event1.hour < event2.hour
            }
            return event1.minute < event2.minute
        }
        
        let schedule = DailySchedule(
            date: getTodayDateString(),
            events: sortedEvents,
            rawContent: content
        )
        
        DispatchQueue.main.async {
            self.currentSchedule = schedule
            self.saveSchedule(schedule)
            self.scheduleNotifications()
            
            // 通知UI更新
            NotificationCenter.default.post(name: .catScheduleUpdated, object: schedule)
        }
    }
    
    // MARK: - 通知调度（按AI返回的时间）
    
    private func scheduleNotifications() {
        guard let schedule = currentSchedule else { return }
        
        let center = UNUserNotificationCenter.current()
        let now = Date()
        let calendar = Calendar.current
        
        // 清除旧的AI日程通知
        center.getPendingNotificationRequests { requests in
            let identifiers = requests.filter { $0.identifier.hasPrefix("ai_schedule_") }.map { $0.identifier }
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
            print("🧹 清除了 \(identifiers.count) 个旧的AI日程通知")
        }
        
        var scheduledCount = 0
        
        for event in schedule.events where !event.isNotified {
            let eventTime = event.getTodayTimestamp()
            
            // 只注册未来的通知
            if eventTime > now {
                var dateComponents = DateComponents()
                dateComponents.hour = event.hour
                dateComponents.minute = event.minute
                
                let content = UNMutableNotificationContent()
                content.title = "🐱 小猫现在在做什么？"
                content.body = event.description
                content.sound = .default
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
                let identifier = "ai_schedule_\(event.id.uuidString)"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                
                center.add(request) { error in
                    if let error = error {
                        print("❌ 注册通知失败: \(error.localizedDescription)")
                    } else {
                        print("✅ 注册通知: \(event.time) - \(event.description)")
                    }
                }
                
                scheduledCount += 1
            } else {
                print("⏭️ 跳过已过时间: \(event.time)")
            }
        }
        
        print("⏰ 共注册 \(scheduledCount) 个通知")
    }
    
    func markEventAsNotified(eventId: UUID) {
        guard var schedule = currentSchedule else { return }
        
        if let index = schedule.events.firstIndex(where: { $0.id == eventId }) {
            schedule.events[index].isNotified = true
            currentSchedule = schedule
            saveSchedule(schedule)
            print("✅ 事件已标记为已通知: \(schedule.events[index].time)")
        }
    }
    
    // MARK: - 每日刷新
    
    private func setupDailyRefresh() {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        components.hour = 0
        components.minute = 1
        
        guard let nextRefreshDate = calendar.date(from: components) else { return }
        let timeInterval = nextRefreshDate.timeIntervalSince(Date())
        
        Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            print("🌅 新的一天开始，刷新日程")
            self?.fetchTodaySchedule()
            self?.setupDailyRefresh()
        }
        
        print("⏰ 已设置明日刷新: \(nextRefreshDate)")
    }
    
    // MARK: - 辅助方法
    
    private func getTodayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    func getCurrentSchedule() -> DailySchedule? {
        return currentSchedule
    }
    
    func refreshSchedule() {
        // 手动刷新：清空当前日程，重新请求
        currentSchedule = nil
        fetchTodaySchedule()
    }
}

extension Notification.Name {
    static let catScheduleUpdated = Notification.Name("catScheduleUpdated")
}