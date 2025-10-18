import SwiftUI

// MARK: - 金币记录悬浮窗
struct CoinHistoryPopover: View {
    @ObservedObject var historyManager = CoinHistoryManager.shared
    
    var body: some View {
        ZStack {
            // 统一的模糊背景
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 标题栏
                headerView
                
                Divider()
                    .padding(.horizontal, 12)
                
                // 实时收入显示（固定在顶部）
                HStack(spacing: 8) {
                    // 动态图标
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                    }
                    
                    // 描述
                    VStack(alignment: .leading, spacing: 2) {
                        Text("每秒收入")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("持续增长中...")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // 实时金额
                    Text("+\(String(format: "%.3f", historyManager.getCurrentHourIncome()))")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.green)
                        .monospacedDigit()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.green.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.green.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 12)
                .padding(.top, 8)
                
                Divider()
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                
                // 内容区域 - 所有记录混合显示
                ScrollView {
                    VStack(spacing: 6) {
                        let allRecords = getAllRecordsSorted()
                        
                        if allRecords.isEmpty {
                            emptyView
                        } else {
                            ForEach(allRecords) { record in
                                RecordRow(record: record)
                            }
                        }
                    }
                    .padding(12)
                }
                .frame(maxHeight: 300)
            }
        }
        .frame(width: 320)
        .focusable(false)
    }
    
    // MARK: - 标题栏
    private var headerView: some View {
        HStack(spacing: 8) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(.yellow)
            
            Text("金币记录")
                .font(.system(size: 13, weight: .semibold))
            
            Spacer()
            
            Text("余额: \(String(format: "%.3f", getCurrentBalance()))")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
    
    // MARK: - 实时收入显示
    @available(macOS 14.0, *)
    private var realtimeIncomeView: some View {
        HStack(spacing: 8) {
            // 动态图标
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.green)
                    .symbolEffect(.pulse, options: .repeating)
            }
            
            // 描述
            VStack(alignment: .leading, spacing: 2) {
                Text("每秒收入")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("持续增长中...")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 实时金额
            Text("+\(String(format: "%.3f", historyManager.getCurrentHourIncome()))")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.green)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.green.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - 空状态视图
    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("暂无记录")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - 辅助方法
    
    /// 获取所有记录并按时间排序（最新的在前）
    private func getAllRecordsSorted() -> [CombinedRecord] {
        var combined: [CombinedRecord] = []
        
        // 添加每小时收入记录
        for hourly in historyManager.getRecentHourlyIncome(limit: 20) {
            combined.append(.hourly(hourly))
        }
        
        // 添加操作记录
        for operation in historyManager.getRecentRecords(limit: 30) {
            combined.append(.operation(operation))
        }
        
        // 按时间倒序排序
        return combined.sorted { $0.timestamp > $1.timestamp }
    }
    
    private func getCurrentBalance() -> Double {
        return historyManager.records.first?.balance ?? 0
    }
}

// MARK: - 组合记录类型
enum CombinedRecord: Identifiable {
    case hourly(HourlyIncomeRecord)
    case operation(CoinRecord)
    
    var id: String {
        switch self {
        case .hourly(let record): return "h_\(record.id)"
        case .operation(let record): return "o_\(record.id)"
        }
    }
    
    var timestamp: Date {
        switch self {
        case .hourly(let record): return record.hour
        case .operation(let record): return record.timestamp
        }
    }
}

// MARK: - 统一记录行
struct RecordRow: View {
    let record: CombinedRecord
    
    var body: some View {
        switch record {
        case .hourly(let hourly):
            HourlyRow(record: hourly)
        case .operation(let operation):
            OperationRow(record: operation)
        }
    }
}

// MARK: - 每小时收入行
struct HourlyRow: View {
    let record: HourlyIncomeRecord
    
    var body: some View {
        HStack(spacing: 8) {
            // 时间图标
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 28, height: 28)
                
                Image(systemName: "clock.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.green)
            }
            
            // 时间和描述
            VStack(alignment: .leading, spacing: 2) {
                Text("自动收入")
                    .font(.system(size: 11, weight: .medium))
                
                Text(record.formattedDate)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 金额
            Text("+\(String(format: "%.3f", record.totalIncome))")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.green)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - 操作记录行
struct OperationRow: View {
    let record: CoinRecord
    
    var body: some View {
        HStack(spacing: 8) {
            // 类型图标
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 28, height: 28)
                
                Image(systemName: record.type.icon)
                    .font(.system(size: 12))
                    .foregroundColor(iconColor)
            }
            
            // 描述和时间
            VStack(alignment: .leading, spacing: 2) {
                Text(record.description)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                
                Text(record.formattedDate)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 金额
            VStack(alignment: .trailing, spacing: 2) {
                Text(record.formattedAmount)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(amountColor)
                    .monospacedDigit()
                
                Text("余额: \(String(format: "%.1f", record.balance))")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.7))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private var iconColor: Color {
        switch record.type {
        case .income: return .green
        case .expense: return .red
        case .reward: return .yellow
        }
    }
    
    private var amountColor: Color {
        record.type == .expense ? .red : .green
    }
}

#Preview {
    CoinHistoryPopover()
        .frame(width: 320, height: 400)
}
