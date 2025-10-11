import SwiftUI
import AppKit

struct CatStatusView: View {
    @ObservedObject var viewModel: CatViewModel
    
    var body: some View {
        VStack(spacing: 15) {
            if viewModel.isAlive {
                Text("小猫状态")
                    .font(.headline)
                Text("存活：" + String(viewModel.getLiveDays()) + " 天")
                
                VStack(alignment: .leading, spacing: 10) {
                    StatusRow(icon: "heart.fill", label: "心情", value: viewModel.mood, color: .pink)
                    StatusRow(icon: "leaf.fill", label: "饥饿", value: viewModel.hunger, color: .green)
                    StatusRow(icon: "drop.fill", label: "清洁", value: viewModel.cleanliness, color: .blue)
                }
                
                HStack(spacing: 10) {
                    Button("陪它玩", systemImage: "gamecontroller.fill", action: viewModel.play)
                    Button("喂食物", systemImage: "fork.knife", action: viewModel.feed)
                    Button("洗澡澡", systemImage: "bathtub.fill", action: viewModel.clean)
                }
                .buttonStyle(.borderedProminent)
                
                Menu("请教猫猫") {
                    // ⭐ 新增功能入口
                    Button("数据处理工具") {
                        openDataProcessor()
                    }
                    
                    Button("剪贴板历史") {
                        openClipboardHistory()
                    }
                    
                    Button("IP 地址查询") {
                        openIPLookup()
                    }
                    
                    Button("JSON格式化") {
                        showJSONFormatter()
                    }
                    
                    Divider()
                    
                    Button("更多功能...") {
                        print("未来扩展功能")
                    }
                }
                .menuStyle(.borderedButton)

            } else {
                VStack(spacing: 20) {
                    Image(systemName: "heart.slash.fill")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("小猫去天堂了...")
                        .font(.title2)
                    Button("重新开始", action: viewModel.restart)
                        .buttonStyle(.borderedProminent)
                }
            }
            
            Divider()
            
            Button("退出应用") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            
        }
        .padding(20)
        .frame(width: 300)
    }
    
    // MARK: - 提高效率和整洁度: 提取通用窗口创建逻辑
    
    /// 创建并显示一个具有统一 macOS 样式（透明、无边框）的辅助工具窗口。
    private func openUtilityWindow<Content: View>(view: Content, title: String = "工具", size: NSSize = NSSize(width: 420, height: 560)) {
        let hostingController = NSHostingController(rootView: view)
        
        let window = NSWindow(contentViewController: hostingController)
        
        // 统一美化 UI: 确保所有辅助窗口的样式完全一致
        window.title = title
        window.titlebarAppearsTransparent = true
        window.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        window.isOpaque = false
        window.backgroundColor = .clear // 必须设置为 clear 才能透出 VisualEffectBlur 的效果
        window.setContentSize(size)
        window.center()
        window.level = .floating // 使窗口保持在其他应用之上
        window.makeKeyAndOrderFront(nil)
        
        NSApp.activate(ignoringOtherApps: true)
        print("✅ 打开 \(title) 窗口")
    }

    // MARK: - 功能调用 (使用新的通用方法)
    
    private func openClipboardHistory() {
        let historyView = ClipboardHistoryView()
             .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        
        openUtilityWindow(view: historyView, title: "剪贴板历史")
    }
    
    private func openIPLookup() {
        openUtilityWindow(view: IPLookupView(), title: "IP 地址查询")
    }
    
    func showJSONFormatter() {
        openUtilityWindow(view: JSONFormatterView(), title: "JSON 格式化器")
    }
    
    // 新增功能入口
    func openDataProcessor() {
        openUtilityWindow(view: DataProcessorView(), title: "数据处理工具")
    }
}

// StatusRow 结构体保持不变
struct StatusRow: View {
    let icon: String
    let label: String
    let value: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text("\(label): \(Int(value))")
            }
            ProgressView(value: value, total: 100)
                .progressViewStyle(LinearProgressViewStyle(tint: color))
        }
    }
}
