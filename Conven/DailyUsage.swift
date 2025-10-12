import SwiftUI
import Foundation
import Combine
// MARK: - 数据模型

/// 每日使用记录
struct DailyUsage: Identifiable, Codable {
    let id: UUID
    let date: Date
    var openCount: Int
    var lastOpenTime: Date
    
    init(date: Date, openCount: Int = 0) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.openCount = openCount
        self.lastOpenTime = date
    }
    
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
    
    var weekday: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

// MARK: - 统计服务

class UsageStatisticsService: ObservableObject {
    static let shared = UsageStatisticsService()
    
    @Published var dailyUsages: [DailyUsage] = []
    
    private let storageKey = "app_usage_statistics"
    private let maxDays = 30 // 保留30天数据
    
    private init() {
        loadStatistics()
        recordAppOpen()
    }
    
    // MARK: - 记录打开
    
    /// 记录应用打开
    func recordAppOpen() {
        let today = Calendar.current.startOfDay(for: Date())
        
        if let index = dailyUsages.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            // 今天已有记录，增加计数
            dailyUsages[index].openCount += 1
            dailyUsages[index].lastOpenTime = Date()
        } else {
            // 新的一天，创建记录
            let newRecord = DailyUsage(date: today, openCount: 1)
            dailyUsages.append(newRecord)
        }
        
        // 清理旧数据，只保留最近30天
        cleanOldData()
        
        // 保存
        saveStatistics()
        
        print("📊 记录应用打开 - 今日第 \(getTodayCount()) 次")
    }
    
    // MARK: - 数据获取
    
    /// 获取今日打开次数
    func getTodayCount() -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        return dailyUsages.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) })?.openCount ?? 0
    }
    
    /// 获取总打开次数
    func getTotalCount() -> Int {
        return dailyUsages.reduce(0) { $0 + $1.openCount }
    }
    
    /// 获取平均每日打开次数
    func getAverageCount() -> Int {
        guard !dailyUsages.isEmpty else { return 0 }
        return getTotalCount() / dailyUsages.count
    }
    
    /// 获取最近N天的数据
    func getRecentDays(_ days: Int) -> [DailyUsage] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var result: [DailyUsage] = []
        
        for i in (0..<days).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                if let usage = dailyUsages.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                    result.append(usage)
                } else {
                    // 没有记录的日期，添加0次
                    result.append(DailyUsage(date: date, openCount: 0))
                }
            }
        }
        
        return result
    }
    
    /// 获取最大打开次数（用于图表缩放）
    func getMaxCount(in days: Int) -> Int {
        let recentData = getRecentDays(days)
        return recentData.map { $0.openCount }.max() ?? 10
    }
    
    // MARK: - 数据持久化
    
    private func saveStatistics() {
        if let encoded = try? JSONEncoder().encode(dailyUsages) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    func loadStatistics() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([DailyUsage].self, from: data) {
            dailyUsages = decoded
        }
    }
    
    private func cleanOldData() {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -maxDays, to: Date())!
        
        dailyUsages.removeAll { usage in
            usage.date < cutoffDate
        }
    }
    
    // MARK: - 调试
    
    /// 重置所有数据（仅用于测试）
    func resetStatistics() {
        dailyUsages.removeAll()
        saveStatistics()
    }
    
    /// 生成模拟数据（仅用于测试）
    func generateMockData() {
        dailyUsages.removeAll()
        let calendar = Calendar.current
        
        for i in 0..<30 {
            if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
                let randomCount = Int.random(in: 0...20)
                dailyUsages.append(DailyUsage(date: date, openCount: randomCount))
            }
        }
        
        saveStatistics()
    }
}

// MARK: - 使用统计视图（极简版）

struct UsageStatsCard: View {
    @ObservedObject var statsService = UsageStatisticsService.shared
    @State private var hoveredIndex: Int?
    
    var body: some View {
        MinimalLineChart(hoveredIndex: $hoveredIndex)
            .frame(height: 35)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
    }
}

// MARK: - 极简折线图

struct MinimalLineChart: View {
    @Binding var hoveredIndex: Int?
    @ObservedObject var statsService = UsageStatisticsService.shared
    
    private let days = 7
    
    var recentData: [DailyUsage] {
        statsService.getRecentDays(days)
    }
    
    var maxCount: Int {
        max(statsService.getMaxCount(in: days), 1)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // 只显示平滑曲线
                smoothPath(in: geometry.size)
                    .stroke(
                        lineGradient(),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )
                
                // 数据点（悬浮时显示）
                dataPoints(in: geometry.size)
            }
        }
    }
    
    // 根据数据生成渐变（从左到右根据每个点的数值变化）
    private func lineGradient() -> LinearGradient {
        guard !recentData.isEmpty else {
            return LinearGradient(colors: [.blue], startPoint: .leading, endPoint: .trailing)
        }
        
        var colors: [Color] = []
        
        for usage in recentData {
            colors.append(colorForCount(usage.openCount))
        }
        
        // 如果颜色少于2个，补充一个
        if colors.count < 2 {
            colors.append(colors.first ?? .blue)
        }
        
        return LinearGradient(
            colors: colors,
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // 生成平滑曲线路径（使用贝塞尔曲线）
    private func smoothPath(in size: CGSize) -> Path {
        Path { path in
            guard recentData.count >= 2 else { return }
            
            let stepX = size.width / CGFloat(recentData.count - 1)
            var points: [CGPoint] = []
            
            // 收集所有数据点
            for (index, usage) in recentData.enumerated() {
                let x = CGFloat(index) * stepX
                let percentage = CGFloat(usage.openCount) / CGFloat(maxCount)
                let y = size.height * (1 - percentage)
                points.append(CGPoint(x: x, y: y))
            }
            
            // 绘制平滑曲线
            path.move(to: points[0])
            
            for i in 1..<points.count {
                let current = points[i]
                let previous = points[i - 1]
                
                // 计算控制点（创建平滑过渡）
                let controlPointX = (previous.x + current.x) / 2
                
                let controlPoint1 = CGPoint(x: controlPointX, y: previous.y)
                let controlPoint2 = CGPoint(x: controlPointX, y: current.y)
                
                path.addCurve(to: current, control1: controlPoint1, control2: controlPoint2)
            }
        }
    }
    
    // 数据点和悬浮提示
    private func dataPoints(in size: CGSize) -> some View {
        ForEach(Array(recentData.enumerated()), id: \.element.id) { index, usage in
            let stepX = size.width / CGFloat(recentData.count - 1)
            let x = CGFloat(index) * stepX
            let percentage = CGFloat(usage.openCount) / CGFloat(maxCount)
            let y = size.height * (1 - percentage)
            
            ZStack {
                // 数据点（只在悬浮时显示）
                if hoveredIndex == index {
                    Circle()
                        .fill(.white)
                        .frame(width: 8, height: 8)
                        .shadow(color: colorForCount(usage.openCount).opacity(0.6), radius: 6)
                    
                    // 悬浮提示
                    VStack(spacing: 3) {
                        Text("\(usage.openCount) 次")
                            .font(.system(size: 11, weight: .semibold))
                        Text(usage.dateString)
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.black.opacity(0.9))
                            .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
                    )
                    .foregroundColor(.white)
                    .offset(y: -40)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .position(x: x, y: y)
            .contentShape(Rectangle().size(width: max(stepX, 20), height: size.height))
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    hoveredIndex = hovering ? index : nil
                }
            }
        }
    }
    
    // 根据使用量返回颜色
    private func colorForCount(_ count: Int) -> Color {
        switch count {
        case 0: return Color(red: 0.5, green: 0.5, blue: 0.5) // 灰色
        case 1...3: return Color(red: 0.2, green: 0.5, blue: 1.0) // 蓝色
        case 4...6: return Color(red: 0.2, green: 0.8, blue: 0.9) // 青色
        case 7...10: return Color(red: 0.2, green: 0.9, blue: 0.4) // 绿色
        case 11...15: return Color(red: 1.0, green: 0.7, blue: 0.2) // 橙色
        default: return Color(red: 1.0, green: 0.3, blue: 0.3) // 红色
        }
    }
}

// MARK: - 统计徽章

struct StatBadge: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color.gradient)
            
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - 使用图表

struct UsageChart: View {
    let days: Int
    @ObservedObject var statsService = UsageStatisticsService.shared
    
    var recentData: [DailyUsage] {
        statsService.getRecentDays(days)
    }
    
    var maxCount: Int {
        max(statsService.getMaxCount(in: days), 1)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let barWidth = geometry.size.width / CGFloat(recentData.count) - 4
            
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(recentData.enumerated()), id: \.element.id) { index, usage in
                    VStack(spacing: 4) {
                        // 柱状图
                        RoundedRectangle(cornerRadius: 4)
                            .fill(barColor(for: usage.openCount).gradient)
                            .frame(width: barWidth, height: barHeight(for: usage.openCount, maxHeight: geometry.size.height - 30))
                            .overlay(
                                // 显示数值（如果有打开记录）
                                Group {
                                    if usage.openCount > 0 {
                                        Text("\(usage.openCount)")
                                            .font(.system(size: 8, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                }
                            )
                        
                        // 日期标签
                        Text(labelText(for: usage, at: index))
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }
    
    private func barHeight(for count: Int, maxHeight: CGFloat) -> CGFloat {
        guard maxCount > 0 else { return 0 }
        let percentage = CGFloat(count) / CGFloat(maxCount)
        return max(percentage * maxHeight, count > 0 ? 4 : 2) // 最小高度
    }
    
    private func barColor(for count: Int) -> Color {
        switch count {
        case 0: return .gray
        case 1...5: return .blue
        case 6...10: return .green
        case 11...15: return .orange
        default: return .red
        }
    }
    
    private func labelText(for usage: DailyUsage, at index: Int) -> String {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(usage.date)
        
        if isToday {
            return "今天"
        }
        
        // 显示间隔标签（避免拥挤）
        switch days {
        case 7:
            return usage.weekday
        case 14:
            return index % 2 == 0 ? usage.dateString : ""
        case 30:
            return index % 3 == 0 ? usage.dateString : ""
        default:
            return usage.dateString
        }
    }
}

// MARK: - 详细统计视图（可选的独立窗口）

struct UsageStatisticsDetailView: View {
    @ObservedObject var statsService = UsageStatisticsService.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 标题栏
                HStack {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue.gradient)
                    
                    Text("使用统计详情")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Divider()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 概览卡片
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                OverviewCard(
                                    title: "总打开次数",
                                    value: "\(statsService.getTotalCount())",
                                    icon: "sum",
                                    color: .blue
                                )
                                
                                OverviewCard(
                                    title: "平均每日",
                                    value: "\(statsService.getAverageCount())",
                                    icon: "chart.line.uptrend.xyaxis",
                                    color: .green
                                )
                            }
                            
                            HStack(spacing: 16) {
                                OverviewCard(
                                    title: "最高记录",
                                    value: "\(statsService.getMaxCount(in: 30))",
                                    icon: "crown.fill",
                                    color: .orange
                                )
                                
                                OverviewCard(
                                    title: "统计天数",
                                    value: "\(statsService.dailyUsages.count)",
                                    icon: "calendar",
                                    color: .purple
                                )
                            }
                        }
                        
                        // 30天图表
                        VStack(alignment: .leading, spacing: 12) {
                            Text("近30天使用趋势")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            UsageChart(days: 30)
                                .frame(height: 180)
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                        
                        // 每日列表
                        VStack(alignment: .leading, spacing: 12) {
                            Text("详细记录")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            ForEach(statsService.getRecentDays(30)) { usage in
                                DailyUsageRow(usage: usage)
                            }
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 420, height: 600)
        .focusable(false)
    }
}

// MARK: - 概览卡片

struct OverviewCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color.gradient)
            
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - 每日使用行

struct DailyUsageRow: View {
    let usage: DailyUsage
    
    var isToday: Bool {
        Calendar.current.isDateInToday(usage.date)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(usage.dateString)
                        .font(.system(size: 13, weight: .medium))
                    
                    if isToday {
                        Text("今天")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.blue.opacity(0.2)))
                    }
                }
                
                Text(usage.weekday)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Text("\(usage.openCount)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("次")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(isToday ? Color.blue.opacity(0.05) : Color.clear)
        .cornerRadius(8)
    }
}

#Preview {
    UsageStatsCard()
        .frame(width: 380)
        .padding()
        .background(Color.black.opacity(0.9))
}
