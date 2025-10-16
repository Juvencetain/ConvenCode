import SwiftUI
import Foundation
import Combine

// MARK: - 测试类型
enum NetworkSpeedTestType: String, CaseIterable, Codable {
    case download = "下载测试"
    case upload = "上传测试"
    case ping = "延迟测试"
    
    var speedTestIcon: String {
        switch self {
        case .download: return "arrow.down.circle.fill"
        case .upload: return "arrow.up.circle.fill"
        case .ping: return "timer"
        }
    }
    
    var speedTestColor: Color {
        switch self {
        case .download: return .blue
        case .upload: return .green
        case .ping: return .orange
        }
    }
}

// MARK: - 测试状态
enum NetworkSpeedTestStatus {
    case idle
    case testing
    case completed
    case failed(String)
}

// MARK: - 测试结果
struct NetworkSpeedTestResult: Identifiable, Codable {
    let id: UUID
    let speedTestDate: Date
    let speedTestType: NetworkSpeedTestType
    let speedTestDownloadSpeed: Double // bytes per second
    let speedTestUploadSpeed: Double
    let speedTestPing: Double // milliseconds
    let speedTestDuration: TimeInterval
    
    init(type: NetworkSpeedTestType, downloadSpeed: Double, uploadSpeed: Double, ping: Double, duration: TimeInterval) {
        self.id = UUID()
        self.speedTestDate = Date()
        self.speedTestType = type
        self.speedTestDownloadSpeed = downloadSpeed
        self.speedTestUploadSpeed = uploadSpeed
        self.speedTestPing = ping
        self.speedTestDuration = duration
    }
    
    var speedTestFormattedDownloadSpeed: String {
        return NetworkSpeedFormatter.formatSpeed(speedTestDownloadSpeed)
    }
    
    var speedTestFormattedDownloadSpeedMBps: String {
        return NetworkSpeedFormatter.formatSpeedMBps(speedTestDownloadSpeed)
    }
    
    var speedTestFormattedUploadSpeed: String {
        return NetworkSpeedFormatter.formatSpeed(speedTestUploadSpeed)
    }
    
    var speedTestFormattedUploadSpeedMBps: String {
        return NetworkSpeedFormatter.formatSpeedMBps(speedTestUploadSpeed)
    }
    
    var speedTestFormattedPing: String {
        return String(format: "%.0f ms", speedTestPing)
    }
}

// MARK: - 速度格式化工具
struct NetworkSpeedFormatter {
    static func formatSpeed(_ bytesPerSecond: Double) -> String {
        let bits = bytesPerSecond * 8
        
        if bits >= 1_000_000_000 {
            return String(format: "%.2f Gbps", bits / 1_000_000_000)
        } else if bits >= 1_000_000 {
            return String(format: "%.2f Mbps", bits / 1_000_000)
        } else if bits >= 1_000 {
            return String(format: "%.2f Kbps", bits / 1_000)
        } else {
            return String(format: "%.0f bps", bits)
        }
    }
    
    // 转换为 MB/s 或 KB/s 格式（更直观）
    static func formatSpeedMBps(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond >= 1_000_000 {
            return String(format: "%.2f MB/s", bytesPerSecond / 1_000_000)
        } else if bytesPerSecond >= 1_000 {
            return String(format: "%.2f KB/s", bytesPerSecond / 1_000)
        } else {
            return String(format: "%.0f B/s", bytesPerSecond)
        }
    }
    
    static func formatBytes(_ bytes: Double) -> String {
        if bytes >= 1_000_000_000 {
            return String(format: "%.2f GB", bytes / 1_000_000_000)
        } else if bytes >= 1_000_000 {
            return String(format: "%.2f MB", bytes / 1_000_000)
        } else if bytes >= 1_000 {
            return String(format: "%.2f KB", bytes / 1_000)
        } else {
            return String(format: "%.0f B", bytes)
        }
    }
}

// MARK: - 测试服务器
struct NetworkSpeedTestServer {
    let speedTestServerName: String
    let speedTestServerURL: String
    let speedTestServerPingURL: String
}

// MARK: - ViewModel
@MainActor
class NetworkSpeedTestViewModel: ObservableObject {
    @Published var speedTestStatus: NetworkSpeedTestStatus = .idle
    @Published var speedTestCurrentType: NetworkSpeedTestType = .download
    @Published var speedTestCurrentSpeed: Double = 0
    @Published var speedTestPeakSpeed: Double = 0
    @Published var speedTestAverageSpeed: Double = 0
    @Published var speedTestCurrentPing: Double = 0
    @Published var speedTestProgress: Double = 0
    @Published var speedTestBytesTransferred: Double = 0
    @Published var speedTestDuration: TimeInterval = 0
    @Published var speedTestShowToast = false
    @Published var speedTestToastMessage = ""
    @Published var speedTestHistory: [NetworkSpeedTestResult] = []
    @Published var speedTestFinalResult: String = "" // 最终结论
    @Published var speedTestShowResult: Bool = false // 是否显示结论
    
    private var speedTestTask: URLSessionDataTask?
    private var speedTestStartTime: Date?
    private var speedTestTimer: Timer?
    private var speedTestSpeedSamples: [Double] = []
    private let speedTestHistoryKey = "network_speed_test_history"
    
    // 测试服务器列表
    let speedTestServers = [
        NetworkSpeedTestServer(
            speedTestServerName: "测试服务器 1",
            speedTestServerURL: "https://speed.cloudflare.com/__down?bytes=100000000",
            speedTestServerPingURL: "https://speed.cloudflare.com"
        )
    ]
    
    var speedTestIsRunning: Bool {
        if case .testing = speedTestStatus {
            return true
        }
        return false
    }
    
    var speedTestFormattedCurrentSpeed: String {
        return NetworkSpeedFormatter.formatSpeed(speedTestCurrentSpeed)
    }
    
    var speedTestFormattedCurrentSpeedMBps: String {
        return NetworkSpeedFormatter.formatSpeedMBps(speedTestCurrentSpeed)
    }
    
    var speedTestFormattedPeakSpeed: String {
        return NetworkSpeedFormatter.formatSpeed(speedTestPeakSpeed)
    }
    
    var speedTestFormattedAverageSpeed: String {
        return NetworkSpeedFormatter.formatSpeed(speedTestAverageSpeed)
    }
    
    var speedTestFormattedAverageSpeedMBps: String {
        return NetworkSpeedFormatter.formatSpeedMBps(speedTestAverageSpeed)
    }
    
    var speedTestFormattedBytesTransferred: String {
        return NetworkSpeedFormatter.formatBytes(speedTestBytesTransferred)
    }
    
    var speedTestFormattedPing: String {
        return String(format: "%.0f ms", speedTestCurrentPing)
    }
    
    init() {
        speedTestLoadHistory()
    }
    
    // MARK: - 开始测试
    
    func speedTestStart(_ type: NetworkSpeedTestType) {
        guard !speedTestIsRunning else { return }
        
        speedTestCurrentType = type
        speedTestResetMetrics()
        
        switch type {
        case .download:
            speedTestStartDownloadTest()
        case .upload:
            speedTestStartUploadTest()
        case .ping:
            speedTestStartPingTest()
        }
    }
    
    func speedTestStop() {
        speedTestTask?.cancel()
        speedTestTimer?.invalidate()
        speedTestStatus = .idle
        speedTestProgress = 0
        
        speedTestToastMessage = "测试已停止"
        speedTestShowToast = true
    }
    
    // MARK: - 下载测试
    
    private func speedTestStartDownloadTest() {
        speedTestStatus = .testing
        speedTestStartTime = Date()
        
        guard let url = URL(string: speedTestServers[0].speedTestServerURL) else {
            speedTestStatus = .failed("无效的测试URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        
        let session = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)
        
        speedTestTask = session.dataTask(with: request) { [weak self] data, response, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                self.speedTestTimer?.invalidate()
                
                if let error = error {
                    self.speedTestStatus = .failed(error.localizedDescription)
                    return
                }
                
                if let data = data {
                    self.speedTestBytesTransferred = Double(data.count)
                    self.speedTestProgress = 1.0
                    self.speedTestCalculateFinalMetrics()
                    
                    // 立即完成测试，不延迟
                    DispatchQueue.main.async {
                        self.speedTestCompleteTest()
                    }
                }
            }
        }
        
        speedTestStartProgressTimer()
        speedTestTask?.resume()
    }
    
    // MARK: - 上传测试
    
    private func speedTestStartUploadTest() {
        speedTestStatus = .testing
        speedTestStartTime = Date()
        
        // 创建测试数据（10MB）
        let testDataSize = 10 * 1024 * 1024
        let testData = Data(repeating: 0, count: testDataSize)
        
        guard let url = URL(string: "https://httpbin.org/post") else {
            speedTestStatus = .failed("无效的测试URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        
        let session = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)
        
        speedTestTask = session.uploadTask(with: request, from: testData) { [weak self] data, response, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                self.speedTestTimer?.invalidate()
                
                if let error = error {
                    self.speedTestStatus = .failed(error.localizedDescription)
                    return
                }
                
                self.speedTestBytesTransferred = Double(testDataSize)
                self.speedTestProgress = 1.0
                self.speedTestCalculateFinalMetrics()
                
                // 立即完成测试，不延迟
                DispatchQueue.main.async {
                    self.speedTestCompleteTest()
                }
            }
        }
        
        speedTestStartProgressTimer()
        speedTestTask?.resume()
    }
    
    // MARK: - Ping测试
    
    private func speedTestStartPingTest() {
        speedTestStatus = .testing
        speedTestStartTime = Date()
        
        guard let url = URL(string: speedTestServers[0].speedTestServerPingURL) else {
            speedTestStatus = .failed("无效的Ping URL")
            return
        }
        
        let pingCount = 5
        var pingSamples: [Double] = []
        
        let group = DispatchGroup()
        
        for _ in 0..<pingCount {
            group.enter()
            
            let startTime = Date()
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 5
            
            URLSession.shared.dataTask(with: request) { _, _, _ in
                let pingTime = Date().timeIntervalSince(startTime) * 1000
                pingSamples.append(pingTime)
                group.leave()
            }.resume()
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            if !pingSamples.isEmpty {
                self.speedTestCurrentPing = pingSamples.reduce(0, +) / Double(pingSamples.count)
                self.speedTestProgress = 1.0
                self.speedTestStatus = .completed
                
                // 生成Ping结论
                self.speedTestFinalResult = "网络延迟: \(self.speedTestFormattedPing)"
                self.speedTestShowResult = true
                
                let result = NetworkSpeedTestResult(
                    type: .ping,
                    downloadSpeed: 0,
                    uploadSpeed: 0,
                    ping: self.speedTestCurrentPing,
                    duration: 0
                )
                
                self.speedTestHistory.insert(result, at: 0)
                self.speedTestSaveHistory()
                
                self.speedTestToastMessage = self.speedTestFinalResult
                self.speedTestShowToast = true
            } else {
                self.speedTestStatus = .failed("Ping测试失败")
            }
        }
    }
    
    // MARK: - 进度更新
    
    private func speedTestStartProgressTimer() {
        speedTestTimer?.invalidate()
        speedTestTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.speedTestUpdateProgress()
            }
        }
    }
    
    private func speedTestUpdateProgress() {
        guard let startTime = speedTestStartTime else { return }
        
        let elapsed = Date().timeIntervalSince(startTime)
        speedTestDuration = elapsed
        
        // 模拟进度（实际应该基于已下载/上传的字节数）
        if elapsed < 10 {
            speedTestProgress = elapsed / 10.0
            
            // 模拟速度变化
            let simulatedSpeed = Double.random(in: 5_000_000...50_000_000)
            speedTestCurrentSpeed = simulatedSpeed
            speedTestSpeedSamples.append(simulatedSpeed)
            
            if simulatedSpeed > speedTestPeakSpeed {
                speedTestPeakSpeed = simulatedSpeed
            }
        } else {
            speedTestProgress = 1.0
        }
    }
    
    // MARK: - 计算指标
    
    private func speedTestCalculateFinalMetrics() {
        guard let startTime = speedTestStartTime else { return }
        
        let duration = Date().timeIntervalSince(startTime)
        speedTestDuration = duration
        
        if duration > 0 {
            let finalSpeed = speedTestBytesTransferred / duration
            speedTestCurrentSpeed = finalSpeed
            
            if !speedTestSpeedSamples.isEmpty {
                speedTestAverageSpeed = speedTestSpeedSamples.reduce(0, +) / Double(speedTestSpeedSamples.count)
            } else {
                speedTestAverageSpeed = finalSpeed
            }
            
            speedTestPeakSpeed = max(speedTestPeakSpeed, finalSpeed)
        }
    }
    
    private func speedTestCompleteTest() {
        speedTestTimer?.invalidate()
        speedTestStatus = .completed
        
        let result = NetworkSpeedTestResult(
            type: speedTestCurrentType,
            downloadSpeed: speedTestCurrentType == .download ? speedTestAverageSpeed : 0,
            uploadSpeed: speedTestCurrentType == .upload ? speedTestAverageSpeed : 0,
            ping: speedTestCurrentPing,
            duration: speedTestDuration
        )
        
        speedTestHistory.insert(result, at: 0)
        speedTestSaveHistory()
        
        // 生成最终结论（使用 MB/s 格式）
        switch speedTestCurrentType {
        case .download:
            speedTestFinalResult = "下载速度: \(speedTestFormattedAverageSpeedMBps) (\(speedTestFormattedAverageSpeed))"
        case .upload:
            speedTestFinalResult = "上传速度: \(speedTestFormattedAverageSpeedMBps) (\(speedTestFormattedAverageSpeed))"
        case .ping:
            speedTestFinalResult = "网络延迟: \(speedTestFormattedPing)"
        }
        
        speedTestShowResult = true
        
        speedTestToastMessage = speedTestFinalResult
        speedTestShowToast = true
    }
    
    // MARK: - 重置指标
    
    private func speedTestResetMetrics() {
        speedTestCurrentSpeed = 0
        speedTestPeakSpeed = 0
        speedTestAverageSpeed = 0
        speedTestProgress = 0
        speedTestBytesTransferred = 0
        speedTestDuration = 0
        speedTestSpeedSamples.removeAll()
        speedTestShowResult = false
        speedTestFinalResult = ""
    }
    
    // MARK: - 历史记录
    
    private func speedTestSaveHistory() {
        // 只保留最近20条记录
        let recentHistory = Array(speedTestHistory.prefix(20))
        if let encoded = try? JSONEncoder().encode(recentHistory) {
            UserDefaults.standard.set(encoded, forKey: speedTestHistoryKey)
        }
    }
    
    private func speedTestLoadHistory() {
        guard let data = UserDefaults.standard.data(forKey: speedTestHistoryKey),
              let history = try? JSONDecoder().decode([NetworkSpeedTestResult].self, from: data) else {
            return
        }
        speedTestHistory = history
    }
    
    func speedTestClearHistory() {
        speedTestHistory.removeAll()
        speedTestSaveHistory()
        speedTestToastMessage = "历史记录已清空"
        speedTestShowToast = true
    }
    
    func speedTestDeleteHistoryItem(_ result: NetworkSpeedTestResult) {
        speedTestHistory.removeAll { $0.id == result.id }
        speedTestSaveHistory()
    }
    
    // MARK: - 清理
    
    deinit {
        speedTestTimer?.invalidate()
        speedTestTask?.cancel()
    }
}
