import SwiftUI
import Translation

// MARK: - 工具分类
enum ToolCategory: String, CaseIterable, Codable {
    case development = "开发工具"
    case daily = "日常工具"
    case fun = "趣味工具"
}

// MARK: - 工具定义
struct AppTool: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let icon: String
    let color: Color
    let type: ToolType
    let description: String
    let category: ToolCategory
    
    enum ToolType: String, Codable {
        case clipboard, ipLookup, httpRequest, dataProcessor, json, calculator, translator,
             ocr, passwordManager, morse, imageTools,iconGenerator,chmod,jwtDebugger,cronParser,
             regexTester,uuidGenerator,portScanner,hosts,urlParser,pdfExtractor,colorPicker,antiSleep,
             networkSpeedTest,scratchpad,dateCalculator,systemMonitor,worldClock,ballSortGame,matchGame,
             textProcessor,pdfToImage,qrCode,fileHashCalculator,watermarkTool,startupExecutor
    }
    
    // Codable 支持 Color
    enum CodingKeys: String, CodingKey {
        case id, name, icon, colorHex, type, description, category
    }
    
    init(id: String, name: String, icon: String, color: Color, type: ToolType, description: String, category: ToolCategory) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.type = type
        self.description = description
        self.category = category
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decode(String.self, forKey: .icon)
        let colorHex = try container.decode(String.self, forKey: .colorHex)
        color = Color(hex: colorHex) ?? .blue
        type = try container.decode(ToolType.self, forKey: .type)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? "" // Handle optional description for backward compatibility
        category = try container.decodeIfPresent(ToolCategory.self, forKey: .category) ?? .daily // Default category
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(icon, forKey: .icon)
        try container.encode(color.toHex(), forKey: .colorHex)
        try container.encode(type, forKey: .type)
        try container.encode(description, forKey: .description)
        try container.encode(category, forKey: .category)
    }
}

// MARK: - 统一工具管理器
class ToolsManager {
    static let shared = ToolsManager()
    
    // 所有可用工具的统一定义（单一数据源）
    let allTools: [AppTool] = [
        // 日常工具
        AppTool(id: "clipboard", name: "剪贴板历史", icon: "doc.on.clipboard.fill", color: .blue, type: .clipboard, description: "查看和管理剪贴板历史记录", category: .daily),
        AppTool(id: "dateCalculator", name: "日期计算器", icon: "calendar.badge.clock", color: .cyan, type: .dateCalculator, description: "计算日期差异或增减天数", category: .daily),
        AppTool(id: "calc", name: "计算器", icon: "function", color: .purple, type: .calculator, description: "一个简单实用的计算器", category: .daily),
        AppTool(id: "qrCode", name: "二维码工具", icon: "qrcode.viewfinder", color: .orange, type: .qrCode, description: "生成或识别二维码内容", category: .daily),
        AppTool(id: "textProcessor", name: "文本处理", icon: "text.quote", color: .green, type: .textProcessor, description: "强大的文本分析、转换和对比工具集", category: .daily),
        AppTool(id: "fileHash", name: "文件哈希计算器", icon: "number.circle.fill", color: .green, type: .fileHashCalculator, description: "计算文件的 MD5, SHA-1, SHA-256 等哈希值", category: .development),
        AppTool(id: "watermark",name: "图片水印工具",icon: "wand.and.rays",color: .purple,type: .watermarkTool,description: "为图片批量添加文字或图片水印",category: .daily
        ),
        AppTool(id: "password", name: "密码本", icon: "lock.shield.fill", color: .blue, type: .passwordManager, description: "安全地存储您的账户和密码", category: .daily),
        AppTool(id: "pdfToImage", name: "PDF转图片", icon: "doc.richtext.fill", color: .red, type: .pdfToImage, description: "将 pdf 转换成为图片进行导出，支持批量", category: .daily),
        AppTool(id: "trans", name: "翻译", icon: "character.bubble", color: .pink, type: .translator, description: "多语言文本翻译", category: .daily),
        AppTool(id: "uuid", name: "UUID 生成器", icon: "number.circle.fill", color: .purple, type: .uuidGenerator, description: "快速生成通用唯一识别码", category: .daily),
        AppTool(id: "scratchpad", name: "临时便签", icon: "pencil.and.scribble", color: .yellow, type: .scratchpad,description: "用于临时记录想法或信息，关闭即毁",category: .daily),
        AppTool(id: "imageTools", name: "图片工具", icon: "photo.on.rectangle.angled", color: .purple, type: .imageTools, description: "处理图片的工具集", category: .daily),
        AppTool(id: "matchGame", name: "趣味消消乐", icon: "squares.below.rectangle", color: .blue, type: .matchGame, description: "经典的宝石消除游戏", category: .fun),
        AppTool(id: "antiSleep",name: "防休眠",icon: "bolt.shield.fill",color: .green,type: .antiSleep,description: "防止 Mac 进入休眠或黑屏",category: .daily),
        AppTool(id: "worldClock", name: "世界时间", icon: "globe.americas.fill", color: .indigo, type: .worldClock, description: "查看世界各地实时时间", category: .daily),
        AppTool(id: "speedTest",name: "网络测速",icon: "speedometer",color: .blue,type: .networkSpeedTest,description: "测试网络上传和下载速度",category: .daily
        ),
        AppTool(id: "systemMonitor", name: "系统信息", icon: "gauge.high", color: .blue, type: .systemMonitor, description: "监控CPU、内存和网络状态", category: .daily),
        // AppTool(id: "pdfExtractor", name: "PDF 数据解析", icon: "doc.text.magnifyingglass", color: .orange, type: .pdfExtractor, description: "从PDF提取文本并导出为CSV", category: .daily),
        // AppTool(id: "ocr", name: "截图识字", icon: "doc.text.viewfinder", color: .teal, type: .ocr),
        // 开发工具
        AppTool(id: "ip", name: "IP 地址查询", icon: "network", color: .cyan, type: .ipLookup, description: "查询公网或指定IP的地理信息", category: .development),
        AppTool(id: "http", name: "HTTP 请求", icon: "arrow.left.arrow.right.circle", color: .indigo, type: .httpRequest, description: "发送HTTP请求以调试API接口", category: .development),
        AppTool(id: "color", name: "颜色选择器", icon: "eyedropper.halffull", color: .purple, type: .colorPicker,description: "从屏幕任何位置拾取颜色，并在 HEX, RGB, HSL 等格式间相互转换。", category: .development),
        AppTool(id: "data", name: "数据处理", icon: "wrench.and.screwdriver.fill", color: .green, type: .dataProcessor, description: "Base64, URL, 时间戳, 哈希计算", category: .development),
        AppTool(id: "json", name: "JSON 工具", icon: "curlybraces.square.fill", color: .orange, type: .json, description: "格式化、压缩和转义JSON字符串", category: .development),
        AppTool(id: "chmod", name: "Chmod 计算器", icon: "slider.horizontal.3", color: .cyan, type: .chmod, description: "计算Linux/Unix文件权限代码", category: .development),
        AppTool(id: "hosts", name: "Hosts 编辑器", icon: "pencil.and.ruler.fill", color: .green, type: .hosts, description: "快速编辑本地Hosts文件", category: .development),
        AppTool(id: "urlParser", name: "URL 解析器", icon: "link.circle.fill", color: .purple, type: .urlParser, description: "将URL分解为协议、路径等部分", category: .development),
        AppTool(id: "portscan", name: "端口扫描", icon: "shippingbox.and.arrow.backward.fill", color: .indigo, type: .portScanner, description: "扫描指定主机的常见端口", category: .development),
        AppTool(id: "regex", name: "正则表达式", icon: "text.magnifyingglass", color: .orange, type: .regexTester, description: "在线测试和调试正则表达式", category: .development),
        AppTool(id: "iconGenerator", name: "App Icon生成器", icon: "app.dashed", color: .teal, type: .iconGenerator, description: "为Apple平台生成应用图标集", category: .development),
        AppTool(id: "startupExecutor", name: "启动执行", icon: "play.display", color: .blue, type: .startupExecutor, description: "应用启动时自动执行命令", category: .development),
        AppTool(id: "jwt", name: "JWT 解码器", icon: "key.viewfinder", color: .red, type: .jwtDebugger, description: "解码和验证JWT (JSON Web Token)", category: .development),
        AppTool(id: "cron", name: "Cron 解析器", icon: "timer.square", color: .cyan, type: .cronParser, description: "解析Cron表达式的执行时间", category: .development),
        
        // 趣味工具
        AppTool(id: "waveform.path.ecg", name: "摩斯电码", icon: "waveform.path.ecg", color: .green, type: .morse, description: "文本与摩斯电码互转和播放", category: .fun),
        AppTool(id: "ballSort", name: "彩球排序", icon: "gamecontroller.fill", color: .purple, type: .ballSortGame, description: "一个令人上瘾的颜色排序小游戏", category: .fun) // [!code ++]
    ]
    
    // 根据类型获取工具
    func getTool(by type: AppTool.ToolType) -> AppTool? {
        return allTools.first { $0.type == type }
    }
    
    func openToolWindow(_ type: AppTool.ToolType, viewModel: CatViewModel? = nil) {
            print("🚀 ToolsManager.openToolWindow 被调用 for \(type.rawValue)")
            
            let view: AnyView
            let size: NSSize
            
            switch type {
            case .clipboard:
                let clipboardView = ClipboardHistoryView()
                    .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                view = AnyView(clipboardView)
                size = NSSize(width: 420, height: 560)
            case .ipLookup:
                view = AnyView(IPLookupView())
                size = NSSize(width: 420, height: 560)
            case .httpRequest:
                view = AnyView(HTTPRequestView())
                size = NSSize(width: 900, height: 650)
            case .fileHashCalculator:
                view = AnyView(FileHashView())
                size = NSSize(width: 700, height: 600)
            case .watermarkTool:
                view = AnyView(WatermarkToolView())
                size = NSSize(width: 900, height: 650)
            case .pdfToImage:
                view = AnyView(PDFToImageView())
                size = NSSize(width: 800, height: 600)
            case .dataProcessor:
                view = AnyView(DataProcessorView())
                size = NSSize(width: 420, height: 560)
            case .qrCode:
                view = AnyView(QRCodeToolView())
                size = NSSize(width: 700, height: 500)
            case .matchGame:
                view = AnyView(MatchGameView())
                size = NSSize(width: 420, height: 600)
            case .json:
                view = AnyView(JSONFormatterView())
                size = NSSize(width: 420, height: 560)
            case .worldClock:
                view = AnyView(WorldClockView())
                size = NSSize(width: 480, height: 620)
            case .textProcessor:
                view = AnyView(TextProcessorView())
                size = NSSize(width: 800, height: 600)
            case .dateCalculator:
                view = AnyView(DateCalculatorView())
                size = NSSize(width: 420, height: 500)
            case .systemMonitor:
               view = AnyView(SystemMonitorView())
               size = NSSize(width: 420, height: 620)
            case .antiSleep:
                view = AnyView(AntiSleepView())
                size = NSSize(width: 420, height: 560)
            case .networkSpeedTest:
                view = AnyView(NetworkSpeedTestView())
                size = NSSize(width: 420, height: 680)
            case .scratchpad:
                view = AnyView(ScratchpadView())
                size = NSSize(width: 350, height: 400)
            case .startupExecutor:
                view = AnyView(StartupExecutorView())
                size = NSSize(width: 550, height: 450)
            case .calculator:
                view = AnyView(CalculatorView())
                size = NSSize(width: 420, height: 560)
            case .pdfExtractor:
                view = AnyView(PDFExtractorView())
                size = NSSize(width: 600, height: 650)
            case .translator:
                view = AnyView(GuideView()) // Placeholder
                size = NSSize(width: 420, height: 560)
            case .ocr:
                view = AnyView(ScreenshotToolView())
                size = NSSize(width: 420, height: 560)
            case .ballSortGame: // [!code ++]
                view = AnyView(BallSortView())
                size = NSSize(width: 480, height: 600)
            case .colorPicker:
                view = AnyView(ColorPickerView())
                size = NSSize(width: 420, height: 560)
            case .passwordManager:
                let passwordView = PasswordManagerView()
                    .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                view = AnyView(passwordView)
                size = NSSize(width: 700, height: 560) // Note: PasswordManagerView has a larger size
            case .morse:
                view = AnyView(MorseCodeToolView())
                size = NSSize(width: 420, height: 560)
            case .imageTools:
                view = AnyView(ImageToolsView()) // Placeholder
                size = NSSize(width: 420, height: 560)
            case .iconGenerator:
                view = AnyView(IconGeneratorView()) // Placeholder
                size = NSSize(width: 420, height: 760)
            case .chmod:
                view = AnyView(ChmodCalculatorView())
                size = NSSize(width: 420, height: 560)
            case .jwtDebugger:
                view = AnyView(JWTView()) // Placeholder
                size = NSSize(width: 800, height: 500)
            case .cronParser:
                view = AnyView(CronView()) // Placeholder
                size = NSSize(width: 450, height: 550)
            case .regexTester:
                view = AnyView(RegexView()) // Placeholder
                size = NSSize(width: 800, height: 600)
            case .uuidGenerator:
                view = AnyView(UUIDGeneratorView()) // Placeholder
                size = NSSize(width: 420, height: 560)
            case .portScanner:
                view = AnyView(PortScannerView()) // Placeholder
                size = NSSize(width: 420, height: 560)
            case .hosts:
                view = AnyView(HostsView()) // Placeholder
                size = NSSize(width: 500, height: 600)
            case .urlParser:
                view = AnyView(URLParserView())
                size = NSSize(width: 420, height: 560)
            }
            
            let hostingController = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: hostingController)
            
            window.title = ""
            window.titlebarAppearsTransparent = true
            window.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
            window.isOpaque = false
            window.backgroundColor = .clear
            window.setContentSize(size)
            window.center()
            window.level = .floating
            window.makeKeyAndOrderFront(nil)
            
            NSApp.activate(ignoringOtherApps: true)
            
            if let vm = viewModel {
                print("✅ viewModel 存在，触发奖励")
                DispatchQueue.main.async {
                    vm.rewardForToolUsage()
                }
            } else {
                print("⚠️ viewModel 为 nil，无法触发奖励")
            }
        }
}
// MARK: - 固定工具管理器
class PinnedToolsManager {
    static let shared = PinnedToolsManager()
    private let storageKey = "pinned_tools"
    private let maxPinnedTools = 6
    
    // 获取所有工具（从统一管理器）
    var allTools: [AppTool] {
        return ToolsManager.shared.allTools
    }
    
    func load() -> [AppTool] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let tools = try? JSONDecoder().decode([AppTool].self, from: data) else {
            // 默认固定前3个工具
            return Array(allTools.prefix(3))
        }
        return tools
    }
    
    func save(_ tools: [AppTool]) {
        if let encoded = try? JSONEncoder().encode(tools) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    func canPin(currentCount: Int) -> Bool {
        return currentCount < maxPinnedTools
    }
}

// MARK: - Color 扩展
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: // RGB
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func toHex() -> String {
        guard let components = NSColor(self).cgColor.components else { return "#000000" }
        
        let r = Int(components[0] * 255.0)
        let g = Int(components[1] * 255.0)
        let b = Int(components[2] * 255.0)
        
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - 固定工具栏视图
struct PinnedToolsBar: View {
    @Binding var pinnedTools: [AppTool]
    let onToolTap: (AppTool) -> Void
    let onManage: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("快捷工具")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: onManage) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("管理工具")
                .pointingHandCursor()
            }
            
            if pinnedTools.isEmpty {
                Button(action: onManage) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("添加工具")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 10) {
                    ForEach(pinnedTools) { tool in
                        PinnedToolButton(tool: tool) {
                            onToolTap(tool)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - 固定工具按钮
struct PinnedToolButton: View {
    let tool: AppTool
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
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(tool.color.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: tool.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(tool.color.gradient)
                }
                .scaleEffect(isPressed ? 0.85 : 1.0)
                
                Text(tool.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
    }
}

// MARK: - 工具管理视图
struct ManageToolsView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var pinnedTools: [AppTool]
    
    @State private var availableTools: [AppTool] = []
    
    let maxTools = 6
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(1)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 标题栏
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue.gradient)
                    
                    Text("管理工具")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Spacer()
                    
                    Text("\(pinnedTools.count)/\(maxTools)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.secondary.opacity(0.15)))
                    
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
                        // 已固定
                        if !pinnedTools.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("已固定 (\(pinnedTools.count))")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 12) {
                                    ForEach(pinnedTools) { tool in
                                        ToolManageCard(
                                            tool: tool,
                                            isPinned: true,
                                            onToggle: {
                                                unpinTool(tool)
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        
                        // 可用工具
                        if !availableTools.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("可用工具")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 12) {
                                    ForEach(availableTools) { tool in
                                        ToolManageCard(
                                            tool: tool,
                                            isPinned: false,
                                            isDisabled: pinnedTools.count >= maxTools,
                                            onToggle: {
                                                pinTool(tool)
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 420, height: 560)
        .focusable(false)
        .onAppear {
            updateAvailableTools()
        }
    }
    
    private func pinTool(_ tool: AppTool) {
        guard pinnedTools.count < maxTools else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            pinnedTools.append(tool)
            PinnedToolsManager.shared.save(pinnedTools)
            updateAvailableTools()
        }
    }
    
    private func unpinTool(_ tool: AppTool) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            pinnedTools.removeAll { $0.id == tool.id }
            PinnedToolsManager.shared.save(pinnedTools)
            updateAvailableTools()
        }
    }
    
    private func updateAvailableTools() {
        let pinnedIds = Set(pinnedTools.map { $0.id })
        availableTools = ToolsManager.shared.allTools.filter { !pinnedIds.contains($0.id) }
    }
}

// MARK: - 工具管理卡片
struct ToolManageCard: View {
    let tool: AppTool
    let isPinned: Bool
    var isDisabled: Bool = false
    let onToggle: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(tool.color.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: tool.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(tool.color.gradient)
                    
                    if isPinned {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 18, height: 18)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .offset(x: 18, y: -18)
                    }
                }
                
                Text(tool.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHovered ? Color.white.opacity(0.12) : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isPinned ? tool.color.opacity(0.5) :
                        (isHovered ? Color.blue.opacity(0.3) : Color.clear),
                        lineWidth: isPinned ? 2 : 1
                    )
            )
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled && !isPinned)
        .onHover { hovering in
            isHovered = hovering
        }
        .pointingHandCursor()
    }
}

#Preview {
    ManageToolsView(pinnedTools: .constant([
        AppTool(id: "clipboard", name: "剪贴板历史", icon: "doc.on.clipboard.fill", color: .blue, type: .clipboard, description: "记录你的剪贴板历史", category: .daily)
    ]))
}
