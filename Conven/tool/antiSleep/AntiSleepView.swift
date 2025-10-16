import SwiftUI

// MARK: - 防休眠主视图
struct AntiSleepView: View {
    @StateObject private var antiSleepViewModel = AntiSleepViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(1)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                antiSleepTopBar
                Divider()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // 主状态卡片
                        antiSleepStatusCard
                        
                        // 模式选择
                        antiSleepModeSelection
                        
                        // 倒计时设置
                        antiSleepCountdownSection
                        
                        // 统计信息
                        antiSleepStatsSection
                        
                        Spacer(minLength: 20)
                    }
                    .padding(24)
                }
            }
        }
        .frame(width: 420, height: 560)
        .focusable(false)
        .overlay(alignment: .top) {
            if antiSleepViewModel.antiSleepShowToast {
                antiSleepToastView
            }
        }
    }
    
    // MARK: - 顶部栏
    
    private var antiSleepTopBar: some View {
        HStack {
            Image(systemName: "bolt.shield.fill")
                .font(.system(size: 16))
                .foregroundStyle(.green.gradient)
            
            Text("防休眠工具")
                .font(.system(size: 16, weight: .semibold))
            
            Spacer()
            
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .antiSleepCursor()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
    
    // MARK: - 状态卡片
    
    private var antiSleepStatusCard: some View {
        VStack(spacing: 20) {
            // 主开关
            ZStack {
                // 背景圆环
                Circle()
                    .stroke(
                        antiSleepViewModel.antiSleepIsActive ?
                        antiSleepViewModel.antiSleepCurrentMode.antiSleepColor.opacity(0.3) :
                        Color.gray.opacity(0.2),
                        lineWidth: 8
                    )
                    .frame(width: 140, height: 140)
                
                // 动画圆环
                if antiSleepViewModel.antiSleepIsActive {
                    Circle()
                        .trim(from: 0, to: 0.75)
                        .stroke(
                            antiSleepViewModel.antiSleepCurrentMode.antiSleepColor.gradient,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-90))
                        .animation(
                            .linear(duration: 2).repeatForever(autoreverses: false),
                            value: antiSleepViewModel.antiSleepIsActive
                        )
                }
                
                // 中心图标
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        antiSleepViewModel.antiSleepToggle()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                antiSleepViewModel.antiSleepIsActive ?
                                antiSleepViewModel.antiSleepCurrentMode.antiSleepColor.gradient :
                                Color.gray.gradient
                            )
                            .frame(width: 110, height: 110)
                        
                        Image(systemName: antiSleepViewModel.antiSleepIsActive ? "bolt.fill" : "power")
                            .font(.system(size: 44))
                            .foregroundColor(.white)
                            .scaleEffect(antiSleepViewModel.antiSleepIsActive ? 1.0 : 0.9)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: antiSleepViewModel.antiSleepIsActive)
                    }
                }
                .buttonStyle(.plain)
                .antiSleepCursor()
            }
            
            // 状态文本
            VStack(spacing: 8) {
                Text(antiSleepViewModel.antiSleepIsActive ? "已激活" : "已关闭")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(antiSleepViewModel.antiSleepIsActive ? antiSleepViewModel.antiSleepCurrentMode.antiSleepColor : .secondary)
                
                if antiSleepViewModel.antiSleepIsActive {
                    VStack(spacing: 4) {
                        Text("运行时长: \(antiSleepViewModel.antiSleepFormattedDuration)")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.primary)
                        
                        if antiSleepViewModel.antiSleepIsCountdownActive {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 11))
                                Text("剩余: \(antiSleepViewModel.antiSleepFormattedRemainingTime)")
                                    .font(.system(size: 13, design: .monospaced))
                            }
                            .foregroundColor(.orange)
                        }
                    }
                } else {
                    Text("点击按钮开启防休眠")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(24)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    // MARK: - 模式选择
    
    private var antiSleepModeSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("防休眠模式")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 10) {
                ForEach(AntiSleepMode.allCases, id: \.self) { mode in
                    AntiSleepModeCard(
                        antiSleepMode: mode,
                        antiSleepIsSelected: antiSleepViewModel.antiSleepCurrentMode == mode,
                        antiSleepIsActive: antiSleepViewModel.antiSleepIsActive
                    ) {
                        if !antiSleepViewModel.antiSleepIsActive {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                antiSleepViewModel.antiSleepCurrentMode = mode
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - 倒计时设置
    
    private var antiSleepCountdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("定时关闭")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if antiSleepViewModel.antiSleepCountdownMinutes > 0 {
                    Button(action: {
                        withAnimation {
                            antiSleepViewModel.antiSleepClearCountdown()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                            Text("清除")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .antiSleepCursor()
                }
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                ForEach(antiSleepViewModel.antiSleepCountdownPresets) { preset in
                    AntiSleepCountdownButton(
                        antiSleepPreset: preset,
                        antiSleepIsSelected: antiSleepViewModel.antiSleepCountdownMinutes == preset.antiSleepPresetMinutes,
                        antiSleepIsDisabled: antiSleepViewModel.antiSleepIsActive
                    ) {
                        withAnimation {
                            antiSleepViewModel.antiSleepSetCountdown(preset.antiSleepPresetMinutes)
                        }
                    }
                }
            }
            
            if antiSleepViewModel.antiSleepIsActive {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 11))
                    Text("运行时无法更改倒计时")
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - 统计信息
    
    private var antiSleepStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("使用统计")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    antiSleepViewModel.antiSleepResetStats()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                        Text("重置")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.12))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .antiSleepCursor()
            }
            
            HStack(spacing: 16) {
                AntiSleepStatCard(
                    antiSleepStatIcon: "number.circle.fill",
                    antiSleepStatValue: "\(antiSleepViewModel.antiSleepStats.antiSleepTotalActivations)",
                    antiSleepStatLabel: "总启动次数",
                    antiSleepStatColor: .blue
                )
                
                AntiSleepStatCard(
                    antiSleepStatIcon: "clock.fill",
                    antiSleepStatValue: antiSleepViewModel.antiSleepStats.antiSleepFormattedTotalDuration,
                    antiSleepStatLabel: "累计时长",
                    antiSleepStatColor: .purple
                )
            }
            
            if let lastUsed = antiSleepViewModel.antiSleepStats.antiSleepLastUsedDate {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                    Text("上次使用: \(antiSleepFormatDate(lastUsed))")
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Toast
    
    private var antiSleepToastView: some View {
        HStack(spacing: 8) {
            Image(systemName: antiSleepViewModel.antiSleepIsActive ? "checkmark.circle.fill" : "info.circle.fill")
                .font(.system(size: 12))
            Text(antiSleepViewModel.antiSleepToastMessage)
                .font(.system(size: 12))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(antiSleepViewModel.antiSleepIsActive ? Color.green : Color.blue)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
        .padding(.top, 70)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3).delay(2)) {
                antiSleepViewModel.antiSleepShowToast = false
            }
        }
    }
    
    // MARK: - 辅助方法
    
    private func antiSleepFormatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 模式卡片
struct AntiSleepModeCard: View {
    let antiSleepMode: AntiSleepMode
    let antiSleepIsSelected: Bool
    let antiSleepIsActive: Bool
    let antiSleepAction: () -> Void
    
    @State private var antiSleepIsHovered = false
    
    var body: some View {
        Button(action: antiSleepAction) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(antiSleepMode.antiSleepColor.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: antiSleepMode.antiSleepIcon)
                        .font(.system(size: 18))
                        .foregroundStyle(antiSleepMode.antiSleepColor.gradient)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(antiSleepMode.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(antiSleepMode.antiSleepDescription)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if antiSleepIsSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(antiSleepMode.antiSleepColor)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        antiSleepIsSelected ?
                        antiSleepMode.antiSleepColor.opacity(0.15) :
                        (antiSleepIsHovered ? Color.white.opacity(0.08) : Color.white.opacity(0.05))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        antiSleepIsSelected ? antiSleepMode.antiSleepColor.opacity(0.5) : Color.clear,
                        lineWidth: 2
                    )
            )
            .opacity(antiSleepIsActive ? 0.5 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(antiSleepIsActive)
        .onHover { hovering in
            if !antiSleepIsActive {
                antiSleepIsHovered = hovering
            }
        }
        .antiSleepCursor()
    }
}

// MARK: - 倒计时预设按钮
struct AntiSleepCountdownButton: View {
    let antiSleepPreset: AntiSleepCountdownPreset
    let antiSleepIsSelected: Bool
    let antiSleepIsDisabled: Bool
    let antiSleepAction: () -> Void
    
    @State private var antiSleepIsHovered = false
    
    var body: some View {
        Button(action: antiSleepAction) {
            VStack(spacing: 6) {
                Image(systemName: antiSleepPreset.antiSleepPresetIcon)
                    .font(.system(size: 16))
                    .foregroundStyle(
                        antiSleepIsSelected ? Color.orange.gradient :
                        (antiSleepIsDisabled ? Color.gray.gradient : Color.blue.gradient)
                    )
                
                Text(antiSleepPreset.antiSleepPresetName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(antiSleepIsSelected ? .orange : (antiSleepIsDisabled ? .secondary : .primary))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        antiSleepIsSelected ?
                        Color.orange.opacity(0.15) :
                        (antiSleepIsHovered ? Color.white.opacity(0.08) : Color.white.opacity(0.05))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        antiSleepIsSelected ? Color.orange.opacity(0.5) : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .opacity(antiSleepIsDisabled ? 0.5 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(antiSleepIsDisabled)
        .onHover { hovering in
            if !antiSleepIsDisabled {
                antiSleepIsHovered = hovering
            }
        }
        .antiSleepCursor()
    }
}

// MARK: - 统计卡片
struct AntiSleepStatCard: View {
    let antiSleepStatIcon: String
    let antiSleepStatValue: String
    let antiSleepStatLabel: String
    let antiSleepStatColor: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: antiSleepStatIcon)
                .font(.system(size: 20))
                .foregroundStyle(antiSleepStatColor.gradient)
            
            Text(antiSleepStatValue)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(antiSleepStatLabel)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - 辅助扩展
extension View {
    func antiSleepCursor() -> some View {
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
    AntiSleepView()
}
