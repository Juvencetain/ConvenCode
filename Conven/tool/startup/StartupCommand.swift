import SwiftUI
import Combine
import Foundation

// MARK: - Startup Command Model
struct StartupCommand: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var command: String
    var isEnabled: Bool
    var delaySeconds: Double
    var executionTime: Date?
    var lastOutput: String?
    var exitCode: Int32?
    var executionCount: Int
    
    init(
        id: UUID = UUID(),
        name: String,
        command: String,
        isEnabled: Bool = true,
        delaySeconds: Double = 0
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.isEnabled = isEnabled
        self.delaySeconds = delaySeconds
        self.executionCount = 0
    }
}

// MARK: - Execution Log Model
struct ExecutionLog: Identifiable, Codable {
    let id: UUID
    let commandId: UUID
    let commandName: String
    let timestamp: Date
    let output: String
    let errorOutput: String
    let exitCode: Int32
    let executionType: ExecutionType
    let duration: TimeInterval
    
    enum ExecutionType: String, Codable {
        case startup = "启动"
        case manual = "手动"
    }
}

// MARK: - Startup Executor ViewModel
@MainActor
class StartupExecutorViewModel: ObservableObject {
    @Published var commands: [StartupCommand] = []
    @Published var executionLogs: [ExecutionLog] = []
    @Published var executingCommandId: UUID?
    @Published var showAddEditSheet = false
    @Published var commandToEdit: StartupCommand?
    @Published var showLogsSheet = false
    @Published var searchText: String = ""
    @Published var systemEnvironment: [String: String] = [:]
    
    private let commandsKey = "startup_executor_commands_v2"
    private let maxLogsCount = 1000
    private var cancellables = Set<AnyCancellable>()
    
    // 日志文件路径
    private var logsFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let appFolder = appSupport.appendingPathComponent("StartupExecutor", isDirectory: true)
        
        // 确保目录存在
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        
        return appFolder.appendingPathComponent("execution_logs.json")
    }
    
    var filteredCommands: [StartupCommand] {
        if searchText.isEmpty {
            return commands
        }
        return commands.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.command.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var statistics: (total: Int, enabled: Int) {
        let total = commands.count
        let enabled = commands.filter { $0.isEnabled }.count
        return (total, enabled)
    }
    
    init() {
        loadCommands()
        loadLogs()
        loadSystemEnvironment()
        
        $commands
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.saveCommands() }
            .store(in: &cancellables)
        
        $executionLogs
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.saveLogs() }
            .store(in: &cancellables)
    }
    
    // MARK: - Environment
    private func loadSystemEnvironment() {
        systemEnvironment = ProcessInfo.processInfo.environment
        print("📦 已加载 \(systemEnvironment.count) 个系统环境变量")
    }
    
    // MARK: - Command Management
    func addCommand(_ command: StartupCommand) {
        commands.append(command)
    }
    
    func updateCommand(_ command: StartupCommand) {
        if let index = commands.firstIndex(where: { $0.id == command.id }) {
            commands[index] = command
        }
    }
    
    func deleteCommand(_ command: StartupCommand) {
        commands.removeAll { $0.id == command.id }
        executionLogs.removeAll { $0.commandId == command.id }
    }
    
    func deleteCommands(at offsets: IndexSet) {
        let commandsToDelete = offsets.map { filteredCommands[$0] }
        commandsToDelete.forEach { deleteCommand($0) }
    }
    
    // MARK: - Execution
    func executeSingleCommand(commandId: UUID) async {
        guard executingCommandId == nil else { return }
        guard let index = commands.firstIndex(where: { $0.id == commandId }) else { return }
        
        executingCommandId = commandId
        let command = commands[index]
        
        print("⏳ 手动执行: \(command.name)")
        
        if command.delaySeconds > 0 {
            try? await Task.sleep(nanoseconds: UInt64(command.delaySeconds * 1_000_000_000))
        }
        
        let startTime = Date()
        let (output, errorOutput, exitCode) = await executeShellCommand(command.command)
        let duration = Date().timeIntervalSince(startTime)
        
        // 合并输出用于显示
        var displayOutput = ""
        if !output.isEmpty {
            displayOutput = output
        }
        if !errorOutput.isEmpty {
            if !displayOutput.isEmpty {
                displayOutput += "\n"
            }
            displayOutput += errorOutput
        }
        if displayOutput.isEmpty {
            displayOutput = "已执行"
        }
        
        if let updatedIndex = commands.firstIndex(where: { $0.id == commandId }) {
            commands[updatedIndex].executionTime = Date()
            commands[updatedIndex].lastOutput = displayOutput
            commands[updatedIndex].exitCode = exitCode
            commands[updatedIndex].executionCount += 1
        }
        
        let log = ExecutionLog(
            id: UUID(),
            commandId: commandId,
            commandName: command.name,
            timestamp: Date(),
            output: output,
            errorOutput: errorOutput,
            exitCode: exitCode,
            executionType: .manual,
            duration: duration
        )
        addLog(log)
        
        executingCommandId = nil
        print("✅ 手动执行完成: \(command.name) (耗时 \(String(format: "%.2f", duration))s, 退出码: \(exitCode))")
    }
    
    func executeEnabledCommandsOnStartup() {
        print("🚀 开始执行启动命令...")
        let enabledCommands = commands.filter { $0.isEnabled }.sorted { $0.delaySeconds < $1.delaySeconds }
        
        guard !enabledCommands.isEmpty else {
            print("ℹ️ 没有可用的启动命令")
            return
        }
        
        Task(priority: .background) {
            for command in enabledCommands {
                while await executingCommandId != nil {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
                
                if command.delaySeconds > 0 {
                    print("⏰ 延迟 \(command.delaySeconds)秒后执行: \(command.name)")
                    try? await Task.sleep(nanoseconds: UInt64(command.delaySeconds * 1_000_000_000))
                }
                
                print("⏳ [启动] 正在执行: \(command.name)")
                
                let startTime = Date()
                let (output, errorOutput, exitCode) = await executeShellCommand(command.command)
                let duration = Date().timeIntervalSince(startTime)
                
                var displayOutput = ""
                if !output.isEmpty {
                    displayOutput = output
                }
                if !errorOutput.isEmpty {
                    if !displayOutput.isEmpty {
                        displayOutput += "\n"
                    }
                    displayOutput += errorOutput
                }
                if displayOutput.isEmpty {
                    displayOutput = "已执行"
                }
                
                await MainActor.run {
                    if let index = commands.firstIndex(where: { $0.id == command.id }) {
                        commands[index].executionTime = Date()
                        commands[index].lastOutput = displayOutput
                        commands[index].exitCode = exitCode
                        commands[index].executionCount += 1
                    }
                    
                    let log = ExecutionLog(
                        id: UUID(),
                        commandId: command.id,
                        commandName: command.name,
                        timestamp: Date(),
                        output: output,
                        errorOutput: errorOutput,
                        exitCode: exitCode,
                        executionType: .startup,
                        duration: duration
                    )
                    addLog(log)
                }
                
                print("✅ [启动] 执行完成: \(command.name) (耗时 \(String(format: "%.2f", duration))s, 退出码: \(exitCode))")
                
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
            print("🏁 启动命令执行完毕")
        }
    }
    
    // MARK: - Shell Execution
    private func executeShellCommand(_ command: String) async -> (output: String, errorOutput: String, exitCode: Int32) {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                // 关键:使用 -l 参数加载用户的 shell 配置(.zshrc 等)
                process.arguments = ["-l", "-c", command]
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                
                // 使用系统环境变量作为基础
                process.environment = ProcessInfo.processInfo.environment
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let errorOutput = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    
                    continuation.resume(returning: (output, errorOutput, process.terminationStatus))
                } catch {
                    continuation.resume(returning: ("", "执行失败: \(error.localizedDescription)", -1))
                }
            }
        }
    }
    
    // MARK: - Logs
    private func addLog(_ log: ExecutionLog) {
        executionLogs.insert(log, at: 0)
        if executionLogs.count > maxLogsCount {
            executionLogs = Array(executionLogs.prefix(maxLogsCount))
        }
    }
    
    func clearLogs() {
        executionLogs.removeAll()
        
        // 删除日志文件
        do {
            if FileManager.default.fileExists(atPath: logsFileURL.path) {
                try FileManager.default.removeItem(at: logsFileURL)
                print("🗑️ 日志文件已删除")
            }
        } catch {
            print("❌ 删除日志文件失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Persistence
    private func saveCommands() {
        if let encoded = try? JSONEncoder().encode(commands) {
            UserDefaults.standard.set(encoded, forKey: commandsKey)
        }
    }
    
    private func loadCommands() {
        if let data = UserDefaults.standard.data(forKey: commandsKey),
           let decoded = try? JSONDecoder().decode([StartupCommand].self, from: data) {
            commands = decoded
        }
    }
    
    private func saveLogs() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                
                let data = try encoder.encode(self.executionLogs)
                try data.write(to: self.logsFileURL, options: .atomic)
                
                print("💾 日志已保存到: \(self.logsFileURL.path)")
            } catch {
                print("❌ 保存日志失败: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadLogs() {
        do {
            guard FileManager.default.fileExists(atPath: logsFileURL.path) else {
                print("ℹ️ 日志文件不存在，将创建新文件")
                return
            }
            
            let data = try Data(contentsOf: logsFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            executionLogs = try decoder.decode([ExecutionLog].self, from: data)
            print("✅ 已加载 \(executionLogs.count) 条日志记录")
        } catch {
            print("❌ 加载日志失败: \(error.localizedDescription)")
            executionLogs = []
        }
    }
}
