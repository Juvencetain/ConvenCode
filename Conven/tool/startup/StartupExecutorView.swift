import SwiftUI

struct StartupExecutorView: View {
    @StateObject private var viewModel = StartupExecutorViewModel()
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerSection
                Divider()
                
                if viewModel.filteredCommands.isEmpty {
                    emptyStateView
                } else {
                    commandsListView
                }
                
                Divider()
                bottomBar
            }
        }
        .sheet(isPresented: $viewModel.showAddEditSheet) {
            AddEditCommandSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showLogsSheet) {
            LogsSheet(viewModel: viewModel)
        }
    }
    
    private var headerSection: some View {
        HStack {
            Label("启动执行", systemImage: "play.display")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.blue.gradient)
            
            Spacer()
            
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                TextField("搜索命令...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            .frame(width: 200)
            
            Button {
                viewModel.showLogsSheet = true
            } label: {
                Label("日志", systemImage: "list.bullet.clipboard")
                    .font(.system(size: 12))
            }
            .buttonStyle(ModernButtonStyle(style: .normal))
        }
        .padding(16)
    }
    
    private var commandsListView: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(viewModel.filteredCommands) { command in
                    if let index = viewModel.commands.firstIndex(where: { $0.id == command.id }) {
                        CommandCardView(
                            viewModel: viewModel,
                            command: $viewModel.commands[index]
                        )
                    }
                }
            }
            .padding(16)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundStyle(Color.secondary.opacity(0.5).gradient)
            Text("还没有启动命令")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
            Text("点击下方按钮添加命令")
                .font(.system(size: 13))
                .foregroundColor(.secondary.opacity(0.7))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.commandToEdit = nil
                viewModel.showAddEditSheet = true
            } label: {
                Label("添加命令", systemImage: "plus.circle.fill")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(ModernButtonStyle(style: .execute))
            .keyboardShortcut("n", modifiers: .command)
            
            Spacer()
            
            Text("\(viewModel.filteredCommands.count) 个命令")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(16)
    }
}

struct CommandCardView: View {
    @ObservedObject var viewModel: StartupExecutorViewModel
    @Binding var command: StartupCommand
    @State private var isHovered = false
    
    private var isLoading: Bool {
        viewModel.executingCommandId == command.id
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 32, height: 32)
                } else {
                    statusIcon
                }
            }
            .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(command.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isLoading ? .secondary : .primary)
                    
                    if command.delaySeconds > 0 {
                        Text("\(Int(command.delaySeconds))s")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
                
                Text(command.command)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if let lastRun = command.executionTime {
                    HStack(spacing: 10) {
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                            Text(lastRun, style: .relative)
                        }
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        
                        if command.executionCount > 0 {
                            Text("·").foregroundColor(.gray.opacity(0.5))
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("\(command.executionCount)次")
                            }
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        }
                        
                        if let exitCode = command.exitCode {
                            Text("·").foregroundColor(.gray.opacity(0.5))
                            HStack(spacing: 3) {
                                Image(systemName: "terminal")
                                Text("退出码: \(exitCode)")
                            }
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        }
                    }
                }
            }
            .opacity(isLoading ? 0.5 : 1.0)
            
            Spacer()
            
            if isHovered && !isLoading {
                HStack(spacing: 8) {
                    Button {
                        Task {
                            await viewModel.executeSingleCommand(commandId: command.id)
                        }
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                    .help("立即执行")
                    
                    Button {
                        viewModel.commandToEdit = command
                        viewModel.showAddEditSheet = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.orange)
                    .help("编辑")
                    
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.deleteCommand(command)
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                    .help("删除")
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
            
            Toggle("", isOn: $command.isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .scaleEffect(0.75)
                .frame(width: 40)
                .disabled(isLoading)
                .opacity(isLoading ? 0.5 : 1.0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(isHovered ? 0.12 : 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
        .onHover { hovering in
            if !isLoading {
                isHovered = hovering
            }
        }
    }
    
    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.2))
                .frame(width: 32, height: 32)
            
            Image(systemName: statusIconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(statusColor.gradient)
        }
    }
    
    private var statusIconName: String {
        if !command.isEnabled {
            return "pause.circle.fill"
        }
        if command.executionCount == 0 {
            return "circle"
        }
        return "terminal.fill"
    }
    
    private var statusColor: Color {
        if !command.isEnabled {
            return .orange
        }
        if command.executionCount == 0 {
            return .gray
        }
        return .blue
    }
}

struct AddEditCommandSheet: View {
    @ObservedObject var viewModel: StartupExecutorViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = ""
    @State private var command: String = ""
    @State private var isEnabled: Bool = true
    @State private var delaySeconds: Double = 0
    
    private var isEditing: Bool { viewModel.commandToEdit != nil }
    private var title: String { isEditing ? "编辑命令" : "添加命令" }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !command.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text(title)
                    .font(.title2)
                
                TextField("名称 (例如:启动 Docker)", text: $name)
                TextField("命令 (例如:open -a Docker)", text: $command)
                    .font(.system(.body, design: .monospaced))
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("延迟执行")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text("\(Int(delaySeconds)) 秒")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                    }
                    Slider(value: $delaySeconds, in: 0...60, step: 1)
                        .tint(.orange)
                }
                
                Toggle("启动时自动执行", isOn: $isEnabled)
                
                HStack {
                    Button("取消", role: .cancel) { dismiss() }
                        .buttonStyle(ModernButtonStyle(style: .normal))
                        .keyboardShortcut(.cancelAction)
                    
                    Spacer()
                    
                    Button(isEditing ? "保存" : "添加") {
                        saveCommand()
                    }
                    .buttonStyle(ModernButtonStyle(style: .execute))
                    .keyboardShortcut(.return)
                    .disabled(!canSave)
                }
            }
            .padding(24)
        }
        .frame(width: 500, height: 400)
        .onAppear {
            if let cmd = viewModel.commandToEdit {
                name = cmd.name
                command = cmd.command
                isEnabled = cmd.isEnabled
                delaySeconds = cmd.delaySeconds
            }
        }
    }
    
    private func saveCommand() {
        let cmd = StartupCommand(
            id: viewModel.commandToEdit?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            command: command.trimmingCharacters(in: .whitespaces),
            isEnabled: isEnabled,
            delaySeconds: delaySeconds
        )
        
        if isEditing {
            viewModel.updateCommand(cmd)
        } else {
            viewModel.addCommand(cmd)
        }
        
        dismiss()
    }
}

struct LogsSheet: View {
    @ObservedObject var viewModel: StartupExecutorViewModel
    @Environment(\.dismiss) var dismiss
    @State private var filterType: FilterType = .all
    
    enum FilterType: String, CaseIterable {
        case all = "全部"
        case startup = "启动"
        case manual = "手动"
    }
    
    private var filteredLogs: [ExecutionLog] {
        viewModel.executionLogs.filter { log in
            switch filterType {
            case .all: return true
            case .startup: return log.executionType == .startup
            case .manual: return log.executionType == .manual
            }
        }
    }
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Label("执行日志", systemImage: "list.bullet.clipboard.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.blue.gradient)
                    
                    Spacer()
                    
                    Button {
                        viewModel.clearLogs()
                    } label: {
                        Label("清空", systemImage: "trash")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(ModernButtonStyle(style: .danger))
                    .disabled(viewModel.executionLogs.isEmpty)
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                
                Divider()
                
                HStack(spacing: 8) {
                    ForEach(FilterType.allCases, id: \.self) { type in
                        Button(type.rawValue) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                filterType = type
                            }
                        }
                        .buttonStyle(ModernButtonStyle(style: filterType == type ? .accent : .normal))
                    }
                    
                    Spacer()
                    
                    Text("\(filteredLogs.count) 条记录")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.03))
                
                Divider()
                
                if filteredLogs.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "tray")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.secondary.opacity(0.5).gradient)
                        Text("暂无日志记录")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredLogs) { log in
                                LogRowView(log: log)
                            }
                        }
                        .padding(20)
                    }
                }
            }
        }
        .frame(width: 700, height: 600)
    }
}

struct LogRowView: View {
    let log: ExecutionLog
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.blue.gradient)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(log.commandName)
                                .font(.system(size: 13, weight: .medium))
                            
                            Text(log.executionType.rawValue)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.12))
                                .cornerRadius(4)
                            
                            Text(String(format: "%.2fs", log.duration))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.12))
                                .cornerRadius(4)
                            
                            Text("退出码: \(log.exitCode)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.12))
                                .cornerRadius(4)
                        }
                        
                        HStack(spacing: 8) {
                            Text(log.timestamp, style: .date)
                            Text(log.timestamp, style: .time)
                        }
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color.white.opacity(0.04))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    if !log.output.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("标准输出 (stdout):")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text(log.output)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(6)
                        }
                    }
                    
                    if !log.errorOutput.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("标准错误 (stderr):")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text(log.errorOutput)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(6)
                        }
                    }
                    
                    if log.output.isEmpty && log.errorOutput.isEmpty {
                        Text("无输出")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.02))
            }
        }
        .background(Color.white.opacity(0.04))
        .cornerRadius(8)
    }
}
