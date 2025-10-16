import Foundation
import Combine
import AppKit

// MARK: - Date Calculator ViewModel
@MainActor
class DateCalculatorViewModel: ObservableObject {
    
    // MARK: - Enums
    
    /// 计算模式
    enum CalculationMode: String, CaseIterable, Identifiable {
        case difference = "日期差"
        case addSubtract = "日期加减"
        case ageCalculator = "年龄计算"
        case weekdayInfo = "日期信息"
        
        var id: Self { self }
        
        var icon: String {
            switch self {
            case .difference: return "calendar.badge.clock"
            case .addSubtract: return "calendar.badge.plus"
            case .ageCalculator: return "person.text.rectangle"
            case .weekdayInfo: return "info.circle"
            }
        }
    }
    
    /// 时间单位
    struct DateToolUnit: Identifiable {
        let id = UUID()
        let name: String
        let unit: Calendar.Component
        let icon: String
    }
    
    /// 计算历史记录
    struct DateToolHistoryItem: Identifiable {
        let id = UUID()
        let timestamp: Date
        let mode: CalculationMode
        let description: String
        let result: String
    }
    
    // MARK: - Published Properties
    
    @Published var dateToolCalculationMode: CalculationMode = .difference
    
    // 日期差计算
    @Published var dateToolStartDate = Date()
    @Published var dateToolEndDate = Date()
    @Published var dateToolIncludeTime = false
    @Published var dateToolExcludeWeekends = false
    
    // 日期加减
    @Published var dateToolBaseDate = Date()
    @Published var dateToolValueToAdd: Double = 1
    @Published var dateToolIsAdding = true
    @Published var dateToolSelectedUnit: Calendar.Component = .day
    
    // 年龄计算
    @Published var dateToolBirthDate = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    @Published var dateToolTargetDate = Date()
    
    // 日期信息
    @Published var dateToolInfoDate = Date()
    
    // 历史记录
    @Published var dateToolHistory: [DateToolHistoryItem] = []
    @Published var dateToolShowHistory = false
    
    // UI状态
    @Published var dateToolCopiedText: String?
    @Published var dateToolShowCopyFeedback = false
    
    // 性能优化：缓存计算结果
    @Published private var dateToolCachedDifferenceResult: DateToolDifferenceData?
    @Published private var dateToolCachedAddSubtractResult: DateToolAddSubtractData?
    @Published private var dateToolCachedAgeResult: DateToolAgeData?
    @Published private var dateToolCachedInfoResult: DateToolInfoData?
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initializer
    
    init() {
        setupBindings()
    }
    
    // MARK: - Setup Bindings
    
    private func setupBindings() {
        // 日期差计算 - 当相关属性变化时重新计算
        Publishers.CombineLatest4($dateToolStartDate, $dateToolEndDate, $dateToolIncludeTime, $dateToolExcludeWeekends)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _, _, _, _ in
                self?.dateToolCachedDifferenceResult = nil
            }
            .store(in: &cancellables)
        
        // 日期加减计算
        Publishers.CombineLatest4($dateToolBaseDate, $dateToolValueToAdd, $dateToolIsAdding, $dateToolSelectedUnit)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _, _, _, _ in
                self?.dateToolCachedAddSubtractResult = nil
            }
            .store(in: &cancellables)
        
        // 年龄计算
        Publishers.CombineLatest($dateToolBirthDate, $dateToolTargetDate)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.dateToolCachedAgeResult = nil
            }
            .store(in: &cancellables)
        
        // 日期信息
        $dateToolInfoDate
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.dateToolCachedInfoResult = nil
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Constants
    
    let dateToolUnits: [DateToolUnit] = [
        DateToolUnit(name: "秒", unit: .second, icon: "clock"),
        DateToolUnit(name: "分钟", unit: .minute, icon: "clock"),
        DateToolUnit(name: "小时", unit: .hour, icon: "clock.fill"),
        DateToolUnit(name: "天", unit: .day, icon: "sun.max"),
        DateToolUnit(name: "周", unit: .weekOfYear, icon: "calendar"),
        DateToolUnit(name: "月", unit: .month, icon: "calendar.badge.clock"),
        DateToolUnit(name: "年", unit: .year, icon: "calendar.circle")
    ]
    
    private let calendar = Calendar.current
    
    // MARK: - Computed Properties
    
    /// 日期差结果（详细版本）- 使用缓存优化性能
    var dateToolDifferenceResult: DateToolDifferenceData {
        if let cached = dateToolCachedDifferenceResult {
            return cached
        }
        
        let start = dateToolIncludeTime ? dateToolStartDate : calendar.startOfDay(for: dateToolStartDate)
        let end = dateToolIncludeTime ? dateToolEndDate : calendar.startOfDay(for: dateToolEndDate)
        
        // 精确计算各种单位
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: start,
            to: end
        )
        
        // 总天数（包含时间则精确到小数）
        let totalSeconds = end.timeIntervalSince(start)
        let totalDays = totalSeconds / 86400
        let totalWeeks = totalDays / 7
        let totalMonths = Double(components.month ?? 0) + Double(components.year ?? 0) * 12
        let totalHours = totalSeconds / 3600
        let totalMinutes = totalSeconds / 60
        
        // 工作日计算（排除周末）
        let workdays = dateToolExcludeWeekends ? calculateWorkdays(from: start, to: end) : 0
        
        let result = DateToolDifferenceData(
            years: components.year ?? 0,
            months: components.month ?? 0,
            days: components.day ?? 0,
            hours: components.hour ?? 0,
            minutes: components.minute ?? 0,
            seconds: components.second ?? 0,
            totalDays: Int(totalDays),
            totalWeeks: totalWeeks,
            totalMonths: totalMonths,
            totalHours: totalHours,
            totalMinutes: totalMinutes,
            totalSeconds: totalSeconds,
            workdays: workdays,
            isNegative: totalSeconds < 0
        )
        
        dateToolCachedDifferenceResult = result
        return result
    }
    
    /// 日期加减结果 - 使用缓存优化性能
    var dateToolAddSubtractResult: DateToolAddSubtractData {
        if let cached = dateToolCachedAddSubtractResult {
            return cached
        }
        
        let value = Int(dateToolValueToAdd) * (dateToolIsAdding ? 1 : -1)
        
        guard let newDate = calendar.date(byAdding: dateToolSelectedUnit, value: value, to: dateToolBaseDate) else {
            let emptyResult = DateToolAddSubtractData(
                resultDate: dateToolBaseDate,
                formattedDate: "计算错误",
                dayOfWeek: "",
                dayOfYear: 0,
                weekOfYear: 0,
                isWeekend: false
            )
            dateToolCachedAddSubtractResult = emptyResult
            return emptyResult
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 (EEEE)"
        formatter.locale = Locale(identifier: "zh_CN")
        
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: newDate) ?? 0
        let weekOfYear = calendar.component(.weekOfYear, from: newDate)
        let weekday = calendar.component(.weekday, from: newDate)
        let isWeekend = weekday == 1 || weekday == 7
        
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "EEEE"
        weekdayFormatter.locale = Locale(identifier: "zh_CN")
        
        let result = DateToolAddSubtractData(
            resultDate: newDate,
            formattedDate: formatter.string(from: newDate),
            dayOfWeek: weekdayFormatter.string(from: newDate),
            dayOfYear: dayOfYear,
            weekOfYear: weekOfYear,
            isWeekend: isWeekend
        )
        
        dateToolCachedAddSubtractResult = result
        return result
    }
    
    /// 年龄计算结果 - 使用缓存优化性能
    var dateToolAgeResult: DateToolAgeData {
        if let cached = dateToolCachedAgeResult {
            return cached
        }
        
        let components = calendar.dateComponents(
            [.year, .month, .day],
            from: calendar.startOfDay(for: dateToolBirthDate),
            to: calendar.startOfDay(for: dateToolTargetDate)
        )
        
        let totalDays = calendar.dateComponents([.day], from: dateToolBirthDate, to: dateToolTargetDate).day ?? 0
        let totalWeeks = Double(totalDays) / 7.0
        let totalMonths = (components.year ?? 0) * 12 + (components.month ?? 0)
        
        // 计算下一个生日
        var nextBirthdayComponents = calendar.dateComponents([.month, .day], from: dateToolBirthDate)
        nextBirthdayComponents.year = calendar.component(.year, from: dateToolTargetDate)
        
        guard var nextBirthday = calendar.date(from: nextBirthdayComponents) else {
            let emptyResult = createEmptyAgeData()
            dateToolCachedAgeResult = emptyResult
            return emptyResult
        }
        
        // 如果今年的生日已过，计算明年的生日
        if nextBirthday < dateToolTargetDate {
            nextBirthday = calendar.date(byAdding: .year, value: 1, to: nextBirthday) ?? nextBirthday
        }
        
        let daysUntilBirthday = calendar.dateComponents([.day], from: dateToolTargetDate, to: nextBirthday).day ?? 0
        
        // 星座计算
        let zodiac = calculateZodiacSign(month: calendar.component(.month, from: dateToolBirthDate),
                                         day: calendar.component(.day, from: dateToolBirthDate))
        
        // 生肖计算
        let chineseZodiac = calculateChineseZodiac(year: calendar.component(.year, from: dateToolBirthDate))
        
        let result = DateToolAgeData(
            years: components.year ?? 0,
            months: components.month ?? 0,
            days: components.day ?? 0,
            totalDays: totalDays,
            totalWeeks: totalWeeks,
            totalMonths: totalMonths,
            daysUntilNextBirthday: daysUntilBirthday,
            nextBirthday: nextBirthday,
            zodiacSign: zodiac,
            chineseZodiac: chineseZodiac
        )
        
        dateToolCachedAgeResult = result
        return result
    }
    
    /// 日期信息结果 - 使用缓存优化性能
    var dateToolInfoResult: DateToolInfoData {
        if let cached = dateToolCachedInfoResult {
            return cached
        }
        
        let weekday = calendar.component(.weekday, from: dateToolInfoDate)
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: dateToolInfoDate) ?? 0
        let weekOfYear = calendar.component(.weekOfYear, from: dateToolInfoDate)
        let weekOfMonth = calendar.component(.weekOfMonth, from: dateToolInfoDate)
        let year = calendar.component(.year, from: dateToolInfoDate)
        let isLeapYearValue = isLeapYear(year)
        let daysInMonth = calendar.range(of: .day, in: .month, for: dateToolInfoDate)?.count ?? 0
        let daysInYear = isLeapYearValue ? 366 : 365
        let isWeekend = weekday == 1 || weekday == 7
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEEE"
        let weekdayName = formatter.string(from: dateToolInfoDate)
        
        let month = calendar.component(.month, from: dateToolInfoDate)
        let day = calendar.component(.day, from: dateToolInfoDate)
        
        let zodiac = calculateZodiacSign(month: month, day: day)
        let chineseZodiac = calculateChineseZodiac(year: year)
        
        // 季度计算
        let quarter = (month - 1) / 3 + 1
        
        let result = DateToolInfoData(
            weekday: weekday,
            weekdayName: weekdayName,
            dayOfYear: dayOfYear,
            weekOfYear: weekOfYear,
            weekOfMonth: weekOfMonth,
            quarter: quarter,
            daysInMonth: daysInMonth,
            daysInYear: daysInYear,
            isLeapYear: isLeapYearValue,
            isWeekend: isWeekend,
            zodiacSign: zodiac,
            chineseZodiac: chineseZodiac
        )
        
        dateToolCachedInfoResult = result
        return result
    }
    
    // MARK: - Actions
    
    /// 设置为今天
    func dateToolSetToday() {
        switch dateToolCalculationMode {
        case .difference:
            dateToolEndDate = Date()
        case .addSubtract:
            dateToolBaseDate = Date()
        case .ageCalculator:
            dateToolTargetDate = Date()
        case .weekdayInfo:
            dateToolInfoDate = Date()
        }
    }
    
    /// 交换日期
    func dateToolSwapDates() {
        let temp = dateToolStartDate
        dateToolStartDate = dateToolEndDate
        dateToolEndDate = temp
    }
    
    /// 复制结果到剪贴板
    func dateToolCopyResult(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
        
        dateToolCopiedText = text
        dateToolShowCopyFeedback = true
        
        // 2秒后隐藏反馈
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            dateToolShowCopyFeedback = false
        }
    }
    
    /// 添加到历史记录
    func dateToolAddToHistory(description: String, result: String) {
        let item = DateToolHistoryItem(
            timestamp: Date(),
            mode: dateToolCalculationMode,
            description: description,
            result: result
        )
        dateToolHistory.insert(item, at: 0)
        
        // 只保留最近20条记录
        if dateToolHistory.count > 20 {
            dateToolHistory = Array(dateToolHistory.prefix(20))
        }
    }
    
    /// 清空历史记录
    func dateToolClearHistory() {
        dateToolHistory.removeAll()
    }
    
    /// 快速设置预设时间间隔（用于日期差计算）
    func dateToolSetQuickInterval(_ interval: DateToolQuickInterval) {
        dateToolEndDate = Date()
        dateToolStartDate = interval.calculateStartDate(from: dateToolEndDate)
    }
    
    // MARK: - Private Helper Methods
    
    /// 计算工作日（排除周末）- 优化版本
    private func calculateWorkdays(from start: Date, to end: Date) -> Int {
        // 如果日期范围太大（超过5年），返回0避免卡顿
        let daysDiff = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        guard abs(daysDiff) <= 1825 else { return 0 }  // 5年 = 1825天
        
        var workdays = 0
        var currentDate = start
        
        // 优化：批量处理整周
        while currentDate <= end {
            let weekday = calendar.component(.weekday, from: currentDate)
            if weekday != 1 && weekday != 7 { // 不是周日和周六
                workdays += 1
            }
            
            // 优化：如果还剩很多天，尝试跳过整周
            let remainingDays = calendar.dateComponents([.day], from: currentDate, to: end).day ?? 0
            if remainingDays > 7 && weekday == 1 { // 如果是周日且还有很多天
                // 计算整周数
                let fullWeeks = remainingDays / 7
                workdays += fullWeeks * 5  // 每周5个工作日
                // 跳到最后一个完整周
                if let skipDate = calendar.date(byAdding: .day, value: fullWeeks * 7, to: currentDate) {
                    currentDate = skipDate
                    continue
                }
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return workdays
    }
    
    /// 判断是否为闰年
    private func isLeapYear(_ year: Int) -> Bool {
        return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
    }
    
    /// 计算星座
    private func calculateZodiacSign(month: Int, day: Int) -> String {
        switch (month, day) {
        case (3, 21...31), (4, 1...19): return "白羊座 ♈"
        case (4, 20...30), (5, 1...20): return "金牛座 ♉"
        case (5, 21...31), (6, 1...21): return "双子座 ♊"
        case (6, 22...30), (7, 1...22): return "巨蟹座 ♋"
        case (7, 23...31), (8, 1...22): return "狮子座 ♌"
        case (8, 23...31), (9, 1...22): return "处女座 ♍"
        case (9, 23...30), (10, 1...23): return "天秤座 ♎"
        case (10, 24...31), (11, 1...22): return "天蝎座 ♏"
        case (11, 23...30), (12, 1...21): return "射手座 ♐"
        case (12, 22...31), (1, 1...19): return "摩羯座 ♑"
        case (1, 20...31), (2, 1...18): return "水瓶座 ♒"
        case (2, 19...29), (3, 1...20): return "双鱼座 ♓"
        default: return "未知"
        }
    }
    
    /// 计算生肖
    private func calculateChineseZodiac(year: Int) -> String {
        let zodiacs = ["猴", "鸡", "狗", "猪", "鼠", "牛", "虎", "兔", "龙", "蛇", "马", "羊"]
        let index = year % 12
        return zodiacs[index]
    }
    
    /// 创建空的年龄数据
    private func createEmptyAgeData() -> DateToolAgeData {
        DateToolAgeData(
            years: 0, months: 0, days: 0,
            totalDays: 0, totalWeeks: 0, totalMonths: 0,
            daysUntilNextBirthday: 0, nextBirthday: Date(),
            zodiacSign: "", chineseZodiac: ""
        )
    }
}

// MARK: - Data Models

/// 日期差数据
struct DateToolDifferenceData {
    let years: Int
    let months: Int
    let days: Int
    let hours: Int
    let minutes: Int
    let seconds: Int
    let totalDays: Int
    let totalWeeks: Double
    let totalMonths: Double
    let totalHours: Double
    let totalMinutes: Double
    let totalSeconds: Double
    let workdays: Int
    let isNegative: Bool
}

/// 日期加减数据
struct DateToolAddSubtractData {
    let resultDate: Date
    let formattedDate: String
    let dayOfWeek: String
    let dayOfYear: Int
    let weekOfYear: Int
    let isWeekend: Bool
}

/// 年龄数据
struct DateToolAgeData {
    let years: Int
    let months: Int
    let days: Int
    let totalDays: Int
    let totalWeeks: Double
    let totalMonths: Int
    let daysUntilNextBirthday: Int
    let nextBirthday: Date
    let zodiacSign: String
    let chineseZodiac: String
}

/// 日期信息数据
struct DateToolInfoData {
    let weekday: Int
    let weekdayName: String
    let dayOfYear: Int
    let weekOfYear: Int
    let weekOfMonth: Int
    let quarter: Int
    let daysInMonth: Int
    let daysInYear: Int
    let isLeapYear: Bool
    let isWeekend: Bool
    let zodiacSign: String
    let chineseZodiac: String
}

/// 快速时间间隔
enum DateToolQuickInterval: String, CaseIterable {
    case oneWeek = "一周前"
    case twoWeeks = "两周前"
    case oneMonth = "一个月前"
    case threeMonths = "三个月前"
    case sixMonths = "半年前"
    case oneYear = "一年前"
    
    func calculateStartDate(from endDate: Date) -> Date {
        let calendar = Calendar.current
        switch self {
        case .oneWeek:
            return calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        case .twoWeeks:
            return calendar.date(byAdding: .day, value: -14, to: endDate) ?? endDate
        case .oneMonth:
            return calendar.date(byAdding: .month, value: -1, to: endDate) ?? endDate
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: endDate) ?? endDate
        case .sixMonths:
            return calendar.date(byAdding: .month, value: -6, to: endDate) ?? endDate
        case .oneYear:
            return calendar.date(byAdding: .year, value: -1, to: endDate) ?? endDate
        }
    }
}
