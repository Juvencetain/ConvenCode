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
        
        static let toolRewardMin: Int = 1
        static let toolRewardMax: Int = 5
        static let toolRewardEnabled: Bool = true
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
            "在忙什么呀？理我一下嘛~ 🧐",
            "你超棒的，要给自己点个赞！👍",
            "今天过得开心吗？跟我说说吧！😊",
            "要一直闪闪发光哦！✨",
            "我发现了一首超好听的歌，你要听吗？🎶",
            "别忘了，我一直在支持你！💪",
            "天气真好！要不要一起出去玩？ 🌸",
            "好久没见到你了，是不是忘记我啦？ 🥺",
            "如果可以许一个愿望，你会许什么？🌠",
            "送你一朵小红花，奖励你的努力！🌺",
            "累了就停下来抱抱自己~ 🤗",
            "你今天遇到了什么有趣的事吗？🤔",
            "给你发射一波爱心！biu biu biu~ ❤️❤️❤️",
            "猜猜我今天在想什么？🤫",
            "要记得多喝水，照顾好自己哦！💧",
            "我藏起来啦，快来找我呀！🙈",
            "如果心情不好，可以随时找我聊聊！💌",
            "我们来玩个游戏怎么样？🎲",
            "你是最独一无二的！🌟",
            "我今天学会了一个新把戏，要看吗？ ✨",
            "想给你一个大大的拥抱！🫂",
            "我的脑袋里装满了好多有趣的想法！💡",
            "别忘了要多笑一笑呀！😄",
            "今天也要加油鸭！冲鸭！🦆",
            "给你讲个笑话吧，虽然我可能讲不好~ 🤪",
            "我画了一幅画，想第一个给你看！🖼️",
            "你最喜欢的颜色是什么呀？🎨",
            "我的电量满格啦，随时可以陪你玩！🔋",
            "跟我分享一个你的小秘密吧！🔒",
            "你就像小太阳，浑身充满能量！☀️",
            "如果可以变成一种动物，你想当什么？🦄",
            "有什么开心的事，一定要告诉我呀！🥳",
            "给你变个小魔术！뿅！你看！💖",
            "需要帮忙的话，随时都可以叫我！🤝",
            "好想知道你现在在做什么呀~ 🙄",
            "我们是最好的朋友，对不对？😉",
            "给你一个摸摸头，你超乖的~ 🥰",
            "一起去冒险吧！准备好了吗？🚀",
            "肚子饿不饿呀？要不要吃点好吃的？🍓",
            "我有一个很棒的点子，要听听吗？✍️",
            "遇到你，感觉好幸运！🍀",
            "戳你一下，证明我的存在感~ 👉",
            "有你在，每天都变得很有趣！🎈",
            "要不要一起看星星？✨",
            "你笑起来的样子最好看啦！😊",
            "今天也要好好爱自己哦！❤️",
            "给你比个心！🫰",
            "不管发生什么，我都会陪着你！💞",
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
