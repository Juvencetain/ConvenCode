import SwiftUI

// MARK: - Startup Executor Main View
struct StartupExecutorView: View {
    @StateObject private var startupExecutorViewModel = StartupExecutorViewModel()

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                startupExecutorHeaderBar
                Divider().padding(.horizontal, 16)

                if startupExecutorViewModel.startupExecutorIsLoading {
                    Spacer()
                    ProgressView("正在加载命令...")
                    Spacer()
                } else if startupExecutorViewModel.startupExecutorCommands.isEmpty {
                    startupExecutorEmptyState
                } else {
                    // 使用 ScrollView + LazyVStack 代替 List
                    startupExecutorCommandScrollView
                }

                Divider().padding(.horizontal, 16)
                startupExecutorBottomBar
            }
        }
        .frame(width: 550, height: 450)
        .sheet(isPresented: $startupExecutorViewModel.startupExecutorShowAddEditSheet) {
            AddEditStartupCommandView(viewModel: startupExecutorViewModel)
        }
        .focusable(false)
    }

    // MARK: - Subviews
    private var startupExecutorHeaderBar: some View {
        HStack {
            Image(systemName: "play.display")
                .font(.system(size: 16))
                .foregroundStyle(.blue.gradient)
            Text("启动执行")
                .font(.system(size: 14, weight: .medium))
            Spacer()
            // 可以在这里添加刷新按钮等
        }
        .padding(16)
    }

    private var startupExecutorEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.5))
            Text("还没有添加启动命令")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Button("添加第一个命令") {
                startupExecutorViewModel.startupExecutorCommandToEdit = nil // 确保是添加模式
                startupExecutorViewModel.startupExecutorShowAddEditSheet = true
            }
            .buttonStyle(ModernButtonStyle(style: .accent)) // 使用 ModernButtonStyle
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // 将 List 替换为包含自定义卡片的 ScrollView
    private var startupExecutorCommandScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 10) { // 在卡片之间添加间距
                // 传递 viewModel 并更新 onExecute 闭包
                ForEach($startupExecutorViewModel.startupExecutorCommands) { $command in
                    StartupCommandCard( // 使用新的卡片视图
                        viewModel: startupExecutorViewModel, // 传递 viewModel
                        command: $command,
                        onEdit: {
                            startupExecutorViewModel.startupExecutorCommandToEdit = command
                            startupExecutorViewModel.startupExecutorShowAddEditSheet = true
                        },
                        onDelete: {
                            startupExecutorViewModel.startupExecutorDeleteCommand(command)
                        },
                        onExecute: {
                             Task { // 使用 Task 进行异步调用
                                await startupExecutorViewModel.startupExecutorExecuteSingleCommand(commandId: command.id) // 调用新方法
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 16) // 为 VStack 添加内边距
            .padding(.vertical, 12)
        }
    }


    private var startupExecutorBottomBar: some View {
        HStack {
            Button {
                startupExecutorViewModel.startupExecutorCommandToEdit = nil // 添加模式
                startupExecutorViewModel.startupExecutorShowAddEditSheet = true
            } label: {
                Label("添加命令", systemImage: "plus")
                    .font(.system(size: 12, weight: .medium)) // 统一字体
            }
            .buttonStyle(ModernButtonStyle(style: .normal)) // 使用 ModernButtonStyle
            .keyboardShortcut("n", modifiers: .command)

            Spacer()
            // 可以在这里添加“全部禁用/启用”等按钮
        }
        .padding(16)
    }
}

// MARK: - [新增] 命令卡片视图
struct StartupCommandCard: View {
    // 观察 viewModel 以获取执行状态
    @ObservedObject var viewModel: StartupExecutorViewModel
    @Binding var command: StartupCommand
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onExecute: () -> Void // 添加了立即执行的操作

    @State private var isHovered = false
    // 计算属性用于判断加载状态
    private var isLoading: Bool {
        viewModel.startupExecutorExecutingCommandId == command.id
    }


    var body: some View {
        HStack(spacing: 12) {
            // 图标或进度指示器
            ZStack { // 使用 ZStack 叠加 ProgressView
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.6) // 使加载指示器小一点
                        .frame(width: 24, height: 24)
                        .transition(.opacity.combined(with: .scale)) // 添加过渡动画
                } else {
                    Image(systemName: command.startupExecutorIsEnabled ? "play.circle.fill" : "pause.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(command.startupExecutorIsEnabled ? Color.green.gradient : Color.orange.gradient)
                        .frame(width: 24, height: 24) // 固定宽度用于对齐
                        .transition(.opacity.combined(with: .scale)) // 添加过渡动画
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isLoading) // 为过渡添加动画

            VStack(alignment: .leading, spacing: 4) {
                Text(command.startupExecutorName)
                    .font(.system(size: 13, weight: .semibold)) // 稍大字体
                    .foregroundColor(isLoading ? .secondary : .primary) // 加载时文字变暗
                    .lineLimit(1)

                Text(command.startupExecutorCommand)
                    .font(.system(size: 11, design: .monospaced)) // 等宽字体用于命令
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                // 状态信息（上次运行，输出）
                HStack(spacing: 8) {
                    if let lastRun = command.startupExecutorExecutionTime {
                        HStack(spacing: 3){
                             Image(systemName: "clock")
                             Text("\(lastRun, style: .relative) ago") // 相对时间
                         }
                         .font(.system(size: 9))
                         .foregroundColor(.gray)
                    }
                     if let output = command.startupExecutorLastOutput, !output.isEmpty {
                         Text("|") // 分隔符
                            .font(.system(size: 9))
                            .foregroundColor(.gray.opacity(0.5))
                         HStack(spacing: 3) {
                             // 根据输出内容判断成功或失败图标
                             Image(systemName: output.localizedCaseInsensitiveContains("错误") ? "xmark.circle" : "checkmark.circle")
                             Text(output)
                                 .lineLimit(1) // 限制单行
                         }
                        .font(.system(size: 9))
                         // 根据输出内容判断成功或失败颜色
                        .foregroundColor(output.localizedCaseInsensitiveContains("错误") ? .red : .gray)

                     }
                }
                .opacity(isLoading ? 0.5 : 1.0) // 加载时状态变暗
            }
            .animation(.easeInOut(duration: 0.2), value: isLoading) // 为变暗添加动画

            Spacer() // 将开关推到右侧

            // 悬停时显示的操作按钮（加载时不显示）
            if isHovered && !isLoading { // 加载时不显示操作按钮
                HStack(spacing: 8) {
                     Button(action: onExecute) {
                         Image(systemName: "play.fill") // 执行图标
                             .font(.system(size: 11))
                     }
                     .buttonStyle(.plain)
                     .foregroundColor(.blue)
                     .help("立即执行")

                    Button(action: onEdit) {
                        Image(systemName: "pencil") // 编辑图标
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.orange)
                    .help("编辑")

                    Button(action: onDelete) {
                        Image(systemName: "trash") // 删除图标
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                    .help("删除")
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8))) // 添加过渡动画
            }


            Toggle("", isOn: $command.startupExecutorIsEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .scaleEffect(0.75) // 使开关小一点
                .frame(width: 40) // 给开关固定空间
                .padding(.leading, (isHovered && !isLoading) ? 0 : 8) // 根据悬停状态调整内边距（仅当未加载时）
                .disabled(isLoading) // 加载时禁用开关
                .opacity(isLoading ? 0.5 : 1.0) // 加载时开关变暗
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                // 调整悬停时的背景透明度
                .fill(Color.white.opacity(isHovered ? 0.12 : 0.06))
        )
        .overlay(
             RoundedRectangle(cornerRadius: 10)
                // 悬停时添加微妙的边框
                .stroke(isHovered ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isHovered) // 为悬停效果添加动画
        .animation(.easeInOut(duration: 0.2), value: isLoading) // 为加载状态变化添加动画
        .onHover { hovering in
            // 仅当未加载时才允许悬停效果
            if !isLoading {
                isHovered = hovering
            } else {
                 isHovered = false // 确保加载时关闭悬停效果
            }
        }
    }
}


// MARK: - 添加/编辑命令 Sheet 视图 (无需更改)
struct AddEditStartupCommandView: View {
    @ObservedObject var viewModel: StartupExecutorViewModel
    @Environment(\.dismiss) var dismiss

    @State private var startupExecutorName: String = ""
    @State private var startupExecutorCommand: String = ""
    @State private var startupExecutorIsEnabled: Bool = true

    private var startupExecutorIsEditing: Bool { viewModel.startupExecutorCommandToEdit != nil }
    private var startupExecutorTitle: String { startupExecutorIsEditing ? "编辑命令" : "添加命令" }

    var body: some View {
         ZStack {
             VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow).ignoresSafeArea()
             VStack(spacing: 20) {
                 Text(startupExecutorTitle)
                     .font(.title2)

                 TextField("名称 (例如：启动 Docker)", text: $startupExecutorName)
                 TextField("命令 (例如：open -a Docker)", text: $startupExecutorCommand)
                     .font(.system(.body, design: .monospaced)) // 等宽字体

                 Toggle("启动时自动执行", isOn: $startupExecutorIsEnabled)

                 HStack {
                     Button("取消", role: .cancel) { dismiss() }
                         .buttonStyle(ModernButtonStyle(style: .normal)) // 使用 ModernButtonStyle
                         .keyboardShortcut(.cancelAction)

                     Spacer()

                     Button(startupExecutorIsEditing ? "保存" : "添加") {
                         saveChanges()
                         dismiss()
                     }
                     .buttonStyle(ModernButtonStyle(style: .execute)) // 使用 ModernButtonStyle
                     .disabled(startupExecutorName.isEmpty || startupExecutorCommand.isEmpty)
                     .keyboardShortcut(.defaultAction)
                 }
             }
             .textFieldStyle(.roundedBorder) // 在 sheet 中保持圆角边框样式
             .padding(30)
         }
        .frame(width: 450, height: 300)
        .onAppear {
            if let command = viewModel.startupExecutorCommandToEdit {
                startupExecutorName = command.startupExecutorName
                startupExecutorCommand = command.startupExecutorCommand
                startupExecutorIsEnabled = command.startupExecutorIsEnabled
            }
        }
    }

    private func saveChanges() {
        if let editingCommand = viewModel.startupExecutorCommandToEdit {
            var updatedCommand = editingCommand
            updatedCommand.startupExecutorName = startupExecutorName
            updatedCommand.startupExecutorCommand = startupExecutorCommand
            updatedCommand.startupExecutorIsEnabled = startupExecutorIsEnabled
            viewModel.startupExecutorUpdateCommand(updatedCommand)
        } else {
            viewModel.startupExecutorAddCommand(name: startupExecutorName, command: startupExecutorCommand)
        }
    }
}

// MARK: - Preview
#Preview {
    StartupExecutorView()
}
