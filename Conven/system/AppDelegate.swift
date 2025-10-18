import SwiftUI
import Combine
import AppKit
import ImageIO
import UserNotifications

// MARK: - NSImage 扩展
extension NSImage {
    /// 上下偏移绘制（仅用于初始化阶段）
    func withVerticalOffset(_ offset: CGFloat) -> NSImage {
        guard offset != 0 else { return self }
        
        let origSize = self.size
        let extra = abs(offset)
        let newSize = NSSize(width: origSize.width, height: origSize.height + extra)
        let result = NSImage(size: newSize)
        
        result.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        
        let drawY: CGFloat = (offset > 0) ? offset : 0
        let drawRect = NSRect(x: 0, y: drawY, width: origSize.width, height: origSize.height)
        
        self.draw(in: drawRect,
                  from: NSRect(origin: .zero, size: origSize),
                  operation: .sourceOver,
                  fraction: 1.0)
        result.unlockFocus()
        
        result.isTemplate = self.isTemplate
        return result
    }
}

// MARK: - GIF 播放器
class GifAnimator {
    private weak var statusButton: NSStatusBarButton?
    private var frames: [NSImage] = []
    private var frameDurations: [TimeInterval] = []
    private var frameIndex = 0
    private var timer: Timer?
    private var verticalOffset: CGFloat = 0
    
    init(statusButton: NSStatusBarButton) {
        self.statusButton = statusButton
        statusButton.imagePosition = .imageOnly
        statusButton.imageScaling = .scaleProportionallyDown
    }
    
    func setVerticalOffset(_ offset: CGFloat) {
        verticalOffset = offset
    }
    
    func loadGif(named name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "gif"),
              let data = try? Data(contentsOf: url),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            print("❌ GIF 文件没找到: \(name).gif")
            return
        }
        
        let frameCount = CGImageSourceGetCount(source)
        frames.removeAll()
        frameDurations.removeAll()
        
        for i in 0..<frameCount {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                var nsImage = NSImage(cgImage: cgImage,
                                      size: NSSize(width: cgImage.width, height: cgImage.height))
                nsImage.isTemplate = true
                if verticalOffset != 0 {
                    nsImage = nsImage.withVerticalOffset(verticalOffset)
                }
                frames.append(nsImage)
            }
            
            let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any]
            let gifDict = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let delay = gifDict?[kCGImagePropertyGIFDelayTime] as? Double ?? 0.1
            frameDurations.append(max(delay, 0.02))
        }
    }
    
    func startAnimating() {
        stopAnimating()
        guard !frames.isEmpty else { return }
        frameIndex = 0
        statusButton?.image = frames[0]
        
        timer = Timer.scheduledTimer(withTimeInterval: frameDurations[0], repeats: false) { [weak self] _ in
            self?.nextFrame()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    func stopAnimating() {
        timer?.invalidate()
        timer = nil
    }
    
    private func nextFrame() {
        guard !frames.isEmpty else { return }
        frameIndex = (frameIndex + 1) % frames.count
        statusButton?.image = frames[frameIndex]
        
        timer = Timer.scheduledTimer(withTimeInterval: frameDurations[frameIndex], repeats: false) { [weak self] _ in
            self?.nextFrame()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    deinit {
        stopAnimating()
    }
}

// MARK: - AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var startupExecutorViewModel: StartupExecutorViewModel!
    private var statusItem: NSStatusItem!
    private var popover: NSPopover?
    private var catViewModel: CatViewModel!
    private var cancellables = Set<AnyCancellable>()
    private var gifAnimator: GifAnimator?
    private var clipboardMonitor: ClipboardMonitor?
    
    // 添加事件监听器
    private var eventMonitor: Any?
    
    func getCatViewModel() -> CatViewModel {
            return catViewModel
        }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 请求通知权限
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ 已获得通知权限")
            } else {
                print("❌ 通知权限被拒绝: \(String(describing: error))")
            }
        }
        
        // ⭐ 初始化AI日程服务（只初始化一次）
        _ = CatAIScheduleService.shared
        print("✅ AI日程服务已启动")
        
        // 检查 GIF 文件
        if let path = Bundle.main.path(forResource: "cat-animated", ofType: "gif") {
            print("✅ GIF 文件找到: \(path)")
        } else {
            print("❌ GIF 文件未找到")
        }
        
        // 初始化 Core Data
        _ = PersistenceController.shared
        
        // 初始化使用统计（会自动记录一次打开）
        UsageStatisticsService.shared.loadStatistics()
        print("✅ 使用统计系统已初始化")
        
        // 初始化 ViewModel
        catViewModel = CatViewModel()
        startupExecutorViewModel = StartupExecutorViewModel()
        // 创建状态栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem.button else { return }
        button.action = #selector(togglePopover)
        
        // 设置 GIF 动画
        gifAnimator = GifAnimator(statusButton: button)
        gifAnimator?.setVerticalOffset(4)
        gifAnimator?.loadGif(named: "cat-animated")
        
        // 监听小猫存活状态，控制动画
        catViewModel.$isAlive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAlive in
                guard let self = self else { return }
                if isAlive {
                    self.gifAnimator?.startAnimating()
                } else {
                    self.gifAnimator?.stopAnimating()
                    if let deadImage = NSImage(named: "cat-dead") {
                        deadImage.isTemplate = true
                        self.statusItem.button?.image = deadImage.withVerticalOffset(4)
                    }
                }
            }
            .store(in: &cancellables)
        
        clipboardMonitor = ClipboardMonitor(persistenceController: PersistenceController.shared)
        clipboardMonitor?.startMonitoring()
        print("✅ 剪贴板监控已启动")

        // [修改] 延迟1秒后异步执行启动命令
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await startupExecutorViewModel.executeEnabledCommandsOnStartup()
        }

        // 设置全局事件监听器 - 监听鼠标点击和键盘事件
        setupEventMonitor()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor?.stopMonitoring()
        print("⏹️ 剪贴板监控已停止")
        
        // 移除事件监听器
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }
    
    // MARK: - 设置事件监听器
    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return }
            
            // 如果 popover 正在显示
            if let popover = self.popover, popover.isShown {
                // 检查点击是否在 popover 之外
                if !self.isClickInsidePopover(event) {
                    self.closePopover()
                }
            }
        }
    }
    
    // MARK: - 检查点击是否在 popover 内部
    private func isClickInsidePopover(_ event: NSEvent) -> Bool {
        guard let popover = popover,
              let contentView = popover.contentViewController?.view,
              let window = contentView.window else {
            return false
        }
        
        // 将屏幕坐标转换为窗口坐标
        let locationInWindow = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        
        // 检查点击是否在内容视图范围内
        return contentView.frame.contains(locationInWindow)
    }
    
    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        
        if let popover = popover, popover.isShown {
            popover.performClose(nil)
            self.popover = nil
        } else {
            UsageStatisticsService.shared.recordAppOpen()
            // 创建新的视图实例
            let menuView = CatMenuView(viewModel: catViewModel)
            
            // 创建新的 popover
            let newPopover = NSPopover()
            newPopover.behavior = .transient
            newPopover.contentViewController = NSHostingController(rootView: menuView)
            
            // 设置代理以处理 popover 关闭事件
            newPopover.delegate = self
            
            newPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            
            self.popover = newPopover
        }
    }
    
    // MARK: - NSPopoverDelegate
    func popoverDidClose(_ notification: Notification) {
        popover = nil
    }
    
    @objc func closePopover() {
        if let popover = popover, popover.isShown {
            popover.performClose(nil)
            self.popover = nil
        }
    }
}
