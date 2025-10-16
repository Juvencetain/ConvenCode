import SwiftUI

// MARK: - Main View
struct DateCalculatorView: View {
    @StateObject private var viewModel = DateCalculatorViewModel()
    @Namespace private var animation
    
    var body: some View {
        ZStack {
            // 背景
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部栏
                dateToolHeaderBar
                Divider().padding(.horizontal, 20)
                
                // 模式选择器
                dateToolModeSelector
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                
                // 主内容区域
                ScrollView {
                    VStack(spacing: 20) {
                        // 根据模式显示不同的视图
                        Group {
                            switch viewModel.dateToolCalculationMode {
                            case .difference:
                                dateToolDifferenceView
                            case .addSubtract:
                                dateToolAddSubtractView
                            case .ageCalculator:
                                dateToolAgeCalculatorView
                            case .weekdayInfo:
                                dateToolWeekdayInfoView
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    }
                    .padding(20)
                }
            }
            
            // 复制成功提示
            if viewModel.dateToolShowCopyFeedback {
                dateToolCopyFeedbackView
            }
        }
        .frame(width: 480, height: 680)
        .focusable(false)
    }
    
    // MARK: - Header Bar
    
    private var dateToolHeaderBar: some View {
        HStack {
            Image(systemName: viewModel.dateToolCalculationMode.icon)
                .font(.system(size: 16))
                .foregroundStyle(.cyan.gradient)
            
            Text("日期计算器")
                .font(.system(size: 14, weight: .medium))
            
            Spacer()
            
            // 历史记录按钮
            Button(action: { viewModel.dateToolShowHistory.toggle() }) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $viewModel.dateToolShowHistory) {
                dateToolHistoryView
            }
        }
        .padding(20)
    }
    
    // MARK: - Mode Selector
    
    private var dateToolModeSelector: some View {
        HStack(spacing: 8) {
            ForEach(DateCalculatorViewModel.CalculationMode.allCases) { mode in
                dateToolModeButton(mode)
            }
        }
    }
    
    private func dateToolModeButton(_ mode: DateCalculatorViewModel.CalculationMode) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.dateToolCalculationMode = mode
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: mode.icon)
                    .font(.system(size: 16))
                Text(mode.rawValue)
                    .font(.system(size: 10, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    if viewModel.dateToolCalculationMode == mode {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.cyan.opacity(0.2))
                            .matchedGeometryEffect(id: "selector", in: animation)
                    }
                }
            )
            .foregroundColor(viewModel.dateToolCalculationMode == mode ? .cyan : .secondary)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Date Difference View
    
    private var dateToolDifferenceView: some View {
        VStack(spacing: 16) {
            // 日期选择卡片
            VStack(alignment: .leading, spacing: 12) {
                Text("日期范围").dateToolSectionHeader()
                
                // 开始日期
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.cyan)
                        .frame(width: 20)
                    Text("开始")
                        .frame(width: 40, alignment: .leading)
                    DatePicker("", selection: $viewModel.dateToolStartDate, displayedComponents: viewModel.dateToolIncludeTime ? [.date, .hourAndMinute] : [.date])
                        .labelsHidden()
                }
                
                // 结束日期
                HStack {
                    Image(systemName: "calendar.badge.checkmark")
                        .foregroundColor(.cyan)
                        .frame(width: 20)
                    Text("结束")
                        .frame(width: 40, alignment: .leading)
                    DatePicker("", selection: $viewModel.dateToolEndDate, displayedComponents: viewModel.dateToolIncludeTime ? [.date, .hourAndMinute] : [.date])
                        .labelsHidden()
                }
                
                Divider()
                
                // 选项
                VStack(spacing: 8) {
                    Toggle(isOn: $viewModel.dateToolIncludeTime) {
                        Label("包含时间", systemImage: "clock")
                            .font(.system(size: 12))
                    }
                    .toggleStyle(.switch)
                    
                    Toggle(isOn: $viewModel.dateToolExcludeWeekends) {
                        Label("计算工作日", systemImage: "briefcase")
                            .font(.system(size: 12))
                    }
                    .toggleStyle(.switch)
                }
                
                // 快捷按钮
                VStack(spacing: 8) {
                    HStack {
                        Button(action: viewModel.dateToolSwapDates) {
                            Label("交换", systemImage: "arrow.left.arrow.right")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(DateToolButtonStyle(style: .normal))
                        
                        Button(action: viewModel.dateToolSetToday) {
                            Label("今天", systemImage: "calendar.badge.checkmark")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(DateToolButtonStyle(style: .accent))
                    }
                    
                    // 快速时间间隔
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(DateToolQuickInterval.allCases, id: \.self) { interval in
                                Button(interval.rawValue) {
                                    viewModel.dateToolSetQuickInterval(interval)
                                }
                                .buttonStyle(DateToolButtonStyle(style: .compact))
                                .font(.system(size: 11))
                            }
                        }
                    }
                }
            }
            .dateToolCard()
            
            // 结果显示卡片
            dateToolDifferenceResultCard
        }
    }
    
    private var dateToolDifferenceResultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("时间差结果").dateToolSectionHeader()
                Spacer()
                Button(action: {
                    let result = viewModel.dateToolDifferenceResult
                    let text = "\(result.years)年\(result.months)月\(result.days)天"
                    viewModel.dateToolCopyResult(text)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundColor(.cyan)
                }
                .buttonStyle(.plain)
            }
            
            let result = viewModel.dateToolDifferenceResult
            
            // 主要显示（年月日）
            if result.isNegative {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("结束日期早于开始日期")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(spacing: 10) {
                dateToolResultRow(
                    icon: "calendar.badge.exclamationmark",
                    label: "年 月 天",
                    value: "\(abs(result.years)) 年 \(abs(result.months)) 月 \(abs(result.days)) 天",
                    color: .cyan
                )
                
                if viewModel.dateToolIncludeTime {
                    dateToolResultRow(
                        icon: "clock",
                        label: "时 分 秒",
                        value: "\(abs(result.hours)) 时 \(abs(result.minutes)) 分 \(abs(result.seconds)) 秒",
                        color: .cyan
                    )
                }
                
                Divider()
                
                // 详细统计
                Group {
                    dateToolResultRow(
                        icon: "number.circle",
                        label: "总天数",
                        value: "\(abs(result.totalDays)) 天"
                    )
                    
                    dateToolResultRow(
                        icon: "calendar.circle",
                        label: "总周数",
                        value: String(format: "%.2f 周", abs(result.totalWeeks))
                    )
                    
                    dateToolResultRow(
                        icon: "calendar.badge.clock",
                        label: "总月数",
                        value: String(format: "%.2f 个月", abs(result.totalMonths))
                    )
                    
                    if viewModel.dateToolIncludeTime {
                        dateToolResultRow(
                            icon: "hourglass",
                            label: "总小时",
                            value: String(format: "%.0f 小时", abs(result.totalHours))
                        )
                        
                        dateToolResultRow(
                            icon: "timer",
                            label: "总分钟",
                            value: String(format: "%.0f 分钟", abs(result.totalMinutes))
                        )
                    }
                    
                    if viewModel.dateToolExcludeWeekends && result.workdays > 0 {
                        dateToolResultRow(
                            icon: "briefcase",
                            label: "工作日",
                            value: "\(result.workdays) 天",
                            color: .orange
                        )
                    }
                }
            }
        }
        .dateToolCard()
    }
    
    // MARK: - Add/Subtract View
    
    private var dateToolAddSubtractView: some View {
        VStack(spacing: 16) {
            // 输入卡片
            VStack(alignment: .leading, spacing: 12) {
                Text("日期计算").dateToolSectionHeader()
                
                // 基准日期
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.cyan)
                        .frame(width: 20)
                    Text("基准")
                        .frame(width: 40, alignment: .leading)
                    DatePicker("", selection: $viewModel.dateToolBaseDate, displayedComponents: .date)
                        .labelsHidden()
                }
                
                Divider()
                
                // 操作选择
                HStack(spacing: 12) {
                    // 加减切换
                    Picker("", selection: $viewModel.dateToolIsAdding) {
                        Label("加", systemImage: "plus.circle.fill").tag(true)
                        Label("减", systemImage: "minus.circle.fill").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                    
                    // 数值输入
                    TextField("", value: $viewModel.dateToolValueToAdd, formatter: NumberFormatter())
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                        .frame(width: 60)
                    
                    // 单位选择
                    Picker("", selection: $viewModel.dateToolSelectedUnit) {
                        ForEach(viewModel.dateToolUnits) { unit in
                            Label(unit.name, systemImage: unit.icon).tag(unit.unit)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // 快捷按钮
                HStack {
                    Button(action: viewModel.dateToolSetToday) {
                        Label("设为今天", systemImage: "calendar.badge.checkmark")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(DateToolButtonStyle(style: .accent))
                    .frame(maxWidth: .infinity)
                }
            }
            .dateToolCard()
            
            // 结果卡片
            dateToolAddSubtractResultCard
        }
    }
    
    private var dateToolAddSubtractResultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("计算结果").dateToolSectionHeader()
                Spacer()
                Button(action: {
                    viewModel.dateToolCopyResult(viewModel.dateToolAddSubtractResult.formattedDate)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundColor(.cyan)
                }
                .buttonStyle(.plain)
            }
            
            let result = viewModel.dateToolAddSubtractResult
            
            // 主结果
            VStack(spacing: 8) {
                Text(result.formattedDate)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.cyan.gradient)
                    .multilineTextAlignment(.center)
                
                if result.isWeekend {
                    HStack {
                        Image(systemName: "moon.stars")
                        Text("周末")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            
            Divider()
            
            // 详细信息
            VStack(spacing: 8) {
                dateToolResultRow(
                    icon: "calendar.day.timeline.left",
                    label: "星期",
                    value: result.dayOfWeek
                )
                
                dateToolResultRow(
                    icon: "number.circle",
                    label: "年度第几天",
                    value: "第 \(result.dayOfYear) 天"
                )
                
                dateToolResultRow(
                    icon: "calendar.circle",
                    label: "年度第几周",
                    value: "第 \(result.weekOfYear) 周"
                )
            }
        }
        .dateToolCard()
    }
    
    // MARK: - Age Calculator View
    
    private var dateToolAgeCalculatorView: some View {
        VStack(spacing: 16) {
            // 输入卡片
            VStack(alignment: .leading, spacing: 12) {
                Text("年龄计算").dateToolSectionHeader()
                
                // 出生日期
                HStack {
                    Image(systemName: "gift")
                        .foregroundColor(.cyan)
                        .frame(width: 20)
                    Text("出生")
                        .frame(width: 50, alignment: .leading)
                    DatePicker("", selection: $viewModel.dateToolBirthDate, displayedComponents: .date)
                        .labelsHidden()
                }
                
                // 目标日期
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.cyan)
                        .frame(width: 20)
                    Text("计算至")
                        .frame(width: 50, alignment: .leading)
                    DatePicker("", selection: $viewModel.dateToolTargetDate, displayedComponents: .date)
                        .labelsHidden()
                }
                
                Button(action: viewModel.dateToolSetToday) {
                    Label("设为今天", systemImage: "calendar.badge.checkmark")
                        .font(.system(size: 12))
                }
                .buttonStyle(DateToolButtonStyle(style: .accent))
                .frame(maxWidth: .infinity)
            }
            .dateToolCard()
            
            // 结果卡片
            dateToolAgeResultCard
        }
    }
    
    private var dateToolAgeResultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("年龄信息").dateToolSectionHeader()
                Spacer()
                Button(action: {
                    let result = viewModel.dateToolAgeResult
                    let text = "\(result.years)岁\(result.months)月\(result.days)天"
                    viewModel.dateToolCopyResult(text)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundColor(.cyan)
                }
                .buttonStyle(.plain)
            }
            
            let result = viewModel.dateToolAgeResult
            
            // 主要年龄显示
            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(result.years)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.cyan.gradient)
                    Text("岁")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Text("\(result.months) 个月 \(result.days) 天")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            
            Divider()
            
            // 详细统计
            VStack(spacing: 8) {
                dateToolResultRow(
                    icon: "number.circle",
                    label: "总天数",
                    value: "\(result.totalDays) 天"
                )
                
                dateToolResultRow(
                    icon: "calendar.circle",
                    label: "总周数",
                    value: String(format: "%.1f 周", result.totalWeeks)
                )
                
                dateToolResultRow(
                    icon: "calendar.badge.clock",
                    label: "总月数",
                    value: "\(result.totalMonths) 个月"
                )
                
                Divider()
                
                dateToolResultRow(
                    icon: "birthday.cake",
                    label: "下次生日",
                    value: "\(result.daysUntilNextBirthday) 天后",
                    color: .orange
                )
                
                dateToolResultRow(
                    icon: "star.circle",
                    label: "星座",
                    value: result.zodiacSign
                )
                
                dateToolResultRow(
                    icon: "pawprint.circle",
                    label: "生肖",
                    value: result.chineseZodiac
                )
            }
        }
        .dateToolCard()
    }
    
    // MARK: - Weekday Info View
    
    private var dateToolWeekdayInfoView: some View {
        VStack(spacing: 16) {
            // 日期选择卡片
            VStack(alignment: .leading, spacing: 12) {
                Text("选择日期").dateToolSectionHeader()
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.cyan)
                        .frame(width: 20)
                    Text("日期")
                        .frame(width: 40, alignment: .leading)
                    DatePicker("", selection: $viewModel.dateToolInfoDate, displayedComponents: .date)
                        .labelsHidden()
                }
                
                Button(action: viewModel.dateToolSetToday) {
                    Label("设为今天", systemImage: "calendar.badge.checkmark")
                        .font(.system(size: 12))
                }
                .buttonStyle(DateToolButtonStyle(style: .accent))
                .frame(maxWidth: .infinity)
            }
            .dateToolCard()
            
            // 信息卡片
            dateToolInfoResultCard
        }
    }
    
    private var dateToolInfoResultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("日期信息").dateToolSectionHeader()
            
            let result = viewModel.dateToolInfoResult
            
            // 星期显示
            VStack(spacing: 8) {
                Text(result.weekdayName)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.cyan.gradient)
                
                if result.isWeekend {
                    HStack {
                        Image(systemName: "moon.stars")
                        Text("周末")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            
            Divider()
            
            // 详细信息
            VStack(spacing: 8) {
                dateToolResultRow(
                    icon: "calendar.day.timeline.left",
                    label: "星期",
                    value: "星期\(["日", "一", "二", "三", "四", "五", "六"][result.weekday - 1])"
                )
                
                dateToolResultRow(
                    icon: "number.circle",
                    label: "年度第几天",
                    value: "第 \(result.dayOfYear) 天 / \(result.daysInYear) 天"
                )
                
                dateToolResultRow(
                    icon: "calendar.circle",
                    label: "年度第几周",
                    value: "第 \(result.weekOfYear) 周"
                )
                
                dateToolResultRow(
                    icon: "calendar.badge.clock",
                    label: "月度第几周",
                    value: "第 \(result.weekOfMonth) 周"
                )
                
                dateToolResultRow(
                    icon: "chart.bar",
                    label: "季度",
                    value: "第 \(result.quarter) 季度"
                )
                
                dateToolResultRow(
                    icon: "calendar.badge.plus",
                    label: "本月天数",
                    value: "\(result.daysInMonth) 天"
                )
                
                Divider()
                
                dateToolResultRow(
                    icon: result.isLeapYear ? "sparkles" : "calendar",
                    label: "闰年",
                    value: result.isLeapYear ? "是（366天）" : "否（365天）",
                    color: result.isLeapYear ? .orange : .secondary
                )
                
                dateToolResultRow(
                    icon: "star.circle",
                    label: "星座",
                    value: result.zodiacSign
                )
                
                dateToolResultRow(
                    icon: "pawprint.circle",
                    label: "生肖",
                    value: result.chineseZodiac
                )
            }
        }
        .dateToolCard()
    }
    
    // MARK: - History View
    
    private var dateToolHistoryView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("历史记录")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                if !viewModel.dateToolHistory.isEmpty {
                    Button("清空", action: viewModel.dateToolClearHistory)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            if viewModel.dateToolHistory.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("暂无历史记录")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(viewModel.dateToolHistory) { item in
                            dateToolHistoryItem(item)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 300)
            }
        }
        .frame(width: 320)
        .padding(.bottom)
    }
    
    private func dateToolHistoryItem(_ item: DateCalculatorViewModel.DateToolHistoryItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: item.mode.icon)
                    .font(.system(size: 10))
                Text(item.mode.rawValue)
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Text(item.timestamp, style: .time)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Text(item.description)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Text(item.result)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.cyan)
        }
        .padding(8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(6)
    }
    
    // MARK: - Copy Feedback View
    
    private var dateToolCopyFeedbackView: some View {
        VStack {
            Spacer()
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("已复制到剪贴板")
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.8))
            .cornerRadius(20)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .padding(.bottom, 20)
        .animation(.spring(), value: viewModel.dateToolShowCopyFeedback)
    }
    
    // MARK: - Helper Views
    
    private func dateToolResultRow(icon: String, label: String, value: String, color: Color = .secondary) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(color == .secondary ? .primary : color)
        }
    }
}

// MARK: - Custom Styles

private extension Text {
    func dateToolSectionHeader() -> some View {
        self
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
    }
}

private extension View {
    func dateToolCard() -> some View {
        self
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
    }
}

// MARK: - Custom Button Style

struct DateToolButtonStyle: ButtonStyle {
    enum Style {
        case normal
        case accent
        case compact
    }
    
    let style: Style
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, style == .compact ? 8 : 12)
            .padding(.vertical, style == .compact ? 4 : 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor(configuration.isPressed))
            )
            .foregroundColor(foregroundColor)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
    
    private func backgroundColor(_ isPressed: Bool) -> Color {
        switch style {
        case .normal:
            return Color.white.opacity(isPressed ? 0.15 : 0.1)
        case .accent:
            return Color.cyan.opacity(isPressed ? 0.3 : 0.2)
        case .compact:
            return Color.white.opacity(isPressed ? 0.2 : 0.08)
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .normal:
            return .primary
        case .accent:
            return .cyan
        case .compact:
            return .secondary
        }
    }
}

// MARK: - Preview

#Preview {
    DateCalculatorView()
}
