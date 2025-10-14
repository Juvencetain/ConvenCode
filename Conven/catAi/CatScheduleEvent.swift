//
//  CatScheduleEvent.swift
//  Conven
//
//  Created by 土豆星球 on 2025/10/14.
//


import Foundation

// MARK: - 小猫日程事件
struct CatScheduleEvent: Codable, Identifiable {
    let id: UUID
    let time: String // "07:00"
    let hour: Int
    let minute: Int
    let description: String
    var isNotified: Bool
    
    init(time: String, description: String) {
        self.id = UUID()
        self.time = time
        self.description = description
        self.isNotified = false
        
        // 解析时间
        let components = time.split(separator: ":").map { Int($0) ?? 0 }
        self.hour = components[0]
        self.minute = components.count > 1 ? components[1] : 0
    }
    
    // 获取今天这个时间的完整时间戳
    func getTodayTimestamp() -> Date {
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        dateComponents.hour = hour
        dateComponents.minute = minute
        return calendar.date(from: dateComponents) ?? Date()
    }
}

// MARK: - 每日日程
struct DailySchedule: Codable {
    let date: String // "2025-10-14"
    var events: [CatScheduleEvent]
    let rawContent: String
}

// MARK: - AI API 模型
struct AIRequest: Codable {
    let model: String
    let messages: [AIMessage]
}

struct AIMessage: Codable {
    let role: String
    let content: String
}

struct AIResponse: Codable {
    let choices: [AIChoice]
}

struct AIChoice: Codable {
    let message: AIMessage
}
