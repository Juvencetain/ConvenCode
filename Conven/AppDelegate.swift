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
            frameDurations.append(max(delay, 0.02)) // 避免过低导致过载
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
class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var catViewModel: CatViewModel!
    private var cancellables = Set<AnyCancellable>()
    private var gifAnimator: GifAnimator?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 请求通知权限
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ 已获得通知权限")
            } else {
                print("❌ 通知权限被拒绝: \(String(describing: error))")
            }}
        
        if let path = Bundle.main.path(forResource: "cat-animated", ofType: "gif") {
            print("✅ GIF 文件找到: \(path)")
        } else {
            print("❌ GIF 文件未找到")
        }
        
        _ = PersistenceController.shared
        catViewModel = CatViewModel()
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem.button else { return }
        button.action = #selector(togglePopover)
        
        gifAnimator = GifAnimator(statusButton: button)
        gifAnimator?.setVerticalOffset(4)  // 调节位置
        gifAnimator?.loadGif(named: "cat-animated")
        
        let catStatusView = CatStatusView(viewModel: catViewModel)
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 320)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: catStatusView)
        
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
    }
    
    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
