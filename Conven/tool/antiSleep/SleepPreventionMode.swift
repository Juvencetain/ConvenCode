import SwiftUI
import IOKit.pwr_mgt
import Combine

// MARK: - 防休眠模式
enum AntiSleepMode: String, CaseIterable, Codable {
    case display = "防止显示器休眠"
    case system = "防止系统休眠"
    case both = "全部防止"
    
    var antiSleepIcon: String {
        switch self {
        case .display: return "display"
        case .system: return "desktopcomputer"
        case .both: return "lock.shield.fill"
        }
    }
    
    var antiSleepColor: Color {
        switch self {
        case .display: return .blue
        case .system: return .purple
        case .both: return .green
        }
    }
    
    var antiSleepDescription: String {
        switch self {
        case .display: return "仅保持屏幕常亮"
        case .system: return "防止系统休眠但允许屏幕关闭"
        case .both: return "保持屏幕和系统都处于活跃状态"
        }
    }
}

// MARK: - 倒计时预设
struct AntiSleepCountdownPreset: Identifiable {
    let id = UUID()
    let antiSleepPresetName: String
    let antiSleepPresetMinutes: Int
    let antiSleepPresetIcon: String
}

// MARK: - 防休眠统计
struct AntiSleepStatistics: Codable {
    var antiSleepTotalActivations: Int = 0
    var antiSleepTotalDuration: TimeInterval = 0
    var antiSleepLastUsedDate: Date?
    
    var antiSleepFormattedTotalDuration: String {
        let hours = Int(antiSleepTotalDuration) / 3600
        let minutes = (Int(antiSleepTotalDuration) % 3600) / 60
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
}

// MARK: - ViewModel
@MainActor
class AntiSleepViewModel: ObservableObject {
    @Published var antiSleepIsActive: Bool = false
    @Published var antiSleepCurrentMode: AntiSleepMode = .both
    @Published var antiSleepCurrentDuration: TimeInterval = 0
    @Published var antiSleepCountdownMinutes: Int = 0
    @Published var antiSleepRemainingTime: TimeInterval = 0
    @Published var antiSleepShowToast = false
    @Published var antiSleepToastMessage = ""
    @Published var antiSleepStats = AntiSleepStatistics()
    
    private var antiSleepAssertionID: IOPMAssertionID = 0
    private var antiSleepDurationTimer: Timer?
    private var antiSleepCountdownTimer: Timer?
    private let antiSleepStatsStorageKey = "anti_sleep_stats"
    
    // 倒计时预设
    let antiSleepCountdownPresets: [AntiSleepCountdownPreset] = [
        AntiSleepCountdownPreset(antiSleepPresetName: "15分钟", antiSleepPresetMinutes: 15, antiSleepPresetIcon: "clock.fill"),
        AntiSleepCountdownPreset(antiSleepPresetName: "30分钟", antiSleepPresetMinutes: 30, antiSleepPresetIcon: "clock.fill"),
        AntiSleepCountdownPreset(antiSleepPresetName: "1小时", antiSleepPresetMinutes: 60, antiSleepPresetIcon: "clock.fill"),
        AntiSleepCountdownPreset(antiSleepPresetName: "2小时", antiSleepPresetMinutes: 120, antiSleepPresetIcon: "clock.fill"),
        AntiSleepCountdownPreset(antiSleepPresetName: "4小时", antiSleepPresetMinutes: 240, antiSleepPresetIcon: "clock.fill")
    ]
    
    var antiSleepIsCountdownActive: Bool {
        return antiSleepCountdownMinutes > 0 && antiSleepIsActive
    }
    
    var antiSleepFormattedDuration: String {
        let hours = Int(antiSleepCurrentDuration) / 3600
        let minutes = (Int(antiSleepCurrentDuration) % 3600) / 60
        let seconds = Int(antiSleepCurrentDuration) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    var antiSleepFormattedRemainingTime: String {
        let minutes = Int(antiSleepRemainingTime) / 60
        let seconds = Int(antiSleepRemainingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    init() {
        antiSleepLoadStats()
    }
    
    // MARK: - 主要功能
    
    func antiSleepToggle() {
        if antiSleepIsActive {
            antiSleepStopPrevention()
        } else {
            antiSleepStartPrevention()
        }
    }
    
    func antiSleepStartPrevention() {
        guard !antiSleepIsActive else { return }
        
        let assertionType: CFString
        let reason = "User requested to prevent sleep" as CFString
        
        switch antiSleepCurrentMode {
        case .display:
            assertionType = kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString
        case .system:
            assertionType = kIOPMAssertionTypePreventUserIdleSystemSleep as CFString
        case .both:
            assertionType = kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString
        }
        
        let result = IOPMAssertionCreateWithName(
            assertionType,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &antiSleepAssertionID
        )
        
        if result == kIOReturnSuccess {
            antiSleepIsActive = true
            antiSleepCurrentDuration = 0
            
            // 如果设置了倒计时
            if antiSleepCountdownMinutes > 0 {
                antiSleepRemainingTime = TimeInterval(antiSleepCountdownMinutes * 60)
                antiSleepStartCountdownTimer()
            }
            
            antiSleepStartDurationTimer()
            antiSleepUpdateStats(activated: true)
            
            antiSleepToastMessage = "已开启防休眠 - \(antiSleepCurrentMode.rawValue)"
            antiSleepShowToast = true
            
            print("✅ 防休眠已启动: \(antiSleepCurrentMode.rawValue)")
        } else {
            antiSleepToastMessage = "启动失败,请检查权限"
            antiSleepShowToast = true
            print("❌ 防休眠启动失败: \(result)")
        }
    }
    
    func antiSleepStopPrevention() {
        guard antiSleepIsActive else { return }
        
        if antiSleepAssertionID != 0 {
            IOPMAssertionRelease(antiSleepAssertionID)
            antiSleepAssertionID = 0
        }
        
        antiSleepIsActive = false
        antiSleepStopDurationTimer()
        antiSleepStopCountdownTimer()
        
        antiSleepUpdateStats(activated: false)
        
        antiSleepToastMessage = "防休眠已关闭"
        antiSleepShowToast = true
        
        print("🛑 防休眠已关闭")
    }
    
    func antiSleepSetCountdown(_ minutes: Int) {
        antiSleepCountdownMinutes = minutes
        if antiSleepIsActive {
            antiSleepRemainingTime = TimeInterval(minutes * 60)
            antiSleepStartCountdownTimer()
        }
    }
    
    func antiSleepClearCountdown() {
        antiSleepCountdownMinutes = 0
        antiSleepRemainingTime = 0
        antiSleepStopCountdownTimer()
    }
    
    // MARK: - 计时器
    
    private func antiSleepStartDurationTimer() {
        antiSleepDurationTimer?.invalidate()
        antiSleepDurationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.antiSleepCurrentDuration += 1
            }
        }
    }
    
    private func antiSleepStopDurationTimer() {
        antiSleepDurationTimer?.invalidate()
        antiSleepDurationTimer = nil
    }
    
    private func antiSleepStartCountdownTimer() {
        antiSleepStopCountdownTimer()
        antiSleepCountdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if self.antiSleepRemainingTime > 0 {
                    self.antiSleepRemainingTime -= 1
                } else {
                    self.antiSleepStopPrevention()
                    self.antiSleepCountdownMinutes = 0
                    self.antiSleepToastMessage = "倒计时结束,已自动关闭"
                    self.antiSleepShowToast = true
                }
            }
        }
    }
    
    private func antiSleepStopCountdownTimer() {
        antiSleepCountdownTimer?.invalidate()
        antiSleepCountdownTimer = nil
    }
    
    // MARK: - 统计
    
    private func antiSleepUpdateStats(activated: Bool) {
        if activated {
            antiSleepStats.antiSleepTotalActivations += 1
        } else {
            antiSleepStats.antiSleepTotalDuration += antiSleepCurrentDuration
        }
        antiSleepStats.antiSleepLastUsedDate = Date()
        antiSleepSaveStats()
    }
    
    private func antiSleepSaveStats() {
        if let encoded = try? JSONEncoder().encode(antiSleepStats) {
            UserDefaults.standard.set(encoded, forKey: antiSleepStatsStorageKey)
        }
    }
    
    private func antiSleepLoadStats() {
        guard let data = UserDefaults.standard.data(forKey: antiSleepStatsStorageKey),
              let decoded = try? JSONDecoder().decode(AntiSleepStatistics.self, from: data) else {
            return
        }
        antiSleepStats = decoded
    }
    
    func antiSleepResetStats() {
        antiSleepStats = AntiSleepStatistics()
        antiSleepSaveStats()
        antiSleepToastMessage = "统计数据已重置"
        antiSleepShowToast = true
    }
    
    // MARK: - 清理
    
    deinit {
        // 直接释放 assertion，不依赖 main actor
        antiSleepDurationTimer?.invalidate()
        antiSleepCountdownTimer?.invalidate()
        
        if antiSleepAssertionID != 0 {
            IOPMAssertionRelease(antiSleepAssertionID)
            print("🧹 防休眠资源已清理")
        }
    }
}
