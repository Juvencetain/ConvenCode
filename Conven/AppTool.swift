import SwiftUI

// MARK: - 工具定义
struct AppTool: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let icon: String
    let color: Color
    let type: ToolType
    
    enum ToolType: String, Codable {
        case clipboard, ipLookup, httpRequest, dataProcessor, json, calculator, translator
    }
    
    // Codable 支持 Color
    enum CodingKeys: String, CodingKey {
        case id, name, icon, colorHex, type
    }
    
    init(id: String, name: String, icon: String, color: Color, type: ToolType) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.type = type
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decode(String.self, forKey: .icon)
        let colorHex = try container.decode(String.self, forKey: .colorHex)
        color = Color(hex: colorHex) ?? .blue
        type = try container.decode(ToolType.self, forKey: .type)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(icon, forKey: .icon)
        try container.encode(color.toHex(), forKey: .colorHex)
        try container.encode(type, forKey: .type)
    }
}

// MARK: - 固定工具管理器
class PinnedToolsManager {
    static let shared = PinnedToolsManager()
    private let storageKey = "pinned_tools"
    private let maxPinnedTools = 6
    
    // 所有可用工具
    let allTools: [AppTool] = [
        AppTool(id: "clipboard", name: "剪贴板", icon: "doc.on.clipboard.fill", color: .blue, type: .clipboard),
        AppTool(id: "ip", name: "IP查询", icon: "network", color: .cyan, type: .ipLookup),
        AppTool(id: "http", name: "HTTP", icon: "arrow.left.arrow.right.circle", color: .indigo, type: .httpRequest),
        AppTool(id: "data", name: "数据处理", icon: "wrench.and.screwdriver.fill", color: .green, type: .dataProcessor),
        AppTool(id: "json", name: "JSON", icon: "curlybraces.square.fill", color: .orange, type: .json),
        AppTool(id: "calc", name: "计算器", icon: "function", color: .purple, type: .calculator),
        AppTool(id: "trans", name: "翻译", icon: "character.bubble", color: .pink, type: .translator)
    ]
    
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
                .opacity(0.95)
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
        availableTools = PinnedToolsManager.shared.allTools.filter { !pinnedIds.contains($0.id) }
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
        AppTool(id: "clipboard", name: "剪贴板", icon: "doc.on.clipboard.fill", color: .blue, type: .clipboard)
    ]))
}