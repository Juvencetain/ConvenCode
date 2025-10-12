import SwiftUI
import Vision
import AppKit
import ScreenCaptureKit
import Combine

// MARK: - OCR 结果模型
struct OCRResult: Identifiable {
    let id = UUID()
    let text: String
    let confidence: Float
    let timestamp: Date
    
    var confidencePercentage: Int {
        Int(confidence * 100)
    }
}

// MARK: - 截图模式
enum CaptureMode {
    case selection      // 区域截图
    case fullScreen     // 全屏截图
    case window         // 窗口截图
    case clipboard      // 从剪贴板
    case file           // 从文件
}

// MARK: - OCR 服务
class OCRService {
    static let shared = OCRService()
    
    func recognizeText(from image: NSImage) async throws -> [OCRResult] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OCRError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let results = observations.compactMap { observation -> OCRResult? in
                    guard let topCandidate = observation.topCandidates(1).first else {
                        return nil
                    }
                    return OCRResult(
                        text: topCandidate.string,
                        confidence: topCandidate.confidence,
                        timestamp: Date()
                    )
                }
                
                continuation.resume(returning: results)
            }
            
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    enum OCRError: LocalizedError {
        case invalidImage
        case noTextFound
        
        var errorDescription: String? {
            switch self {
            case .invalidImage:
                return "无效的图片格式"
            case .noTextFound:
                return "未识别到文字"
            }
        }
    }
}

// MARK: - 增强截图服务
class EnhancedScreenshotService {
    static let shared = EnhancedScreenshotService()
    
    // 区域截图（交互式选择）
    func captureSelection() async -> NSImage? {
        return await captureWithMode("-i")
    }
    
    // 全屏截图
    func captureFullScreen() async -> NSImage? {
        return await captureWithMode("")
    }
    
    // 窗口截图
    func captureWindow() async -> NSImage? {
        return await captureWithMode("-w")
    }
    
    // 延时截图
    func captureWithDelay(seconds: Int, mode: String = "-i") async -> NSImage? {
        try? await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
        return await captureWithMode(mode)
    }
    
    private func captureWithMode(_ mode: String) async -> NSImage? {
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        
        var args = ["-c"]  // 复制到剪贴板
        if !mode.isEmpty {
            args.insert(mode, at: 0)
        }
        task.arguments = args
        
        try? task.run()
        task.waitUntilExit()
        
        // 短暂延迟确保剪贴板更新
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        if let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            return image
        }
        
        return nil
    }
    
    // 从剪贴板读取
    func getImageFromClipboard() -> NSImage? {
        return NSPasteboard.general.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage
    }
    
    // 从文件选择
    func selectImageFile() -> NSImage? {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.image, .png, .jpeg]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            return NSImage(contentsOf: url)
        }
        
        return nil
    }
    
    // 保存图片到文件
    func saveImage(_ image: NSImage) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = "Screenshot-\(Date().timeIntervalSince1970).png"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            if let tiffData = image.tiffRepresentation,
               let bitmapImage = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                try? pngData.write(to: url)
            }
        }
    }
}

// MARK: - ViewModel
@MainActor
class OCRViewModel: ObservableObject {
    @Published var recognizedText = ""
    @Published var ocrResults: [OCRResult] = []
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var currentImage: NSImage?
    @Published var showSuccessToast = false
    @Published var toastMessage = ""
    @Published var averageConfidence: Float = 0
    @Published var selectedTab = 0  // 0: 截图, 1: OCR结果
    @Published var delaySeconds = 3
    
    private let ocrService = OCRService.shared
    private let screenshotService = EnhancedScreenshotService.shared
    private var hiddenWindows: [NSWindow] = []
    
    // 截图并识别
    func captureAndRecognize(mode: CaptureMode) async {
        isProcessing = true
        errorMessage = nil
        
        // 需要隐藏窗口的模式
        if mode == .selection || mode == .fullScreen || mode == .window {
            hideAllWindows()
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        
        var image: NSImage?
        
        switch mode {
        case .selection:
            image = await screenshotService.captureSelection()
        case .fullScreen:
            image = await screenshotService.captureFullScreen()
        case .window:
            image = await screenshotService.captureWindow()
        case .clipboard:
            image = screenshotService.getImageFromClipboard()
        case .file:
            image = screenshotService.selectImageFile()
        }
        
        // 显示窗口
        if mode == .selection || mode == .fullScreen || mode == .window {
            showAllWindows()
        }
        
        if let image = image {
            currentImage = image
            await performOCR(on: image)
            selectedTab = 1  // 自动切换到结果标签
        } else {
            errorMessage = mode == .clipboard ? "剪贴板中没有图片" : "截图失败或已取消"
            isProcessing = false
        }
    }
    
    // 延时截图
    func delayedCapture(mode: CaptureMode) async {
        isProcessing = true
        errorMessage = nil
        toastMessage = "将在 \(delaySeconds) 秒后截图"
        showSuccessToast = true
        
        hideAllWindows()
        
        let modeString: String
        switch mode {
        case .selection: modeString = "-i"
        case .fullScreen: modeString = ""
        case .window: modeString = "-w"
        default: modeString = "-i"
        }
        
        if let image = await screenshotService.captureWithDelay(seconds: delaySeconds, mode: modeString) {
            showAllWindows()
            currentImage = image
            await performOCR(on: image)
            selectedTab = 1
        } else {
            showAllWindows()
            errorMessage = "延时截图失败"
            isProcessing = false
        }
    }
    
    private func hideAllWindows() {
        hiddenWindows.removeAll()
        for window in NSApp.windows {
            if window.isVisible && window.level.rawValue < NSWindow.Level.screenSaver.rawValue {
                hiddenWindows.append(window)
                window.orderOut(nil)
            }
        }
    }
    
    private func showAllWindows() {
        for window in hiddenWindows {
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        hiddenWindows.removeAll()
    }
    
    private func performOCR(on image: NSImage) async {
        isProcessing = true
        errorMessage = nil
        
        do {
            let results = try await ocrService.recognizeText(from: image)
            
            if results.isEmpty {
                errorMessage = "未识别到文字"
            } else {
                ocrResults = results
                recognizedText = results.map { $0.text }.joined(separator: "\n")
                
                let totalConfidence = results.reduce(0) { $0 + $1.confidence }
                averageConfidence = totalConfidence / Float(results.count)
                
                toastMessage = "识别成功，共 \(results.count) 行文字"
                showSuccessToast = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isProcessing = false
    }
    
    func copyToClipboard() {
        guard !recognizedText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(recognizedText, forType: .string)
        toastMessage = "已复制文字"
        showSuccessToast = true
    }
    
    func saveImage() {
        guard let image = currentImage else { return }
        screenshotService.saveImage(image)
    }
    
    func copyImage() {
        guard let image = currentImage else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        toastMessage = "已复制图片"
        showSuccessToast = true
    }
    
    func clear() {
        recognizedText = ""
        ocrResults = []
        currentImage = nil
        errorMessage = nil
        averageConfidence = 0
        selectedTab = 0
    }
}

// MARK: - Main View
struct OCRScreenshotView: View {
    @StateObject private var viewModel = OCRViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var showDelayPicker = false
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerBar
                Divider()
                
                // 标签切换
                tabBar
                Divider()
                
                // 内容区域
                TabView(selection: $viewModel.selectedTab) {
                    captureView
                        .tag(0)
                    
                    resultView
                        .tag(1)
                }
                .tabViewStyle(.automatic)
            }
        }
        .frame(width: 480, height: 620)
        .focusable(false)
        .overlay(alignment: .top) {
            if viewModel.showSuccessToast {
                toastView
            }
        }
        .sheet(isPresented: $showDelayPicker) {
            DelayPickerView(seconds: $viewModel.delaySeconds)
        }
    }
    
    // MARK: - Header
    private var headerBar: some View {
        HStack {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 16))
                .foregroundStyle(.blue.gradient)
            
            Text("智能截图")
                .font(.system(size: 16, weight: .semibold))
            
            Spacer()
            
            if viewModel.currentImage != nil {
                Button(action: viewModel.clear) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .help("清空")
                .pointingHandCursor()
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
    }
    
    // MARK: - Tab Bar
    private var tabBar: some View {
        HStack(spacing: 0) {
            TabButton(title: "截图工具", icon: "camera.fill", isSelected: viewModel.selectedTab == 0) {
                withAnimation {
                    viewModel.selectedTab = 0
                }
            }
            
            TabButton(title: "识别结果", icon: "doc.text.fill", isSelected: viewModel.selectedTab == 1) {
                withAnimation {
                    viewModel.selectedTab = 1
                }
            }
        }
        .frame(height: 44)
        .background(Color.black.opacity(0.05))
    }
    
    // MARK: - Capture View
    private var captureView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // 快速截图
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(icon: "bolt.fill", title: "快速截图", color: .blue)
                    
                    VStack(spacing: 10) {
                        CaptureButton(
                            icon: "crop",
                            title: "区域截图",
                            subtitle: "选择屏幕区域截图",
                            color: .blue,
                            isProcessing: viewModel.isProcessing
                        ) {
                            Task {
                                await viewModel.captureAndRecognize(mode: .selection)
                            }
                        }
                        
                        HStack(spacing: 10) {
                            CaptureButton(
                                icon: "rectangle.fill",
                                title: "全屏",
                                subtitle: "整个屏幕",
                                color: .purple,
                                isCompact: true,
                                isProcessing: viewModel.isProcessing
                            ) {
                                Task {
                                    await viewModel.captureAndRecognize(mode: .fullScreen)
                                }
                            }
                            
                            CaptureButton(
                                icon: "macwindow",
                                title: "窗口",
                                subtitle: "单个窗口",
                                color: .indigo,
                                isCompact: true,
                                isProcessing: viewModel.isProcessing
                            ) {
                                Task {
                                    await viewModel.captureAndRecognize(mode: .window)
                                }
                            }
                        }
                    }
                }
                
                // 延时截图
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(icon: "timer", title: "延时截图", color: .orange)
                    
                    HStack(spacing: 12) {
                        Button(action: { showDelayPicker = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "timer")
                                    .font(.system(size: 14))
                                Text("\(viewModel.delaySeconds) 秒")
                                    .font(.system(size: 13, weight: .medium))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .pointingHandCursor()
                        
                        Button(action: {
                            Task {
                                await viewModel.delayedCapture(mode: .selection)
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 12))
                                Text("开始")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.orange.gradient)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isProcessing)
                        .pointingHandCursor()
                    }
                }
                
                // 导入图片
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(icon: "square.and.arrow.down", title: "导入图片", color: .green)
                    
                    HStack(spacing: 10) {
                        CaptureButton(
                            icon: "doc.on.clipboard",
                            title: "剪贴板",
                            subtitle: "粘贴图片",
                            color: .cyan,
                            isCompact: true,
                            isProcessing: viewModel.isProcessing
                        ) {
                            Task {
                                await viewModel.captureAndRecognize(mode: .clipboard)
                            }
                        }
                        
                        CaptureButton(
                            icon: "folder",
                            title: "文件",
                            subtitle: "选择文件",
                            color: .green,
                            isCompact: true,
                            isProcessing: viewModel.isProcessing
                        ) {
                            Task {
                                await viewModel.captureAndRecognize(mode: .file)
                            }
                        }
                    }
                }
                
                // 图片预览
                if let image = viewModel.currentImage {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(icon: "photo", title: "图片预览", color: .pink)
                        
                        ZStack(alignment: .topTrailing) {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 180)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                            
                            // 图片操作按钮
                            HStack(spacing: 8) {
                                SmallIconButton(icon: "doc.on.doc", color: .blue) {
                                    viewModel.copyImage()
                                }
                                
                                SmallIconButton(icon: "square.and.arrow.down", color: .green) {
                                    viewModel.saveImage()
                                }
                            }
                            .padding(8)
                        }
                    }
                }
                
                Spacer(minLength: 20)
            }
            .padding(20)
        }
    }
    
    // MARK: - Result View
    private var resultView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                if viewModel.isProcessing {
                    loadingView
                } else if let error = viewModel.errorMessage {
                    errorView(error)
                } else if !viewModel.recognizedText.isEmpty {
                    resultContent
                } else {
                    emptyResultView
                }
            }
            .padding(20)
        }
    }
    
    private var resultContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 统计信息
            HStack(spacing: 12) {
                StatCard(icon: "doc.text", label: "文字行数", value: "\(viewModel.ocrResults.count)", color: .blue)
                StatCard(icon: "checkmark.circle", label: "识别准确度", value: "\(Int(viewModel.averageConfidence * 100))%", color: confidenceColor)
            }
            
            // 识别文字
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("识别文字")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: viewModel.copyToClipboard) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                            Text("复制")
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                }
                
                ScrollView {
                    Text(viewModel.recognizedText)
                        .font(.system(size: 13))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                }
                .frame(height: 250)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
            }
            
            // 详细结果
            if viewModel.ocrResults.count > 1 {
                DisclosureGroup {
                    VStack(spacing: 8) {
                        ForEach(viewModel.ocrResults) { result in
                            HStack(spacing: 10) {
                                Text(result.text)
                                    .font(.system(size: 12))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Text("\(result.confidencePercentage)%")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color.secondary.opacity(0.15)))
                            }
                            .padding(.vertical, 6)
                            
                            if result.id != viewModel.ocrResults.last?.id {
                                Divider()
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 11))
                        Text("查看详细信息 (\(viewModel.ocrResults.count) 行)")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.blue)
                }
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
            }
        }
    }
    
    private var confidenceColor: Color {
        let confidence = viewModel.averageConfidence
        if confidence > 0.9 { return .green }
        if confidence > 0.7 { return .orange }
        return .red
    }
    
    private var emptyResultView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 56))
                .foregroundStyle(.gray.gradient)
            
            Text("还没有识别结果")
                .font(.system(size: 15, weight: .medium))
            
            Text("使用左侧的截图工具开始识别")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Button(action: {
                withAnimation {
                    viewModel.selectedTab = 0
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left")
                    Text("返回截图")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("正在识别...")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange.gradient)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var toastView: some View {
        Text("✓ \(viewModel.toastMessage)")
            .font(.system(size: 12))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.green.opacity(0.9))
            .foregroundColor(.white)
            .cornerRadius(18)
            .padding(.top, 70)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                withAnimation(.easeInOut(duration: 0.3).delay(2)) {
                    viewModel.showSuccessToast = false
                }
            }
    }
}

// MARK: - Tab Button
struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isSelected ? .blue : .secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
            .overlay(
                Rectangle()
                    .fill(isSelected ? Color.blue : Color.clear)
                    .frame(height: 2),
                alignment: .bottom
            )
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Capture Button
struct CaptureButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    var isCompact: Bool = false
    var isProcessing: Bool = false
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    isPressed = false
                }
            }
        }) {
            HStack(spacing: isCompact ? 8 : 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: isCompact ? 40 : 48, height: isCompact ? 40 : 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: isCompact ? 18 : 20))
                        .foregroundStyle(color.gradient)
                }
                
                if !isCompact {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(subtitle)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(isCompact ? 12 : 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isProcessing)
        .pointingHandCursor()
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color.gradient)
                .frame(width: 32, height: 32)
                .background(Circle().fill(color.opacity(0.15)))
            
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                    .monospacedDigit()
            }
            
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Small Icon Button
struct SmallIconButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(color.opacity(isHovered ? 0.9 : 0.7))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .pointingHandCursor()
    }
}

// MARK: - Delay Picker View
struct DelayPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var seconds: Int
    
    let delayOptions = [3, 5, 10, 15, 30]
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 标题
                HStack {
                    Text("选择延时时长")
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
                
                // 选项
                VStack(spacing: 0) {
                    ForEach(delayOptions, id: \.self) { option in
                        Button(action: {
                            seconds = option
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "timer")
                                    .font(.system(size: 14))
                                    .foregroundColor(.orange)
                                
                                Text("\(option) 秒")
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if seconds == option {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(seconds == option ? Color.blue.opacity(0.1) : Color.clear)
                        }
                        .buttonStyle(.plain)
                        .pointingHandCursor()
                        
                        if option != delayOptions.last {
                            Divider()
                                .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .frame(width: 260, height: 280)
        .focusable(false)
    }
}
#Preview {
    OCRScreenshotView()
}
