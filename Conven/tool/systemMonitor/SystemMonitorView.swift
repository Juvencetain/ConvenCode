import SwiftUI
import Charts

// MARK: - SystemMonitor View
struct SystemMonitorView: View {
    @StateObject private var systemMonitorViewModel = SystemMonitorViewModel()
    
    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.3),
                    Color.blue.opacity(0.1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                systemMonitorHeaderSection
                Divider().padding(.horizontal, 16)
                
                ScrollView {
                    VStack(spacing: 16) {
                        systemMonitorCPUSection
                        systemMonitorMemorySection
                        systemMonitorDiskSection
                        systemMonitorNetworkSection
                        systemMonitorProcessSection
                        systemMonitorSystemInfoSection
                    }
                    .padding(20)
                }
            }
        }
        .focusable(false)
        .frame(width: 500, height: 720)
        .onAppear {
            systemMonitorViewModel.startMonitoring()
        }
        .onDisappear {
            systemMonitorViewModel.stopMonitoring()
        }
    }
    
    // MARK: - Header Section
    private var systemMonitorHeaderSection: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "gauge.high")
                    .font(.system(size: 16))
                    .foregroundStyle(.blue.gradient)
            }
            .rotationEffect(.degrees(systemMonitorViewModel.systemMonitorIsRefreshing ? 360 : 0))
            .animation(systemMonitorViewModel.systemMonitorIsRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: systemMonitorViewModel.systemMonitorIsRefreshing)
            
            Text("系统监控")
                .font(.system(size: 16, weight: .semibold))
            
            Spacer()
            
            // 状态指示器
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .opacity(systemMonitorViewModel.systemMonitorIsMonitoring ? 1 : 0.3)
                    .scaleEffect(systemMonitorViewModel.systemMonitorIsMonitoring ? 1 : 0.8)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: systemMonitorViewModel.systemMonitorIsMonitoring)
                
                Text("实时")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            // 刷新按钮
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    systemMonitorViewModel.refreshSystemMonitorData()
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
    
    // MARK: - CPU Section
    private var systemMonitorCPUSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "cpu")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue.gradient)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("CPU")
                        .font(.system(size: 14, weight: .semibold))
                    Text("\(systemMonitorViewModel.systemMonitorCPUCores) 核心 · \(systemMonitorViewModel.systemMonitorCPUThreads) 线程")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(systemMonitorViewModel.systemMonitorCPUUsage))%")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(systemMonitorColorForPercentage(systemMonitorViewModel.systemMonitorCPUUsage).gradient)
                    
                    Text(systemMonitorStatusText(systemMonitorViewModel.systemMonitorCPUUsage))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.white.opacity(0.1)))
                }
            }
            
            // 环形进度条
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 12)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: systemMonitorViewModel.systemMonitorCPUUsage / 100)
                    .stroke(
                        systemMonitorColorForPercentage(systemMonitorViewModel.systemMonitorCPUUsage).gradient,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: systemMonitorViewModel.systemMonitorCPUUsage)
                
                VStack(spacing: 4) {
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.blue.gradient)
                    Text("\(Int(systemMonitorViewModel.systemMonitorCPUUsage))%")
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .frame(maxWidth: .infinity)
            
            // CPU 历史图表
            if !systemMonitorViewModel.systemMonitorCPUHistory.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("使用率趋势")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Chart {
                        ForEach(Array(systemMonitorViewModel.systemMonitorCPUHistory.enumerated()), id: \.offset) { index, value in
                            LineMark(
                                x: .value("Time", index),
                                y: .value("Usage", value)
                            )
                            .foregroundStyle(.blue.gradient)
                            .interpolationMethod(.catmullRom)
                            
                            AreaMark(
                                x: .value("Time", index),
                                y: .value("Usage", value)
                            )
                            .foregroundStyle(.blue.opacity(0.2).gradient)
                            .interpolationMethod(.catmullRom)
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisValueLabel {
                                if let intValue = value.as(Double.self) {
                                    Text("\(Int(intValue))%")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .chartYScale(domain: 0...100)
                    .frame(height: 80)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: Color.blue.opacity(0.1), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Memory Section
    private var systemMonitorMemorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "memorychip.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.green.gradient)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("内存")
                        .font(.system(size: 14, weight: .semibold))
                    Text("总计 \(systemMonitorViewModel.systemMonitorMemoryTotal)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(systemMonitorViewModel.systemMonitorMemoryUsagePercentage))%")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(systemMonitorColorForPercentage(systemMonitorViewModel.systemMonitorMemoryUsagePercentage).gradient)
                    
                    Text(systemMonitorStatusText(systemMonitorViewModel.systemMonitorMemoryUsagePercentage))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.white.opacity(0.1)))
                }
            }
            
            // 内存详细信息卡片
            HStack(spacing: 12) {
                SystemMonitorMemoryCard(
                    title: "已用",
                    value: systemMonitorViewModel.systemMonitorMemoryUsed,
                    icon: "square.fill",
                    color: .green
                )
                
                SystemMonitorMemoryCard(
                    title: "可用",
                    value: systemMonitorViewModel.systemMonitorMemoryAvailable,
                    icon: "square",
                    color: .blue
                )
                
                SystemMonitorMemoryCard(
                    title: "压缩",
                    value: systemMonitorViewModel.systemMonitorMemoryCompressed,
                    icon: "arrow.down.square",
                    color: .orange
                )
            }
            
            // 内存使用条形图
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    // Active
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.green.gradient)
                        .frame(width: geometry.size.width * CGFloat(systemMonitorViewModel.systemMonitorMemoryActivePercentage / 100))
                    
                    // Wired
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.orange.gradient)
                        .frame(width: geometry.size.width * CGFloat(systemMonitorViewModel.systemMonitorMemoryWiredPercentage / 100))
                    
                    // Compressed
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.yellow.gradient)
                        .frame(width: geometry.size.width * CGFloat(systemMonitorViewModel.systemMonitorMemoryCompressedPercentage / 100))
                    
                    Spacer(minLength: 0)
                }
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: systemMonitorViewModel.systemMonitorMemoryActivePercentage)
            }
            .frame(height: 12)
            .background(Color.white.opacity(0.1))
            .cornerRadius(6)
            
            // 内存类型说明
            HStack(spacing: 16) {
                SystemMonitorLegendItem(color: .green, label: "活跃")
                SystemMonitorLegendItem(color: .orange, label: "联动")
                SystemMonitorLegendItem(color: .yellow, label: "压缩")
            }
            .font(.system(size: 10))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: Color.green.opacity(0.1), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Disk Section
    private var systemMonitorDiskSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "internaldrive.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.purple.gradient)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("磁盘")
                        .font(.system(size: 14, weight: .semibold))
                    Text("总容量 \(systemMonitorViewModel.systemMonitorDiskTotal)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(systemMonitorViewModel.systemMonitorDiskUsagePercentage))%")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(systemMonitorColorForPercentage(systemMonitorViewModel.systemMonitorDiskUsagePercentage).gradient)
                    
                    Text(systemMonitorStatusText(systemMonitorViewModel.systemMonitorDiskUsagePercentage))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.white.opacity(0.1)))
                }
            }
            
            // 磁盘空间可视化
            HStack(spacing: 16) {
                // 圆形图表
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 10)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: systemMonitorViewModel.systemMonitorDiskUsagePercentage / 100)
                        .stroke(
                            systemMonitorColorForPercentage(systemMonitorViewModel.systemMonitorDiskUsagePercentage).gradient,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: systemMonitorViewModel.systemMonitorDiskUsagePercentage)
                    
                    Image(systemName: "internaldrive")
                        .font(.system(size: 24))
                        .foregroundStyle(.purple.gradient)
                }
                
                VStack(spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("已用空间")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(systemMonitorViewModel.systemMonitorDiskUsed)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        Spacer()
                        Circle()
                            .fill(Color.purple.gradient)
                            .frame(width: 8, height: 8)
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("可用空间")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(systemMonitorViewModel.systemMonitorDiskFree)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        Spacer()
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: Color.purple.opacity(0.1), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Network Section
    private var systemMonitorNetworkSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "network")
                        .font(.system(size: 16))
                        .foregroundStyle(.orange.gradient)
                }
                
                Text("网络")
                    .font(.system(size: 14, weight: .semibold))
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                SystemMonitorNetworkCard(
                    title: "上传",
                    value: systemMonitorViewModel.systemMonitorNetworkUpload,
                    icon: "arrow.up.circle.fill",
                    color: .blue,
                    animate: systemMonitorViewModel.systemMonitorNetworkUploadSpeed > 0
                )
                
                SystemMonitorNetworkCard(
                    title: "下载",
                    value: systemMonitorViewModel.systemMonitorNetworkDownload,
                    icon: "arrow.down.circle.fill",
                    color: .green,
                    animate: systemMonitorViewModel.systemMonitorNetworkDownloadSpeed > 0
                )
            }
            
            // 网络历史图表
            if !systemMonitorViewModel.systemMonitorNetworkUploadHistory.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("流量趋势")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Chart {
                        ForEach(Array(systemMonitorViewModel.systemMonitorNetworkUploadHistory.enumerated()), id: \.offset) { index, value in
                            LineMark(
                                x: .value("Time", index),
                                y: .value("Upload", value)
                            )
                            .foregroundStyle(.blue)
                            .interpolationMethod(.catmullRom)
                        }
                        
                        ForEach(Array(systemMonitorViewModel.systemMonitorNetworkDownloadHistory.enumerated()), id: \.offset) { index, value in
                            LineMark(
                                x: .value("Time", index),
                                y: .value("Download", value)
                            )
                            .foregroundStyle(.green)
                            .interpolationMethod(.catmullRom)
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisValueLabel {
                                if let intValue = value.as(Double.self) {
                                    Text(systemMonitorViewModel.systemMonitorFormatSpeed(UInt64(intValue)))
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .frame(height: 70)
                    
                    HStack(spacing: 16) {
                        SystemMonitorLegendItem(color: .blue, label: "上传")
                        SystemMonitorLegendItem(color: .green, label: "下载")
                    }
                    .font(.system(size: 10))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: Color.orange.opacity(0.1), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Process Section
    private var systemMonitorProcessSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.pink.opacity(0.2))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "gearshape.2.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.pink.gradient)
                }
                
                Text("进程")
                    .font(.system(size: 14, weight: .semibold))
                
                Spacer()
                
                Text("\(systemMonitorViewModel.systemMonitorProcessCount)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.pink.gradient)
            }
            
            HStack(spacing: 12) {
                SystemMonitorProcessInfoCard(
                    icon: "app.badge",
                    label: "应用进程",
                    value: "\(systemMonitorViewModel.systemMonitorAppProcessCount)"
                )
                
                SystemMonitorProcessInfoCard(
                    icon: "gearshape.fill",
                    label: "系统进程",
                    value: "\(systemMonitorViewModel.systemMonitorSystemProcessCount)"
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.pink.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: Color.pink.opacity(0.1), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - System Info Section
    private var systemMonitorSystemInfoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.2))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.cyan.gradient)
                }
                
                Text("系统信息")
                    .font(.system(size: 14, weight: .semibold))
                
                Spacer()
            }
            
            VStack(spacing: 10) {
                SystemMonitorInfoRow(
                    icon: "clock.fill",
                    label: "运行时间",
                    value: systemMonitorViewModel.systemMonitorUptime,
                    color: .cyan
                )
                
                SystemMonitorInfoRow(
                    icon: "macbook",
                    label: "设备型号",
                    value: systemMonitorViewModel.systemMonitorModelName,
                    color: .blue
                )
                
                SystemMonitorInfoRow(
                    icon: "apple.logo",
                    label: "系统版本",
                    value: systemMonitorViewModel.systemMonitorOSVersion,
                    color: .purple
                )
                
                SystemMonitorInfoRow(
                    icon: "cpu.fill",
                    label: "处理器",
                    value: systemMonitorViewModel.systemMonitorCPUModel,
                    color: .orange
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: Color.cyan.opacity(0.1), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Helper Functions
    private func systemMonitorColorForPercentage(_ percentage: Double) -> Color {
        switch percentage {
        case 0..<50:
            return .green
        case 50..<80:
            return .yellow
        default:
            return .red
        }
    }
    
    private func systemMonitorStatusText(_ percentage: Double) -> String {
        switch percentage {
        case 0..<50:
            return "良好"
        case 50..<80:
            return "正常"
        default:
            return "繁忙"
        }
    }
}

// MARK: - Memory Card
struct SystemMonitorMemoryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(color.gradient)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 13, weight: .semibold))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }
}

// MARK: - Network Card
struct SystemMonitorNetworkCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let animate: Bool
    
    @State private var animationAmount: CGFloat = 1
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color.gradient)
                .scaleEffect(animationAmount)
                .onChange(of: animate) { newValue in
                    if newValue {
                        withAnimation(.easeInOut(duration: 0.5).repeatCount(2)) {
                            animationAmount = 1.2
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            animationAmount = 1
                        }
                    }
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color.gradient)
            }
            
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Legend Item
struct SystemMonitorLegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Process Info Card
struct SystemMonitorProcessInfoCard: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.pink.gradient)
            
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }
}

// MARK: - Info Row
struct SystemMonitorInfoRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color.gradient)
                .frame(width: 24)
            
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}

#Preview {
    SystemMonitorView()
}
