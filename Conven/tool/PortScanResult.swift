import SwiftUI
import Foundation
import Combine

// MARK: - Model (数据模型)
struct PortScanResult: Identifiable, Hashable {
    enum Status: String {
        case open = "开放"
        case closed = "关闭"
        case timeout = "超时"
        case error = "错误"
        
        var color: Color {
            switch self {
            case .open: .green
            case .closed: .red
            case .timeout: .orange
            case .error: .gray
            }
        }
    }
    
    let id = UUID()
    let host: String
    let port: Int
    let status: Status
    let duration: TimeInterval
    let message: String
    let timestamp: Date = Date()
}

struct CommonPort: Identifiable {
    let id = UUID()
    let name: String
    let port: Int
}

// MARK: - ViewModel (视图模型)
@MainActor
class PortScannerViewModel: ObservableObject {
    @Published var hostname: String = "localhost"
    @Published var portString: String = "3306"
    @Published var scanResults: [PortScanResult] = []
    @Published var isScanning = false
    @Published var errorMessage: String?
    
    let commonPorts: [CommonPort] = [
        .init(name: "HTTP", port: 80),
        .init(name: "HTTPS", port: 443),
        .init(name: "SSH", port: 22),
        .init(name: "FTP", port: 21),
        .init(name: "MySQL", port: 3306),
        .init(name: "PostgreSQL", port: 5432),
        .init(name: "Redis", port: 6379),
        .init(name: "MongoDB", port: 27017),
    ]

    func scan() {
        errorMessage = nil
        
        guard !hostname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "请输入主机名或 IP 地址"
            return
        }
        
        guard let port = Int(portString), port > 0, port <= 65535 else {
            errorMessage = "端口号必须在 1-65535 之间"
            return
        }
        
        isScanning = true
        
        Task {
            let startTime = Date()
            let (status, message) = await checkPortWithNC(host: hostname, port: port)
            let duration = Date().timeIntervalSince(startTime)
            
            let result = PortScanResult(
                host: hostname,
                port: port,
                status: status,
                duration: duration,
                message: message
            )
            
            scanResults.insert(result, at: 0)
            isScanning = false
        }
    }

    private func checkPortWithNC(host: String, port: Int) async -> (PortScanResult.Status, String) {
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/nc")
            process.arguments = ["-zv", "-G", "3", host, "\(port)"]
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            do {
                try process.run()
                
                // 等待进程完成或超时
                DispatchQueue.global().asyncAfter(deadline: .now() + 4) {
                    if process.isRunning {
                        process.terminate()
                    }
                }
                
                process.waitUntilExit()
                
                let exitCode = process.terminationStatus
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                
                let status: PortScanResult.Status
                var message = errorOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // nc 命令的退出码：0 = 成功连接，其他 = 失败
                if exitCode == 0 {
                    status = .open
                    if message.isEmpty {
                        message = "连接成功"
                    }
                } else {
                    // 根据错误信息判断具体状态
                    if message.contains("Connection refused") || message.contains("refused") {
                        status = .closed
                    } else if message.contains("timed out") || message.contains("timeout") || message.contains("Operation timed out") {
                        status = .timeout
                    } else if message.contains("nodename nor servname provided") || message.contains("Name or service not known") {
                        status = .error
                        message = "主机名无法解析"
                    } else if message.contains("No route to host") {
                        status = .timeout
                        message = "主机不可达"
                    } else {
                        // 其他错误
                        status = message.isEmpty ? .timeout : .closed
                        if message.isEmpty {
                            message = "连接失败 (退出码: \(exitCode))"
                        }
                    }
                }
                
                continuation.resume(returning: (status, message))
                
            } catch {
                continuation.resume(returning: (.error, "执行 nc 命令失败: \(error.localizedDescription)"))
            }
        }
    }
}

// MARK: - 主视图
struct PortScannerView: View {
    @StateObject private var viewModel = PortScannerViewModel()

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow).ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                Divider().padding(.horizontal, 20)
                inputSection
                Divider().padding(.horizontal, 20)
                resultsSection
            }
        }
        .frame(width: 480, height: 560)
    }

    private var headerBar: some View {
        HStack {
            Image(systemName: "network")
                .font(.system(size: 16))
                .foregroundStyle(.indigo.gradient)
            Text("端口扫描/检测 (nc)")
                .font(.system(size: 14, weight: .medium))
            Spacer()
        }
        .padding(20)
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading) {
                Text("目标主机与端口").font(.caption).foregroundColor(.secondary)
                HStack {
                    TextField("主机名或 IP 地址", text: $viewModel.hostname)
                    Text(":")
                    TextField("端口", text: $viewModel.portString)
                        .frame(width: 60)
                }
                .textFieldStyle(PlainTextFieldStyle())
                .padding(10)
                .background(Color.primary.opacity(0.1))
                .cornerRadius(8)
            }

            if let error = viewModel.errorMessage {
                Text(error).font(.caption).foregroundColor(.red).padding(.horizontal, 4)
            }
            
            VStack(alignment: .leading) {
                Text("常用端口").font(.caption).foregroundColor(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                    ForEach(viewModel.commonPorts) { commonPort in
                        Button(action: { viewModel.portString = "\(commonPort.port)" }) {
                            Text("\(commonPort.name) (\(commonPort.port))")
                                .font(.system(size: 11))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ModernButtonStyle(style: .normal))
                    }
                }
            }
            
            Button(action: viewModel.scan) {
                HStack(spacing: 8) {
                    if viewModel.isScanning {
                        ProgressView().progressViewStyle(.circular).scaleEffect(0.8).colorInvert()
                        Text("检测中...")
                    } else {
                        Label("开始检测", systemImage: "paperplane.fill")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(ModernButtonStyle(style: .execute))
            .disabled(viewModel.isScanning)
            .keyboardShortcut(.defaultAction)
            
        }
        .padding(20)
    }
    
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("检测历史 (\(viewModel.scanResults.count))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 10) {
                    StatusLegend(color: .green, label: "开放")
                    StatusLegend(color: .red, label: "关闭")
                    StatusLegend(color: .orange, label: "超时")
                }
            }
            .padding(EdgeInsets(top: 15, leading: 20, bottom: 10, trailing: 20))
            
            if viewModel.scanResults.isEmpty {
                VStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("检测结果将显示在这里")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }.frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.scanResults) { result in
                            ResultRow(result: result)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
    }
}

// MARK: - 辅助视图
struct StatusLegend: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
    }
}

struct ResultRow: View {
    let result: PortScanResult
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Circle()
                    .fill(result.status.color)
                    .frame(width: 8, height: 8)
                    .shadow(color: result.status.color, radius: 3)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(result.host):\(result.port)")
                        .font(.system(size: 13, design: .monospaced)).bold()
                    
                    Text(Self.dateFormatter.string(from: result.timestamp))
                        .font(.system(size: 10)).foregroundColor(.secondary)
                }

                Spacer()

                Text(String(format: "%.0f ms", result.duration * 1000))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 70, alignment: .trailing)
                
                Text(result.status.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(result.status.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(width: 70, alignment: .center)
                    .background(result.status.color.opacity(0.15))
                    .cornerRadius(6)
            }
            .padding(10)
            
            if !result.message.isEmpty {
                HStack {
                    Text(result.message)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }
        }
        .background(Color.primary.opacity(0.05))
        .cornerRadius(8)
    }
}
