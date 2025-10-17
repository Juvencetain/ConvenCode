//
//  WorldClockCity.swift
//  Conven
//
//  Created by 土豆星球 on 2025/10/17.
//


import Foundation
import Combine

// MARK: - WorldClock City Model
struct WorldClockCity: Identifiable, Codable, Equatable {
    let id: String
    let worldClockCityName: String
    let worldClockCountry: String
    let worldClockTimeZone: String
    let worldClockFlag: String
    
    init(id: String = UUID().uuidString, cityName: String, country: String, timeZone: String, flag: String) {
        self.id = id
        self.worldClockCityName = cityName
        self.worldClockCountry = country
        self.worldClockTimeZone = timeZone
        self.worldClockFlag = flag
    }
}

// MARK: - WorldClock ViewModel
class WorldClockViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var worldClockCities: [WorldClockCity] = []
    @Published var worldClockCurrentTime: Date = Date()
    @Published var worldClockIsRotating: Bool = true
    
    // MARK: - Private Properties
    private var worldClockTimer: Timer?
    private let worldClockStorageKey = "world_clock_cities"
    
    // MARK: - Available Cities
    let worldClockAvailableCities: [WorldClockCity] = [
        // 亚洲
        WorldClockCity(cityName: "北京", country: "中国", timeZone: "Asia/Shanghai", flag: "🇨🇳"),
        WorldClockCity(cityName: "上海", country: "中国", timeZone: "Asia/Shanghai", flag: "🇨🇳"),
        WorldClockCity(cityName: "香港", country: "中国", timeZone: "Asia/Hong_Kong", flag: "🇭🇰"),
        WorldClockCity(cityName: "台北", country: "中国台湾", timeZone: "Asia/Taipei", flag: "🇹🇼"),
        WorldClockCity(cityName: "东京", country: "日本", timeZone: "Asia/Tokyo", flag: "🇯🇵"),
        WorldClockCity(cityName: "首尔", country: "韩国", timeZone: "Asia/Seoul", flag: "🇰🇷"),
        WorldClockCity(cityName: "新加坡", country: "新加坡", timeZone: "Asia/Singapore", flag: "🇸🇬"),
        WorldClockCity(cityName: "曼谷", country: "泰国", timeZone: "Asia/Bangkok", flag: "🇹🇭"),
        WorldClockCity(cityName: "新德里", country: "印度", timeZone: "Asia/Kolkata", flag: "🇮🇳"),
        WorldClockCity(cityName: "迪拜", country: "阿联酋", timeZone: "Asia/Dubai", flag: "🇦🇪"),
        
        // 欧洲
        WorldClockCity(cityName: "伦敦", country: "英国", timeZone: "Europe/London", flag: "🇬🇧"),
        WorldClockCity(cityName: "巴黎", country: "法国", timeZone: "Europe/Paris", flag: "🇫🇷"),
        WorldClockCity(cityName: "柏林", country: "德国", timeZone: "Europe/Berlin", flag: "🇩🇪"),
        WorldClockCity(cityName: "罗马", country: "意大利", timeZone: "Europe/Rome", flag: "🇮🇹"),
        WorldClockCity(cityName: "马德里", country: "西班牙", timeZone: "Europe/Madrid", flag: "🇪🇸"),
        WorldClockCity(cityName: "阿姆斯特丹", country: "荷兰", timeZone: "Europe/Amsterdam", flag: "🇳🇱"),
        WorldClockCity(cityName: "苏黎世", country: "瑞士", timeZone: "Europe/Zurich", flag: "🇨🇭"),
        WorldClockCity(cityName: "莫斯科", country: "俄罗斯", timeZone: "Europe/Moscow", flag: "🇷🇺"),
        
        // 美洲
        WorldClockCity(cityName: "纽约", country: "美国", timeZone: "America/New_York", flag: "🇺🇸"),
        WorldClockCity(cityName: "洛杉矶", country: "美国", timeZone: "America/Los_Angeles", flag: "🇺🇸"),
        WorldClockCity(cityName: "芝加哥", country: "美国", timeZone: "America/Chicago", flag: "🇺🇸"),
        WorldClockCity(cityName: "旧金山", country: "美国", timeZone: "America/Los_Angeles", flag: "🇺🇸"),
        WorldClockCity(cityName: "华盛顿", country: "美国", timeZone: "America/New_York", flag: "🇺🇸"),
        WorldClockCity(cityName: "多伦多", country: "加拿大", timeZone: "America/Toronto", flag: "🇨🇦"),
        WorldClockCity(cityName: "温哥华", country: "加拿大", timeZone: "America/Vancouver", flag: "🇨🇦"),
        WorldClockCity(cityName: "墨西哥城", country: "墨西哥", timeZone: "America/Mexico_City", flag: "🇲🇽"),
        WorldClockCity(cityName: "圣保罗", country: "巴西", timeZone: "America/Sao_Paulo", flag: "🇧🇷"),
        WorldClockCity(cityName: "布宜诺斯艾利斯", country: "阿根廷", timeZone: "America/Argentina/Buenos_Aires", flag: "🇦🇷"),
        
        // 大洋洲
        WorldClockCity(cityName: "悉尼", country: "澳大利亚", timeZone: "Australia/Sydney", flag: "🇦🇺"),
        WorldClockCity(cityName: "墨尔本", country: "澳大利亚", timeZone: "Australia/Melbourne", flag: "🇦🇺"),
        WorldClockCity(cityName: "奥克兰", country: "新西兰", timeZone: "Pacific/Auckland", flag: "🇳🇿"),
        
        // 非洲
        WorldClockCity(cityName: "开罗", country: "埃及", timeZone: "Africa/Cairo", flag: "🇪🇬"),
        WorldClockCity(cityName: "约翰内斯堡", country: "南非", timeZone: "Africa/Johannesburg", flag: "🇿🇦"),
        WorldClockCity(cityName: "拉各斯", country: "尼日利亚", timeZone: "Africa/Lagos", flag: "🇳🇬"),
    ]
    
    // MARK: - Computed Properties
    var worldClockLocalTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: worldClockCurrentTime)
    }
    
    // MARK: - Init
    init() {
        worldClockLoadCities()
    }
    
    // MARK: - Public Methods
    func startWorldClockTimer() {
        worldClockIsRotating = true
        worldClockUpdateTime()
        worldClockTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.worldClockUpdateTime()
        }
    }
    
    func stopWorldClockTimer() {
        worldClockIsRotating = false
        worldClockTimer?.invalidate()
        worldClockTimer = nil
    }
    
    func addWorldClockCity(_ city: WorldClockCity) {
        guard !worldClockCities.contains(where: { $0.id == city.id }) else { return }
        worldClockCities.append(city)
        worldClockSaveCities()
    }
    
    func removeWorldClockCity(_ city: WorldClockCity) {
        worldClockCities.removeAll { $0.id == city.id }
        worldClockSaveCities()
    }
    
    // MARK: - Private Methods
    private func worldClockUpdateTime() {
        worldClockCurrentTime = Date()
    }
    
    private func worldClockLoadCities() {
        guard let data = UserDefaults.standard.data(forKey: worldClockStorageKey),
              let cities = try? JSONDecoder().decode([WorldClockCity].self, from: data) else {
            // 默认添加几个城市
            worldClockCities = [
                WorldClockCity(cityName: "北京", country: "中国", timeZone: "Asia/Shanghai", flag: "🇨🇳"),
                WorldClockCity(cityName: "纽约", country: "美国", timeZone: "America/New_York", flag: "🇺🇸"),
                WorldClockCity(cityName: "伦敦", country: "英国", timeZone: "Europe/London", flag: "🇬🇧"),
                WorldClockCity(cityName: "东京", country: "日本", timeZone: "Asia/Tokyo", flag: "🇯🇵")
            ]
            worldClockSaveCities()
            return
        }
        worldClockCities = cities
    }
    
    private func worldClockSaveCities() {
        if let encoded = try? JSONEncoder().encode(worldClockCities) {
            UserDefaults.standard.set(encoded, forKey: worldClockStorageKey)
        }
    }
}