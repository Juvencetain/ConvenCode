import SwiftUI
import Combine
import Foundation
import UserNotifications // 导入 UserNotifications

// MARK: - Startup Command Model
struct StartupCommand: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var startupExecutorName: String // 名称，方便用户识别
    var startupExecutorCommand: String // 要执行的命令
    var startupExecutorIsEnabled: Bool = true // 是否启用
    var startupExecutorExecutionTime: Date? // 上次执行时间 (可选)
    var startupExecutorLastOutput: String? // 上次执行输出 (可选)

    init(id: UUID = UUID(), name: String, command: String, isEnabled: Bool = true) {
        self.id = id
        self.startupExecutorName = name
        self.startupExecutorCommand = command
        self.startupExecutorIsEnabled = isEnabled
    }
}

// MARK: - Startup Executor ViewModel
@MainActor
class StartupExecutorViewModel: ObservableObject {
    @Published var startupExecutorCommands: [StartupCommand] = []
    @Published var startupExecutorIsLoading: Bool = false // 整体加载状态（用于初始加载）
    @Published var startupExecutorShowAddEditSheet = false
    @Published var startupExecutorCommandToEdit: StartupCommand?
    // [新增] 跟踪当前手动执行的命令 ID
    @Published var startupExecutorExecutingCommandId: UUID? = nil

    private let startupExecutorStorageKey = "startup_executor_commands"
    private var cancellables = Set<AnyCancellable>()

    init() {
        startupExecutorLoadCommands()
        // 监听命令数组变化并自动保存
        $startupExecutorCommands
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.startupExecutorSaveCommands()
            }
            .store(in: &cancellables)
        // 可选：如果尚未在 AppDelegate 中请求权限，可以在此处请求
        // startupExecutorRequestNotificationPermission()
    }

    // MARK: - Command Management
    func startupExecutorAddCommand(name: String, command: String) {
        let newCommand = StartupCommand(name: name, command: command)
        startupExecutorCommands.append(newCommand)
    }

    func startupExecutorUpdateCommand(_ command: StartupCommand) {
        if let index = startupExecutorCommands.firstIndex(where: { $0.id == command.id }) {
            startupExecutorCommands[index] = command
        }
    }

    func startupExecutorDeleteCommand(at offsets: IndexSet) {
        startupExecutorCommands.remove(atOffsets: offsets)
    }

    func startupExecutorDeleteCommand(_ command: StartupCommand) {
        startupExecutorCommands.removeAll { $0.id == command.id }
    }

    func startupExecutorToggleCommand(_ command: StartupCommand) {
        // 由于 SwiftUI 的 @Binding，这个方法可能不再需要手动调用，
        // 但保留它以防万一有其他地方需要切换状态
        if let index = startupExecutorCommands.firstIndex(where: { $0.id == command.id }) {
            startupExecutorCommands[index].startupExecutorIsEnabled.toggle()
        }
    }

    // MARK: - Execution Logic

    // [新增] 手动执行单个命令并更新其状态的函数
    func startupExecutorExecuteSingleCommand(commandId: UUID) async {
        guard startupExecutorExecutingCommandId == nil else {
            print("⚠️ 另一个命令正在执行中。")
            return // 为简单起见，防止并发手动执行
        }

        // 查找命令索引
        guard let index = startupExecutorCommands.firstIndex(where: { $0.id == commandId }) else {
            print("❌ 未找到要执行的命令。")
            return
        }

        // 设置此特定命令的加载状态
        startupExecutorExecutingCommandId = commandId
        let commandToExecute = startupExecutorCommands[index] // 获取一个副本

        print("⏳ 手动执行: \(commandToExecute.startupExecutorName) (\(commandToExecute.startupExecutorCommand))")
        let (output, errorOutput, exitCode) = await executeShellCommand(commandToExecute.startupExecutorCommand)

        // 在主线程上更新数组中的命令
        // 重新查找索引以防数组发生更改（虽然在这里不太可能，但这是好习惯）
        if let updatedIndex = startupExecutorCommands.firstIndex(where: { $0.id == commandId }) {
            startupExecutorCommands[updatedIndex].startupExecutorExecutionTime = Date()
            if exitCode == 0 {
                startupExecutorCommands[updatedIndex].startupExecutorLastOutput = output.isEmpty ? "执行成功 (手动)" : output
                print("✅ 手动执行成功: \(commandToExecute.startupExecutorName)")
            } else {
                // [修改] 明确标记错误来源
                startupExecutorCommands[updatedIndex].startupExecutorLastOutput = "错误 (手动): \(errorOutput)"
                print("❌ 手动执行失败: \(commandToExecute.startupExecutorName) - \(errorOutput)")
            }
        }

        // 清除加载状态
        startupExecutorExecutingCommandId = nil
    }

    // 应用启动时执行所有启用的命令
    func startupExecutorExecuteEnabledCommands() {
        print("🚀 开始执行启动命令...")
        let enabledCommands = startupExecutorCommands.filter { $0.startupExecutorIsEnabled }
        guard !enabledCommands.isEmpty else {
            print("ℹ️ 没有启用的启动命令。")
            return
        }

        Task(priority: .background) {
            for command in enabledCommands {
                // 如果有命令正在手动执行，短暂等待
                while await startupExecutorExecutingCommandId != nil {
                     try? await Task.sleep(nanoseconds: 500_000_000) // 等待 0.5 秒
                }

                print("⏳ [启动] 正在执行: \(command.startupExecutorName) (\(command.startupExecutorCommand))")
                let (output, errorOutput, exitCode) = await executeShellCommand(command.startupExecutorCommand)

                // 在 MainActor 上更新 UI 状态
                await MainActor.run {
                    if let index = startupExecutorCommands.firstIndex(where: { $0.id == command.id }) {
                        startupExecutorCommands[index].startupExecutorExecutionTime = Date()
                        if exitCode == 0 {
                             // [修改] 明确标记来源
                            startupExecutorCommands[index].startupExecutorLastOutput = output.isEmpty ? "执行成功 (启动)" : output
                            print("✅ [启动] 执行成功: \(command.startupExecutorName)")
                        } else {
                             // [修改] 明确标记错误来源
                            startupExecutorCommands[index].startupExecutorLastOutput = "错误 (启动): \(errorOutput)"
                            print("❌ [启动] 执行失败: \(command.startupExecutorName) - \(errorOutput)")
                        }
                    }
                }

                // 发送通知
                startupExecutorSendNotification(
                    commandName: command.startupExecutorName,
                    success: exitCode == 0,
                    message: exitCode == 0 ? (output.isEmpty ? "已成功执行。" : output) : errorOutput
                )

                // 短暂延迟
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 秒
            }
            print("🏁 启动命令执行完毕。")
        }
    }

    // 发送通知的函数
    private func startupExecutorSendNotification(commandName: String, success: Bool, message: String) {
        let content = UNMutableNotificationContent()
        content.title = "启动命令: \(commandName)"
        content.subtitle = success ? "✅ 执行成功" : "❌ 执行失败"
        content.body = message.isEmpty ? (success ? "命令已完成。" : "执行出错，请检查。") : message
        content.sound = success ? UNNotificationSound.default : UNNotificationSound(named: UNNotificationSoundName("Funk")) // 错误时使用不同声音（可选）

        // 使用命令 ID 和时间戳确保唯一性
        let identifier = "startup_\(commandName)_\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil) // 立即触发

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ 发送启动命令通知失败 for \(commandName): \(error.localizedDescription)")
            } else {
                print("📨 已发送启动命令通知 for \(commandName)")
            }
        }
    }

    /* // 可选：如果需要在此处请求通知权限
    private func startupExecutorRequestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("✅ StartupExecutor: 已获得通知权限。")
            } else if let error = error {
                print("❌ StartupExecutor: 请求通知权限错误: \(error.localizedDescription)")
            }
        }
    }
    */

    // 辅助函数：执行 Shell 命令 (移除 private)
    func executeShellCommand(_ command: String) async -> (output: String, error: String, exitCode: Int32) {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh") // 使用 zsh
            process.arguments = ["-c", command] // 使用 -c 参数执行命令字符串

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let error = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                continuation.resume(returning: (output, error, process.terminationStatus))
            } catch {
                continuation.resume(returning: ("", "启动进程失败: \(error.localizedDescription)", -1))
            }
        }
    }

    // MARK: - Persistence
    private func startupExecutorLoadCommands() {
        self.startupExecutorIsLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            guard let data = UserDefaults.standard.data(forKey: self.startupExecutorStorageKey),
                  let commands = try? JSONDecoder().decode([StartupCommand].self, from: data) else {
                DispatchQueue.main.async {
                    self.startupExecutorIsLoading = false
                    print("ℹ️ 未找到保存的启动命令，或解码失败。")
                }
                return
            }
            DispatchQueue.main.async {
                self.startupExecutorCommands = commands
                self.startupExecutorIsLoading = false
                print("✅ 成功加载 \(commands.count) 条启动命令。")
            }
        }
    }

    private func startupExecutorSaveCommands() {
        // 使用 Task 确保在后台线程执行
        Task(priority: .background) {
             if let encoded = try? JSONEncoder().encode(self.startupExecutorCommands) {
                UserDefaults.standard.set(encoded, forKey: self.startupExecutorStorageKey)
                // 在 MainActor 上打印日志是安全的
                await MainActor.run {
                    print("💾 已保存 \(self.startupExecutorCommands.count) 条启动命令。")
                }
            } else {
                 await MainActor.run {
                    print("❌ 保存启动命令失败。")
                }
            }
        }
    }
}
