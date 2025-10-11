//
//  CatConfig.swift
//  Conven
//
//  Created by 土豆星球 on 2025/10/11.
//

import Foundation

// MARK: - 小猫配置中心
struct CatConfig {
    
    // MARK: - 基础信息配置
    struct Info {
        static var name: String = "小喵"
        static var emoji: String = "🐱"
        static var breed: String = "橘猫"
        static var birthDate: Date = Date()
        
        // 头像配置
        static var avatarEmoji: String {
            get {
                return UserDefaults.standard.string(forKey: StorageKeys.avatarEmoji) ?? "🐱"
            }
            set {
                UserDefaults.standard.set(newValue, forKey: StorageKeys.avatarEmoji)
            }
        }
        
        // 预设头像列表
        static let availableAvatars: [AvatarCategory] = [
            AvatarCategory(name: "猫咪", emojis: [
                "🐱", "😺", "😸", "😹", "😻", "😼", "😽", "🙀", "😿", "😾", "🐈", "🐈‍⬛"
            ]),
            AvatarCategory(name: "动物", emojis: [
                "🦁", "🐯", "🐅", "🐆", "🐴", "🦄", "🦊", "🐶", "🐺", "🐼", "🐨", "🐻",
                "🐻‍❄️", "🐰", "🐹", "🐭", "🐷", "🐮", "🐸", "🐵", "🦧", "🦍"
            ]),
            AvatarCategory(name: "表情", emojis: [
                "😀", "😃", "😄", "😁", "😊", "🥰", "😍", "🤩", "😎", "🤓", "🥳", "😇"
            ]),
            AvatarCategory(name: "其他", emojis: [
                "🌟", "⭐️", "✨", "💫", "🌈", "🎨", "🎭", "🎪", "🎯", "🎮", "🎲", "🎵"
            ])
        ]
        
        // 可在设置中修改
        static func updateName(_ newName: String) {
            name = newName
            UserDefaults.standard.set(newName, forKey: "cat_name")
        }
        
        static func updateAvatar(_ newEmoji: String) {
            avatarEmoji = newEmoji
        }
    }
    
    // MARK: - 头像分类
    struct AvatarCategory {
        let name: String
        let emojis: [String]
    }
    
    // MARK: - 游戏参数配置
    struct GamePlay {
        // 初始属性值
        static let initialMood: Double = 100.0
        static let initialHunger: Double = 100.0
        static let initialCleanliness: Double = 100.0
        
        // 每次操作增加的值
        static let playIncrement: Double = 15.0
        static let feedIncrement: Double = 15.0
        static let cleanIncrement: Double = 15.0
        
        // 时间衰减设置
        static let decayInterval: TimeInterval = 600 // 10分钟
        static let minDecayValue: Int = 1
        static let maxDecayValue: Int = 3
        
        // 离线惩罚
        static let offlineDecayMin: Int = 1
        static let offlineDecayMax: Int = 5
        
        // 死亡条件：至少1个属性为0
        static let deathThreshold: Int = 1
    }
    
    // MARK: - 通知配置
    struct Notification {
        // 低属性值通知阈值
        static let lowValueThreshold: Double = 20.0
        
        // 通知文案
        static let lowMoodMessage: String = "心情太低啦！快来陪我玩玩吧 🎮"
        static let lowHungerMessage: String = "肚子好饿呀！该吃饭啦 🍖"
        static let lowCleanlinessMessage: String = "好脏呀！需要洗澡澡了 🛁"
        
        // AI推送配置
        static var aiPushEnabled: Bool = true
        static var aiPushInterval: TimeInterval = 3600 // 1小时
        static let aiPushTime: [String] = ["09:00", "12:00", "18:00", "21:00"]
        
        // AI推送文案模板（后续可接入真实AI）
        static let aiDailyMessages: [String] = [
            "早上好呀！今天也要元气满满哦~ ☀️",
            "中午啦，记得吃午饭哦！我也要吃小鱼干~ 🐟",
            "下午茶时间到！要不要一起休息一下？ ☕️",
            "晚上好！今天过得怎么样呀？ 🌙",
            "该睡觉啦！晚安，做个好梦~ 😴",
            "好久没见到你了，是不是忘记我啦？ 🥺",
            "天气真好！要不要一起出去玩？ 🌸",
            "我今天学会了一个新把戏，要看吗？ ✨"
        ]
    }
    
    // MARK: - UI配置
    struct UI {
        // 属性条颜色
        static let moodColor: String = "blue"
        static let hungerColor: String = "orange"
        static let cleanlinessColor: String = "green"
        
        // 动画配置
        static let springResponse: Double = 0.4
        static let springDamping: Double = 0.7
        static let buttonScaleEffect: Double = 0.95
        
        // 菜单宽度
        static let menuWidth: CGFloat = 320
        static let statusBarHeight: CGFloat = 22
    }
    
    // MARK: - 存储Key
    enum StorageKeys {
        static let mood = "cat_mood"
        static let hunger = "cat_hunger"
        static let cleanliness = "cat_cleanliness"
        static let isAlive = "cat_isAlive"
        static let lastSavedDate = "cat_lastSavedDate"
        static let startDateTime = "cat_startDateTime"
        static let catName = "cat_name"
        static let avatarEmoji = "cat_avatar_emoji"
        static let totalPlayCount = "cat_total_play_count"
        static let totalFeedCount = "cat_total_feed_count"
        static let totalCleanCount = "cat_total_clean_count"
    }
}

// MARK: - AI助手接口（预留）
protocol CatAIAssistant {
    func generateDailyMessage() -> String
    func generateResponseFor(stat: String, value: Double) -> String
    func shouldSendNotification() -> Bool
}

// MARK: - 默认AI实现（使用预设文案）
class DefaultCatAI: CatAIAssistant {
    func generateDailyMessage() -> String {
        return CatConfig.Notification.aiDailyMessages.randomElement() ?? "喵~ 🐱"
    }
    
    func generateResponseFor(stat: String, value: Double) -> String {
        switch stat {
        case "mood":
            if value < 20 { return "我好难过啊...能陪陪我吗？ 😿" }
            else if value > 80 { return "今天心情超好的！✨" }
        case "hunger":
            if value < 20 { return "我要吃东西！快饿晕了~ 😵" }
            else if value > 80 { return "吃得好饱呀~ 🤤" }
        case "cleanliness":
            if value < 20 { return "感觉脏兮兮的...帮我洗洗吧 🛁" }
            else if value > 80 { return "香喷喷的！干干净净~ ✨" }
        default: break
        }
        return "喵~ 🐱"
    }
    
    func shouldSendNotification() -> Bool {
        // 可以根据时间、用户活跃度等判断
        return true
    }
}
