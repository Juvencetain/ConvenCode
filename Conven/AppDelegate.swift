import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var catViewModel: CatViewModel!
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        
        // 1. 初始化数据模型
        catViewModel = CatViewModel()
        
        // 2. 创建状态栏项目
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        // 确保按钮存在
        guard let button = statusItem.button else {
            print("Status bar item failed to create a button.")
            return
        }
        
        // 设置初始图标
        button.image = NSImage(named: "cat-alive")
        button.action = #selector(togglePopover)
        
        // 3. 创建 SwiftUI 视图并放入 Popover
        let catStatusView = CatStatusView(viewModel: catViewModel)
        
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 320) // 根据你的视图调整
        popover.behavior = .transient // 点击外部区域时自动关闭
        popover.contentViewController = NSHostingController(rootView: catStatusView)
        
        // 4. 监听小猫存活状态，以改变图标
        catViewModel.$isAlive
            .receive(on: DispatchQueue.main)
            .sink { isAlive in
                self.statusItem.button?.image = NSImage(named: isAlive ? "cat-alive" : "cat-dead")
            }
            .store(in: &cancellables)
    }
    
    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // 激活应用，让 popover 能接收键盘事件等
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}