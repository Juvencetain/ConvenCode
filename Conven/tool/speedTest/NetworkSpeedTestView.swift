import SwiftUI

// MARK: - 网络测速主视图
struct NetworkSpeedTestView: View {
    @StateObject private var speedTestViewModel = NetworkSpeedTestViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(1)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                speedTestTopBar
                Divider()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // 速度显示区域
                        speedTestMainSpeedDisplay
                        
                        // 测试按钮
                        speedTestActionButtons
                        
                        // 详细指标
                        if speedTestViewModel.speedTestIsRunning || speedTestViewModel.speedTestProgress > 0 {
                            speedTestMetricsSection
                        }
                        
                        // 历史记录
                        speedTestHistorySection
                        
                        Spacer(minLength: 20)
                    }
                    .padding(24)
                }
            }
        }
        .frame(width: 420, height: 680)
        .focusable(false)
        .overlay(alignment: .top) {
            if speedTestViewModel.speedTestShowToast {
                speedTestToastView
            }
        }
    }
    
    // MARK: - 顶部栏
    
    private var speedTestTopBar: some View {
        HStack {
            Image(systemName: "speedometer")
                .font(.system(size: 16))
                .foregroundStyle(.blue.gradient)
            
            Text("网络测速")
                .font(.system(size: 16, weight: .semibold))
            
            Spacer()
            
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .speedTestCursor()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
    
    // MARK: - 主速度显示
    
    private var speedTestMainSpeedDisplay: some View {
        VStack(spacing: 20) {
            ZStack {
                // 背景圆环
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 180, height: 180)
                
                // 进度圆环
                Circle()
                    .trim(from: 0, to: speedTestViewModel.speedTestProgress)
                    .stroke(
                        speedTestViewModel.speedTestCurrentType.speedTestColor.gradient,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.3), value: speedTestViewModel.speedTestProgress)
                
                // 中心内容
                if speedTestViewModel.speedTestIsRunning {
                    // 显示停止按钮（居中）
                    Button(action: {
                        withAnimation {
                            speedTestViewModel.speedTestStop()
                        }
                    }) {
                        VStack(spacing: 6) {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 52))
                                .foregroundStyle(.red.gradient)
                            
                            Text("停止")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.red)
                        }
                    }
                    .buttonStyle(.plain)
                    .speedTestCursor()
                    .frame(width: 180, height: 180) // 关键：确保占满整个圆形区域
                    .transition(.scale.combined(with: .opacity))
                } else {
                    // 显示速度信息（居中）
                    VStack(spacing: 8) {
                        // 主速度显示（MB/s 格式）
                        Text(speedTestViewModel.speedTestFormattedCurrentSpeedMBps)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(speedTestViewModel.speedTestCurrentType.speedTestColor.gradient)
                        
                        // 副速度显示（Mbps 格式）
                        Text(speedTestViewModel.speedTestFormattedCurrentSpeed)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Text(speedTestStatusText)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 180, height: 180) // 关键：确保占满整个圆形区域
                }
            }
            
            // 进度百分比
            if speedTestViewModel.speedTestIsRunning {
                VStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Text("\(Int(speedTestViewModel.speedTestProgress * 100))%")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                        Text("已完成")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.secondary)
                    
                    // 实时速度显示
                    if speedTestViewModel.speedTestCurrentSpeed > 0 {
                        HStack(spacing: 8) {
                            Text(speedTestViewModel.speedTestFormattedCurrentSpeedMBps)
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundStyle(speedTestViewModel.speedTestCurrentType.speedTestColor.gradient)
                            
                            Text(speedTestViewModel.speedTestFormattedCurrentSpeed)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // 最终结论显示
            if speedTestViewModel.speedTestShowResult {
                speedTestResultCard
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(24)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private var speedTestStatusText: String {
        switch speedTestViewModel.speedTestStatus {
        case .idle:
            return "准备就绪"
        case .testing:
            return "测试中..."
        case .completed:
            return "测试完成"
        case .failed(let message):
            return message
        }
    }
    
    // MARK: - 结论卡片
    
    private var speedTestResultCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.green.gradient)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("测试完成")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Text(speedTestViewModel.speedTestFinalResult)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - 测试按钮
    
    private var speedTestActionButtons: some View {
        HStack(spacing: 12) {
            SpeedTestTypeButton(
                speedTestType: .download,
                speedTestIsRunning: speedTestViewModel.speedTestIsRunning,
                speedTestIsSelected: speedTestViewModel.speedTestCurrentType == .download
            ) {
                speedTestViewModel.speedTestStart(.download)
            }
            
            SpeedTestTypeButton(
                speedTestType: .upload,
                speedTestIsRunning: speedTestViewModel.speedTestIsRunning,
                speedTestIsSelected: speedTestViewModel.speedTestCurrentType == .upload
            ) {
                speedTestViewModel.speedTestStart(.upload)
            }
            
            SpeedTestTypeButton(
                speedTestType: .ping,
                speedTestIsRunning: speedTestViewModel.speedTestIsRunning,
                speedTestIsSelected: speedTestViewModel.speedTestCurrentType == .ping
            ) {
                speedTestViewModel.speedTestStart(.ping)
            }
        }
    }
    
    // MARK: - 详细指标
    
    private var speedTestMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("测试指标")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 10) {
                SpeedTestMetricRow(
                    speedTestLabel: "当前速度",
                    speedTestValue: speedTestViewModel.speedTestFormattedCurrentSpeedMBps,
                    speedTestSubValue: speedTestViewModel.speedTestFormattedCurrentSpeed,
                    speedTestIcon: "speedometer",
                    speedTestColor: .blue
                )
                
                SpeedTestMetricRow(
                    speedTestLabel: "峰值速度",
                    speedTestValue: NetworkSpeedFormatter.formatSpeedMBps(speedTestViewModel.speedTestPeakSpeed),
                    speedTestSubValue: speedTestViewModel.speedTestFormattedPeakSpeed,
                    speedTestIcon: "arrow.up.circle.fill",
                    speedTestColor: .orange
                )
                
                SpeedTestMetricRow(
                    speedTestLabel: "平均速度",
                    speedTestValue: speedTestViewModel.speedTestFormattedAverageSpeedMBps,
                    speedTestSubValue: speedTestViewModel.speedTestFormattedAverageSpeed,
                    speedTestIcon: "chart.line.uptrend.xyaxis.circle.fill",
                    speedTestColor: .green
                )
                
                SpeedTestMetricRow(
                    speedTestLabel: "传输量",
                    speedTestValue: speedTestViewModel.speedTestFormattedBytesTransferred,
                    speedTestSubValue: nil,
                    speedTestIcon: "externaldrive.fill",
                    speedTestColor: .purple
                )
                
                SpeedTestMetricRow(
                    speedTestLabel: "用时",
                    speedTestValue: String(format: "%.1f 秒", speedTestViewModel.speedTestDuration),
                    speedTestSubValue: nil,
                    speedTestIcon: "clock.fill",
                    speedTestColor: .cyan
                )
                
                if speedTestViewModel.speedTestCurrentPing > 0 {
                    SpeedTestMetricRow(
                        speedTestLabel: "延迟",
                        speedTestValue: speedTestViewModel.speedTestFormattedPing,
                        speedTestSubValue: nil,
                        speedTestIcon: "timer",
                        speedTestColor: .orange
                    )
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // MARK: - 历史记录
    
    private var speedTestHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("测试记录")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !speedTestViewModel.speedTestHistory.isEmpty {
                    Button(action: {
                        speedTestViewModel.speedTestClearHistory()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                            Text("清空")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .speedTestCursor()
                }
            }
            
            if speedTestViewModel.speedTestHistory.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    
                    Text("暂无测试记录")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                VStack(spacing: 8) {
                    ForEach(speedTestViewModel.speedTestHistory.prefix(5)) { result in
                        SpeedTestHistoryCard(
                            speedTestResult: result,
                            speedTestOnDelete: {
                                speedTestViewModel.speedTestDeleteHistoryItem(result)
                            }
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Toast
    
    private var speedTestToastView: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
            Text(speedTestViewModel.speedTestToastMessage)
                .font(.system(size: 12))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.blue)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
        .padding(.top, 70)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3).delay(2)) {
                speedTestViewModel.speedTestShowToast = false
            }
        }
    }
}

// MARK: - 测试类型按钮
struct SpeedTestTypeButton: View {
    let speedTestType: NetworkSpeedTestType
    let speedTestIsRunning: Bool
    let speedTestIsSelected: Bool
    let speedTestAction: () -> Void
    
    @State private var speedTestIsHovered = false
    
    var body: some View {
        Button(action: speedTestAction) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(speedTestType.speedTestColor.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: speedTestType.speedTestIcon)
                        .font(.system(size: 24))
                        .foregroundStyle(speedTestType.speedTestColor.gradient)
                }
                
                Text(speedTestType.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        speedTestIsSelected && speedTestIsRunning ?
                        speedTestType.speedTestColor.opacity(0.15) :
                        (speedTestIsHovered ? Color.white.opacity(0.08) : Color.white.opacity(0.05))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        speedTestIsSelected && speedTestIsRunning ?
                        speedTestType.speedTestColor.opacity(0.5) : Color.clear,
                        lineWidth: 2
                    )
            )
            .opacity(speedTestIsRunning ? 0.5 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(speedTestIsRunning)
        .onHover { hovering in
            if !speedTestIsRunning {
                speedTestIsHovered = hovering
            }
        }
        .speedTestCursor()
    }
}

// MARK: - 指标行
struct SpeedTestMetricRow: View {
    let speedTestLabel: String
    let speedTestValue: String
    let speedTestSubValue: String?
    let speedTestIcon: String
    let speedTestColor: Color
    
    init(speedTestLabel: String, speedTestValue: String, speedTestSubValue: String? = nil, speedTestIcon: String, speedTestColor: Color) {
        self.speedTestLabel = speedTestLabel
        self.speedTestValue = speedTestValue
        self.speedTestSubValue = speedTestSubValue
        self.speedTestIcon = speedTestIcon
        self.speedTestColor = speedTestColor
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: speedTestIcon)
                .font(.system(size: 16))
                .foregroundStyle(speedTestColor.gradient)
                .frame(width: 24)
            
            Text(speedTestLabel)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(speedTestValue)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary)
                
                if let subValue = speedTestSubValue {
                    Text(subValue)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - 历史记录卡片
struct SpeedTestHistoryCard: View {
    let speedTestResult: NetworkSpeedTestResult
    let speedTestOnDelete: () -> Void
    
    @State private var speedTestIsHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 类型图标
            ZStack {
                Circle()
                    .fill(speedTestResult.speedTestType.speedTestColor.opacity(0.2))
                    .frame(width: 36, height: 36)
                
                Image(systemName: speedTestResult.speedTestType.speedTestIcon)
                    .font(.system(size: 16))
                    .foregroundStyle(speedTestResult.speedTestType.speedTestColor.gradient)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(speedTestResult.speedTestType.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    if speedTestResult.speedTestDownloadSpeed > 0 {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("↓ \(speedTestResult.speedTestFormattedDownloadSpeedMBps)")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.primary)
                            Text(speedTestResult.speedTestFormattedDownloadSpeed)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if speedTestResult.speedTestUploadSpeed > 0 {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("↑ \(speedTestResult.speedTestFormattedUploadSpeedMBps)")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.primary)
                            Text(speedTestResult.speedTestFormattedUploadSpeed)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if speedTestResult.speedTestPing > 0 {
                        Text(speedTestResult.speedTestFormattedPing)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(speedTestFormatDate(speedTestResult.speedTestDate))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                if speedTestIsHovered {
                    Button(action: speedTestOnDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .speedTestCursor()
                    .transition(.opacity)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(speedTestIsHovered ? Color.white.opacity(0.08) : Color.white.opacity(0.05))
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                speedTestIsHovered = hovering
            }
        }
    }
    
    private func speedTestFormatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 辅助扩展
extension View {
    func speedTestCursor() -> some View {
        self.onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

#Preview {
    NetworkSpeedTestView()
}
