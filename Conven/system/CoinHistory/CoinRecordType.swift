//
//  CoinRecordType.swift
//  Conven
//
//  Created by 土豆星球 on 2025/10/19.
//


import Foundation

// MARK: - 金币记录类型
enum CoinRecordType: String, Codable {
    case income = "收入"      // 每秒自动增长
    case expense = "支出"     // 购买猫粮、玩具、猫砂
    case reward = "奖励"      // 使用工具获得的奖励
    
    var icon: String {
        switch self {
        case .income: return "arrow.down.circle.fill"
        case .expense: return "arrow.up.circle.fill"
        case .reward: return "gift.fill"
        }
    }
    
    var color: String {
        switch self {
        case .income: return "green"
        case .expense: return "red"
        case .reward: return "yellow"
        }
    }
}

// MARK: - 金币记录模型
struct CoinRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let type: CoinRecordType
    let amount: Double
    let balance: Double  // 记录操作后的余额
    let description: String
    
    init(type: CoinRecordType, amount: Double, balance: Double, description: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.type = type
        self.amount = amount
        self.balance = balance
        self.description = description
    }
    
    var formattedAmount: String {
        let prefix = type == .expense ? "-" : "+"
        return String(format: "%@%.3f", prefix, amount)
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: timestamp)
    }
}

// MARK: - 每小时汇总记录
struct HourlyIncomeRecord: Identifiable, Codable {
    let id: UUID
    let hour: Date  // 整点时间
    var totalIncome: Double
    var recordCount: Int
    
    init(hour: Date, totalIncome: Double, recordCount: Int = 1) {
        self.id = UUID()
        self.hour = hour
        self.totalIncome = totalIncome
        self.recordCount = recordCount
    }
    
    var formattedHour: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:00"
        return formatter.string(from: hour)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:00"
        return formatter.string(from: hour)
    }
}