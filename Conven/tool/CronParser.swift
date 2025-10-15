import SwiftUI
import Foundation
import Combine

// MARK: - Cron Parser Logic
class CronParser {
    enum CronError: LocalizedError {
        case invalidExpression(String)
        var errorDescription: String? {
            switch self {
            case .invalidExpression(let message):
                return "无效的表达式: \(message)"
            }
        }
    }

    private let parts: [String]
    private let calendar = Calendar(identifier: .gregorian)

    private let secondsPart: String
    private let minutesPart: String
    private let hoursPart: String
    private let daysOfMonthPart: String
    private let monthsPart: String
    private let daysOfWeekPart: String

    init(expression: String) throws {
        let trimmedExpression = expression
            .replacingOccurrences(of: "？", with: "?")
            .replacingOccurrences(of: "?", with: "*")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let components = trimmedExpression.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        guard [5, 6].contains(components.count) else {
            throw CronError.invalidExpression("应包含 5 或 6 个部分（当前：\(components.count)）")
        }
        
        self.parts = components
        
        if parts.count == 6 {
            self.secondsPart = parts[0]
            self.minutesPart = parts[1]
            self.hoursPart = parts[2]
            self.daysOfMonthPart = parts[3]
            self.monthsPart = parts[4]
            self.daysOfWeekPart = parts[5]
        } else {
            // 5-part 表达式：秒默认 0
            self.secondsPart = "0"
            self.minutesPart = parts[0]
            self.hoursPart = parts[1]
            self.daysOfMonthPart = parts[2]
            self.monthsPart = parts[3]
            self.daysOfWeekPart = parts[4]
        }
    }
    
    /// 生成更自然的中文描述
    func generateHumanReadableDescription() throws -> String {
        // 如果是完整 6 段并且秒段非 0/*，先描述秒
        var clauses: [String] = []
        
        // 秒/分钟/小时 组合说明
        let secondsClause = describeTimePartForHuman(secondsPart, unitSingular: "秒", isSeconds: true)
        let minutesClause = describeTimePartForHuman(minutesPart, unitSingular: "分钟")
        let hoursClause = describeTimePartForHuman(hoursPart, unitSingular: "小时")
        
        // 优化常见模式
        if hoursPart == "*" && minutesPart.starts(with: "*/") && (secondsPart == "*" || secondsPart == "0") {
            let step = minutesPart.dropFirst(2)
            clauses.append("每 \(step) 分钟执行一次")
        } else if hoursPart == "*" && minutesPart == "*" && (secondsPart == "*" || secondsPart == "0") {
            clauses.append("每分钟执行一次")
        } else {
            // 构造“在 X 的 Y 秒/分/时”类描述
            var timePhraseParts: [String] = []
            if hoursPart != "*" { timePhraseParts.append(hoursClause) }
            if minutesPart != "*" { timePhraseParts.append(minutesClause) }
            if secondsPart != "*" && secondsPart != "0" { timePhraseParts.append(secondsClause) }
            if timePhraseParts.isEmpty {
                // 没有具体时分秒，视为每小时/每分钟/每秒的组合
                if hoursPart == "*" && minutesPart == "*" {
                    clauses.append("每分钟执行一次")
                } else {
                    // fallback
                    clauses.append(contentsOf: timePhraseParts)
                }
            } else {
                clauses.append("在" + timePhraseParts.joined(separator: "、") + "执行")
            }
        }

        // 日 / 星期 / 月 的描述（优先日或周的详细说明）
        let dayOfMonthDesc = describePartHuman(daysOfMonthPart, unitSingular: "日", isMonthIndex: false)
        let dayOfWeekDesc = describePartHuman(daysOfWeekPart, unitSingular: "周", isDayOfWeek: true)
        let monthDesc = describePartHuman(monthsPart, unitSingular: "月", isMonthIndex: true)
        
        // 当日和周同时指定时，CRON 语义是“OR”，我们要把它表达清楚
        if daysOfMonthPart != "*" && daysOfWeekPart != "*" {
            clauses.append("且在每月的\(dayOfMonthDesc)或\(dayOfWeekDesc)时触发")
        } else if daysOfMonthPart != "*" {
            clauses.append("且在每月的\(dayOfMonthDesc)触发")
        } else if daysOfWeekPart != "*" {
            clauses.append("且在\(dayOfWeekDesc)触发")
        }
        
        if monthsPart != "*" {
            clauses.append("仅在\(monthDesc)执行")
        }
        
        // 合并句子并修饰语气
        let final = clauses.joined(separator: "，")
        // 保证句尾
        return final.hasSuffix("。") ? final : final + "。"
    }
    
    // MARK: - 帮助函数（用于生成更自然的中文）
    private func describeTimePartForHuman(_ part: String, unitSingular: String, isSeconds: Bool = false) -> String {
        if part == "*" { return "每\(unitSingular)" }
        if part.starts(with: "*/") {
            let step = part.dropFirst(2)
            return "每 \(step) \(unitSingular)"
        }
        // 处理列表或范围或单个值
        let items = part.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let mapped = items.map { item -> String in
            if item.contains("-") {
                let bounds = item.split(separator: "-").map { String($0) }
                return "\(bounds[0])到\(bounds[1])\(unitSingular)"
            } else {
                return "\(item)\(unitSingular)"
            }
        }
        return mapped.joined(separator: "、")
    }
    
    private func describePartHuman(_ part: String, unitSingular: String, isMonthIndex: Bool = false, isDayOfWeek: Bool = false) -> String {
        if part == "*" { return "所有\(unitSingular)" }
        if part.starts(with: "*/") {
            let step = part.dropFirst(2)
            return "每 \(step) 个\(unitSingular)"
        }
        let values = part.components(separatedBy: ",")
        let descriptions = values.map { val -> String in
            if val.contains("-") {
                let parts = val.split(separator: "-").map { String($0) }
                let a = parts[0], b = parts[1]
                if isMonthIndex, let ai = Int(a), let bi = Int(b) {
                    return "\(monthName(from: ai))到\(monthName(from: bi))"
                } else if isDayOfWeek, let ai = Int(a), let bi = Int(b) {
                    return "\(dayOfWeekName(from: String(ai)))到\(dayOfWeekName(from: String(bi)))"
                } else {
                    return "\(a)到\(b)\(unitSingular)"
                }
            } else {
                if isMonthIndex, let n = Int(val) {
                    return monthName(from: n)
                } else if isDayOfWeek {
                    return dayOfWeekName(from: val)
                } else {
                    return val + unitSingular
                }
            }
        }
        return descriptions.joined(separator: "、")
    }
    
    private func monthName(from value: Int) -> String {
        guard value >= 1 && value <= 12 else { return "\(value)" }
        return calendar.monthSymbols[value - 1]
    }
    
    private func dayOfWeekName(from value: String) -> String {
        // normalize 7 -> 0
        let normalized = value.replacingOccurrences(of: "7", with: "0")
        if let num = Int(normalized) {
            return dayOfWeekName(from: num)
        }
        return value
    }
    
    private func dayOfWeekName(from value: Int) -> String {
        // weekdaySymbols 以周日为第一位
        let days = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let idx = (value % 7 + 7) % 7
        if idx >= 0 && idx < days.count { return days[idx] }
        return "\(value)"
    }

    // MARK: - 计算下一些执行时间
    func nextRunDates(from date: Date = Date(), count: Int = 5) throws -> [Date] {
        var dates: [Date] = []
        var currentDate = date
        
        // 解析成集合以便快速匹配
        let seconds = try parse(part: secondsPart, range: 0...59)
        let minutes = try parse(part: minutesPart, range: 0...59)
        let hours = try parse(part: hoursPart, range: 0...23)
        let daysOfMonth = try parse(part: daysOfMonthPart, range: 1...31)
        let months = try parse(part: monthsPart, range: 1...12)
        let daysOfWeek = try parse(part: daysOfWeekPart.replacingOccurrences(of: "7", with: "0"), range: 0...6)

        // 安全迭代上限（防止无限循环）——在极端表达式下会停止
        let maxIterations = 1_000_000
        var iter = 0

        while dates.count < count && iter < maxIterations {
            iter += 1
            guard let nextDate = calendar.date(byAdding: .second, value: 1, to: currentDate) else { break }
            currentDate = nextDate
            
            let comps = calendar.dateComponents([.second, .minute, .hour, .day, .month, .weekday, .year], from: currentDate)
            
            guard let sec = comps.second,
                  let min = comps.minute,
                  let hr = comps.hour,
                  let day = comps.day,
                  let month = comps.month,
                  let weekday = comps.weekday else { continue }

            let currentDayOfWeek = weekday - 1 // Calendar.weekday: 1 = Sunday

            // 日匹配：如果两者都为 '*'，则为 true；
            // 若其中一个为 '*' 则用另一个来判断；若两者都不是 '*'，按 cron 语义为 OR
            let dayMatches: Bool
            if daysOfMonthPart == "*" && daysOfWeekPart == "*" {
                dayMatches = true
            } else if daysOfMonthPart == "*" {
                dayMatches = daysOfWeek.contains(currentDayOfWeek)
            } else if daysOfWeekPart == "*" {
                dayMatches = daysOfMonth.contains(day)
            } else {
                dayMatches = daysOfMonth.contains(day) || daysOfWeek.contains(currentDayOfWeek)
            }

            if seconds.contains(sec) &&
               minutes.contains(min) &&
               hours.contains(hr) &&
               months.contains(month) &&
               dayMatches {
                // 避免重复
                if dates.last != currentDate {
                    dates.append(currentDate)
                }
            }
        }
        
        if iter >= maxIterations {
            // 若未找到足够项，可继续返回找到的项（外部可显示警告）
        }
        
        return dates
    }

    // MARK: - 解析子段为整数集合（支持 *, 数值, 列表, 范围, 步进）
    private func parse(part: String, range: ClosedRange<Int>) throws -> Set<Int> {
        if part == "*" {
            return Set(range)
        }
        var result = Set<Int>()
        let subparts = part.components(separatedBy: ",")
        for raw in subparts {
            let subpart = raw.trimmingCharacters(in: .whitespaces)
            if subpart.contains("/") {
                // 支持形式: */n, start/n, a-b/n
                let comps = subpart.components(separatedBy: "/")
                guard comps.count == 2, let step = Int(comps[1]), step > 0 else {
                    throw CronError.invalidExpression("无效步长: \(subpart)")
                }
                let base = comps[0]
                if base == "*" {
                    let start = range.lowerBound
                    for v in stride(from: start, through: range.upperBound, by: step) { result.insert(v) }
                } else if base.contains("-") {
                    let bounds = base.components(separatedBy: "-")
                    guard bounds.count == 2, let s = Int(bounds[0]), let e = Int(bounds[1]) else {
                        throw CronError.invalidExpression("无效范围 (步进): \(subpart)")
                    }
                    guard range.contains(s) && range.contains(e) && s <= e else {
                        throw CronError.invalidExpression("步进范围超界或错误: \(subpart)")
                    }
                    for v in stride(from: s, through: e, by: step) { result.insert(v) }
                } else if let start = Int(base) {
                    guard range.contains(start) else {
                        throw CronError.invalidExpression("起始值超出范围: \(subpart)")
                    }
                    for v in stride(from: start, through: range.upperBound, by: step) { result.insert(v) }
                } else {
                    throw CronError.invalidExpression("无法解析步进表达式: \(subpart)")
                }
            } else if subpart.contains("-") {
                let components = subpart.components(separatedBy: "-")
                guard components.count == 2, let start = Int(components[0]), let end = Int(components[1]) else {
                    throw CronError.invalidExpression("无效范围: \(subpart)")
                }
                guard range.contains(start) && range.contains(end) && start <= end else {
                    throw CronError.invalidExpression("范围值超出边界或顺序错误: \(subpart)")
                }
                result.formUnion(start...end)
            } else if let num = Int(subpart) {
                // 周日 7 视为 0（在 daysOfWeek 的情况下 caller 已经用 replace 替换了 7->0）
                let normalized = (range == 0...6 && num == 7) ? 0 : num
                guard range.contains(normalized) else {
                    throw CronError.invalidExpression("数值超出范围: \(subpart)")
                }
                result.insert(normalized)
            } else {
                throw CronError.invalidExpression("无法解析: \(subpart)")
            }
        }
        return result
    }
}


// MARK: - ViewModel
@MainActor
class CronViewModel: ObservableObject {
    @Published var cronExpression: String = "*/5 * * * *"
    @Published var humanReadableDescription: String = ""
    @Published var nextRunTimes: [Date] = []
    @Published var errorMessage: String?
    
    let examples = [
        ("每分钟", "* * * * *"),
        ("每10分钟的第0秒", "0 */10 * * * *"),
        ("每天凌晨3点", "0 3 * * *"),
        ("每个工作日下午5点", "0 17 * * 1-5"),
        ("每月1号和15号的午夜", "0 0 1,15 * *"),
    ]

    init() {
        // 不在 init 中自动解析，交由视图 onAppear 执行一次
    }
    
    func parseExpression() {
        do {
            let parser = try CronParser(expression: cronExpression)
            nextRunTimes = try parser.nextRunDates(count: 5)
            humanReadableDescription = try parser.generateHumanReadableDescription()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            nextRunTimes = []
            humanReadableDescription = ""
        }
    }
}


// MARK: - 主视图
struct CronView: View {
    @StateObject private var viewModel = CronViewModel()

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                Divider().padding(.horizontal, 20)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        inputSection
                        
                        if let error = viewModel.errorMessage {
                            errorView(error)
                        } else {
                            resultsSection
                        }
                        
                        examplesSection
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 450, height: 550)
        .onAppear {
            viewModel.parseExpression()
        }
    }

    private var headerBar: some View {
        HStack {
            Image(systemName: "timer.square")
                .font(.system(size: 16))
                .foregroundStyle(.cyan.gradient)
            Text("Cron 表达式解析器")
                .font(.system(size: 14, weight: .medium))
            Spacer()
        }
        .padding(20)
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cron 表达式 (支持5位或6位)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            
            TextField("例如: */5 * * * *", text: $viewModel.cronExpression)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 16, design: .monospaced))
                .padding(12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                .onChange(of: viewModel.cronExpression) { _ in
                    viewModel.parseExpression()
                }
        }
    }
    
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("表达式解释")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            
            Text(viewModel.humanReadableDescription)
                .font(.system(size: 13))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)

            Text("接下来的5次执行时间")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                if viewModel.nextRunTimes.isEmpty {
                    Text("无可用的下次执行时间（请检查表达式）")
                        .font(.system(size: 13, design: .monospaced))
                } else {
                    ForEach(viewModel.nextRunTimes, id: \.self) { date in
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.accentColor)
                            Text(dateFormatter.string(from: date))
                            Spacer()
                        }
                        .font(.system(size: 13, design: .monospaced))
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
        }
    }

    private var examplesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("常用示例")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            
            ForEach(viewModel.examples, id: \.0) { name, expression in
                Button(action: {
                    viewModel.cronExpression = expression
                    viewModel.parseExpression()
                }) {
                    HStack {
                        Text(name)
                            .font(.system(size: 13))
                        Spacer()
                        Text(expression)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        HStack {
            Image(systemName: "xmark.octagon.fill")
            Text(message)
                .font(.system(size: 12))
            Spacer()
        }
        .padding(12)
        .background(Color.red.opacity(0.2))
        .cornerRadius(8)
        .foregroundColor(.red)
    }
}
