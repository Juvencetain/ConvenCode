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
                    Button("剪贴板历史") {
                        openClipboardHistory()
                    }
                    
                    Button("IP 地址查询") {
                        print("查询当前 IP 地址")
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
    
    private func openClipboardHistory() {
        let historyView = ClipboardHistoryView()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        
        let hostingController = NSHostingController(rootView: historyView)
        let window = NSWindow(contentViewController: hostingController)
        
        // 设置窗口样式
        window.title = ""
        window.titlebarAppearsTransparent = true
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.setContentSize(NSSize(width: 420, height: 560))
        window.center()
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        
        NSApp.activate(ignoringOtherApps: true)
        
        print("📋 打开剪贴板历史窗口")
    }
}

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
