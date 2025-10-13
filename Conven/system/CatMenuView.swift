import SwiftUI

// MARK: - 主菜单视图
struct CatMenuView: View {
    @ObservedObject var viewModel: CatViewModel
    @State private var showSettings = false
    @State private var showTools = false
    @State private var showStatistics = false
    @State private var showAbout = false
    @State private var showManageTools = false
    @State private var showQuitConfirmation = false
    @State private var showDetailStats = false
    @State private var pinnedTools: [AppTool] = []
    
    var body: some View {
        ZStack {
            // 毛玻璃背景
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(1)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 头部信息
                headerSection
                
                Divider()
                    .padding(.horizontal, 16)
                
                // 状态区域
                if viewModel.isAlive {
                    statsSection
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    deathSection
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                Divider()
                    .padding(.horizontal, 16)
                
                // 操作按钮区域
                if viewModel.isAlive {
                    actionsSection
                } else {
                    restartSection
                }
                
                // 固定工具栏（在操作按钮后面）
                if viewModel.isAlive && !pinnedTools.isEmpty {
                    Divider()
                        .padding(.horizontal, 16)
                    
                    PinnedToolsBar(
                        pinnedTools: $pinnedTools,
                        onToolTap: { tool in
                            openToolWindow(tool.type)
                        },
                        onManage: {
                            showManageTools = true
                        }
                    )
                }
                
                Divider()
                    .padding(.horizontal, 16)
                                
                if viewModel.isAlive {
                    UsageStatsCard()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 12)
                }
                
                Divider()
                    .padding(.horizontal, 16)
                
                // 底部菜单
                bottomMenu
            }
        }
        .frame(width: CatConfig.UI.menuWidth)
        .focusable(false)
        .onAppear {
            pinnedTools = PinnedToolsManager.shared.load()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(viewModel: viewModel)
        }
        .sheet(isPresented: $showDetailStats) {
            UsageStatisticsDetailView()
        }
        .sheet(isPresented: $showTools) {
            ToolsMenuView(viewModel: viewModel)
        }
        .sheet(isPresented: $showStatistics) {
            CatStatisticsView(viewModel: viewModel)
        }
        .sheet(isPresented: $showManageTools) {
            ManageToolsView(pinnedTools: $pinnedTools)
        }
        .alert("确定要退出吗？", isPresented: $showQuitConfirmation) {
            Button("取消", role: .cancel) { }
            Button("退出", role: .destructive) {
                NSApplication.shared.terminate(nil)
            }
        } message: {
            Text("退出后小猫会继续在后台成长哦")
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack(spacing: 12) {
            // 小猫头像（使用配置的头像）
            ZStack {
                Circle()
                    .fill(viewModel.isAlive ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Text(CatConfig.Info.avatarEmoji)
                    .font(.system(size: 28))
                    .rotationEffect(.degrees(viewModel.isAlive ? 0 : -15))
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: viewModel.isAlive)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.catName)
                    .font(.system(size: 16, weight: .semibold))
                
                HStack(spacing: 6) {
                    Image(systemName: viewModel.isAlive ? "heart.fill" : "heart.slash.fill")
                        .font(.system(size: 10))
                        .foregroundColor(viewModel.isAlive ? .red : .gray)
                    
                    Text(viewModel.isAlive ? "活跃中" : "已离世")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Text("·")
                        .foregroundColor(.secondary)
                    
                    Text("第 \(viewModel.getLiveDays()) 天")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 设置按钮
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Stats Section
    private var statsSection: some View {
        VStack(spacing: 12) {
            StatBar(
                icon: "face.smiling.fill",
                label: "心情",
                value: viewModel.mood,
                color: .blue
            )
            
            StatBar(
                icon: "fork.knife",
                label: "饥饿",
                value: viewModel.hunger,
                color: .orange
            )
            
            StatBar(
                icon: "sparkles",
                label: "清洁",
                value: viewModel.cleanliness,
                color: .green
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Death Section
    private var deathSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 48))
                .foregroundStyle(.gray.gradient)
            
            Text("\(viewModel.catName)永远地睡着了...")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Text("陪伴了你 \(viewModel.getLiveDays()) 天")
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
    
    // MARK: - Actions Section
    private var actionsSection: some View {
        HStack(spacing: 12) {
            ActionButton(
                icon: "gamecontroller.fill",
                label: "陪玩",
                color: .blue,
                action: viewModel.play
            )
            
            ActionButton(
                icon: "fork.knife.circle.fill",
                label: "喂食",
                color: .orange,
                action: viewModel.feed
            )
            
            ActionButton(
                icon: "sparkles",
                label: "清洁",
                color: .green,
                action: viewModel.clean
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Restart Section
    private var restartSection: some View {
        Button(action: viewModel.restart) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 16))
                Text("重新开始")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.gradient)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .pointingHandCursor()
    }
    
    // MARK: - Bottom Menu
    private var bottomMenu: some View {
        HStack(spacing: 0) {
            MenuButton(
                icon: "chart.bar.fill",
                label: "统计",
                action: { showStatistics = true }
            )
            
            Divider()
                .frame(height: 20)
            
            MenuButton(
                icon: "wrench.and.screwdriver.fill",
                label: "工具",
                action: { showTools = true }
            )
            
            Divider()
                .frame(height: 20)
            
            MenuButton(
                icon: "info.circle.fill",
                label: "关于",
                action: { showAbout = true }
            )
            
            Divider()
                .frame(height: 20)
            
            MenuButton(
                icon: "power",
                label: "退出",
                action: { showQuitConfirmation = true }
            )
        }
        .frame(height: 44)
        .background(Color.black.opacity(0.05))
    }
}

// MARK: - 设置视图
struct SettingsView: View {
    @ObservedObject var viewModel: CatViewModel
    @Environment(\.dismiss) var dismiss
    @State private var newName: String = ""
    @State private var selectedAvatar: String = ""
    @State private var aiPushEnabled: Bool = true
    @State private var showSaveSuccess = false
    @State private var showAvatarPicker = false
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(1)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 标题栏
                HStack {
                    Text("设置")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Spacer()
                    
                    // 保存成功提示
                    if showSaveSuccess {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                            Text("已保存")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.green)
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Divider()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 头像和基本信息
                        settingSection(title: "基本信息") {
                            // 头像选择
                            Button(action: { showAvatarPicker.toggle() }) {
                                HStack {
                                    Text("头像")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Text(selectedAvatar)
                                        .font(.system(size: 28))
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .pointingHandCursor()
                            
                            Divider()
                            
                            HStack {
                                Text("名字")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                
                                TextField("小猫的名字", text: $newName)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 13))
                                    .multilineTextAlignment(.trailing)
                                    .onSubmit {
                                        saveName()
                                    }
                                
                                if newName != viewModel.catName && !newName.isEmpty {
                                    Button(action: saveName) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.green)
                                    }
                                    .buttonStyle(.plain)
                                    .pointingHandCursor()
                                    .transition(.scale)
                                }
                            }
                            
                            Divider()
                            
                            HStack {
                                Text("品种")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(CatConfig.Info.breed)
                                    .font(.system(size: 13))
                            }
                            
                            Divider()
                            
                            HStack {
                                Text("存活天数")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(viewModel.getLiveDays()) 天")
                                    .font(.system(size: 13, weight: .medium))
                            }
                        }
                        
                        // 统计数据
                        settingSection(title: "互动统计") {
                            statRow(icon: "gamecontroller.fill", label: "陪玩次数", value: viewModel.totalPlayCount, color: .blue)
                            Divider()
                            statRow(icon: "fork.knife", label: "喂食次数", value: viewModel.totalFeedCount, color: .orange)
                            Divider()
                            statRow(icon: "sparkles", label: "清洁次数", value: viewModel.totalCleanCount, color: .green)
                            
                            Divider()
                            
                            HStack {
                                Text("总互动")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(viewModel.totalPlayCount + viewModel.totalFeedCount + viewModel.totalCleanCount)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.accentColor)
                                    .monospacedDigit()
                            }
                        }
                        
                        // 通知设置
                        settingSection(title: "通知设置") {
                            Toggle(isOn: $aiPushEnabled) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("启用AI日常推送")
                                        .font(.system(size: 13))
                                    Text("每小时推送一条温馨消息")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .toggleStyle(.switch)
                            .onChange(of: aiPushEnabled) { newValue in
                                saveAIPushSetting(newValue)
                            }
                            
                            Divider()
                            
                            HStack {
                                Text("推送间隔")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(CatConfig.Notification.aiPushInterval / 60)) 分钟")
                                    .font(.system(size: 13))
                            }
                        }
                        
                        // 游戏设置
                        settingSection(title: "游戏设置") {
                            HStack {
                                Text("衰减间隔")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(CatConfig.GamePlay.decayInterval / 60)) 分钟")
                                    .font(.system(size: 13))
                            }
                            
                            Divider()
                            
                            HStack {
                                Text("每次增益")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("+\(Int(CatConfig.GamePlay.playIncrement))")
                                    .font(.system(size: 13))
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 380, height: 500)
        .focusable(false)
        .sheet(isPresented: $showAvatarPicker) {
            AvatarPickerView(selectedAvatar: $selectedAvatar) {
                saveAvatar()
            }
        }
        .onAppear {
            newName = viewModel.catName
            selectedAvatar = CatConfig.Info.avatarEmoji
            aiPushEnabled = CatConfig.Notification.aiPushEnabled
        }
    }
    
    private func saveName() {
        guard !newName.isEmpty, newName != viewModel.catName else { return }
        
        withAnimation {
            viewModel.updateCatName(newName)
            showSaveSuccess = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showSaveSuccess = false
            }
        }
    }
    
    private func saveAvatar() {
        CatConfig.Info.updateAvatar(selectedAvatar)
        
        withAnimation {
            showSaveSuccess = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showSaveSuccess = false
            }
        }
    }
    
    private func saveAIPushSetting(_ enabled: Bool) {
        CatConfig.Notification.aiPushEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "aiPushEnabled")
        
        withAnimation {
            showSaveSuccess = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showSaveSuccess = false
            }
        }
    }
    
    private func settingSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                content()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.1))
            )
        }
    }
    
    private func statRow(icon: String, label: String, value: Int, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(label)
                .font(.system(size: 13))
            
            Spacer()
            
            Text("\(value)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
    }
}

// MARK: - 头像选择器视图
struct AvatarPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedAvatar: String
    let onSave: () -> Void
    
    @State private var tempSelection: String
    
    init(selectedAvatar: Binding<String>, onSave: @escaping () -> Void) {
        self._selectedAvatar = selectedAvatar
        self.onSave = onSave
        self._tempSelection = State(initialValue: selectedAvatar.wrappedValue)
    }
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(1)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 标题栏
                HStack {
                    Text("选择头像")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Divider()
                
                // 预览区域
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 80, height: 80)
                        
                        Text(tempSelection)
                            .font(.system(size: 56))
                    }
                    
                    Text("当前选择")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color.black.opacity(0.05))
                
                Divider()
                
                // 头像网格
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(CatConfig.Info.availableAvatars, id: \.name) { category in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(category.name)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                                    ForEach(category.emojis, id: \.self) { emoji in
                                        Button(action: {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                tempSelection = emoji
                                            }
                                        }) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(tempSelection == emoji ? Color.blue.opacity(0.2) : Color.white.opacity(0.1))
                                                
                                                Text(emoji)
                                                    .font(.system(size: 28))
                                            }
                                            .frame(height: 50)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(tempSelection == emoji ? Color.blue : Color.clear, lineWidth: 2)
                                            )
                                            .scaleEffect(tempSelection == emoji ? 1.05 : 1.0)
                                        }
                                        .buttonStyle(.plain)
                                        .pointingHandCursor()
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
                
                Divider()
                
                // 底部按钮
                HStack(spacing: 12) {
                    Button(action: { dismiss() }) {
                        Text("取消")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                    
                    Button(action: {
                        selectedAvatar = tempSelection
                        onSave()
                        dismiss()
                    }) {
                        Text("确定")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.gradient)
                            )
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .frame(width: 420, height: 560)
        .focusable(false)
    }
}

// MARK: - 统计条组件
struct StatBar: View {
    let icon: String
    let label: String
    let value: Double
    let color: Color
    
    @State private var animatedValue: Double = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                    .frame(width: 16)
                
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(Int(value))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            
            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.15))
                    
                    // 前景
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.gradient)
                        .frame(width: geometry.size.width * (animatedValue / 100))
                }
            }
            .frame(height: 8)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animatedValue = value
            }
        }
        .onChange(of: value) { newValue in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                animatedValue = newValue
            }
        }
    }
}

// MARK: - 操作按钮组件
struct ActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
            action()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = false
                }
            }
        }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundStyle(color.gradient)
                }
                .scaleEffect(isPressed ? 0.85 : 1.0)
                
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
    }
}

// MARK: - 底部菜单按钮组件
struct MenuButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(isHovered ? .accentColor : .secondary)
                
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(isHovered ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .background(isHovered ? Color.white.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .pointingHandCursor()
    }
}

// MARK: - CatMenuView 的工具打开方法
extension CatMenuView {
    func openToolWindow(_ type: AppTool.ToolType) {
        // 使用统一的工具管理器
        ToolsManager.shared.openToolWindow(type, viewModel: viewModel)
    }
}

// MARK: - 工具菜单视图
struct ToolsMenuView: View {
    @Environment(\.dismiss) var dismiss
    let viewModel: CatViewModel
    // 从统一的工具管理器获取所有工具
    private var tools: [AppTool] {
        ToolsManager.shared.allTools
    }
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(1)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 标题栏
                HStack {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue.gradient)
                    
                    Text("工具箱")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Divider()
                
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(tools) { tool in
                            ToolCard(
                                icon: tool.icon,
                                name: tool.name,
                                color: tool.color
                            ) {
                                // 使用统一的工具管理器打开窗口
                                ToolsManager.shared.openToolWindow(tool.type, viewModel: viewModel)
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 380, height: 450)
        .focusable(false)
    }
}

// 临时的使用指南视图
struct GuideView: View {
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(1)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "book.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.purple.gradient)
                
                Text("使用指南")
                    .font(.system(size: 20, weight: .bold))
                
                Text("功能开发中...")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - 工具卡片组件
struct ToolCard: View {
    let icon: String
    let name: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    init(icon: String, name: String, color: Color, action: @escaping () -> Void) {
        self.icon = icon
        self.name = name
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundStyle(color.gradient)
                }
                
                Text(name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHovered ? Color.white.opacity(0.15) : Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isHovered ? color.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .pointingHandCursor()
    }
}

#Preview {
    CatMenuView(viewModel: CatViewModel())
}
