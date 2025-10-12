import SwiftUI
import Vision
import AppKit
import ScreenCaptureKit
import Combine

// MARK: - 截图模式
enum CaptureMode: String, CaseIterable, Identifiable {
    case area = "区域截图"
    case fullscreen = "全屏截图"
    case window = "窗口截图"
    case timed = "延时截图"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .area: return "crop"
        case .fullscreen: return "rectangle.fill"
        case .window: return "macwindow"
        case .timed: return "timer"
        }
    }
    
    var color: Color {
        switch self {
        case .area: return .blue
        case .fullscreen: return .purple
        case .window: return .indigo
        case .timed: return .orange
        }
    }
}

// MARK: - 编辑工具
enum EditTool: String, CaseIterable {
    case arrow = "箭头"
    case rectangle = "矩形"
    case circle = "圆形"
    case text = "文字"
    case mosaic = "马赛克"
    case eraser = "橡皮擦"
    case marker = "标记"
    
    var icon: String {
        switch self {
        case .arrow: return "arrow.up.right"
        case .rectangle: return "rectangle"
        case .circle: return "circle"
        case .text: return "textformat"
        case .mosaic: return "squareshape.split.3x3"
        case .eraser: return "eraser.fill"
        case .marker: return "pencil.tip"
        }
    }
}

// MARK: - OCR 结果
struct OCRResult: Identifiable {
    let id = UUID()
    let text: String
    let confidence: Float
}

// MARK: - 截图服务
class ScreenshotService {
    static let shared = ScreenshotService()
    
    func capture(mode: CaptureMode, delay: Int = 0) async -> NSImage? {
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
        }
        
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        
        var args = ["-c"]  // 复制到剪贴板
        switch mode {
        case .area, .timed:
            args.insert("-i", at: 0)  // 交互式
        case .fullscreen:
            break  // 无参数表示全屏
        case .window:
            args.insert("-w", at: 0)  // 窗口模式
        }
        
        task.arguments = args
        try? task.run()
        task.waitUntilExit()
        
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        return NSPasteboard.general.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage
    }
    
    func saveImage(_ image: NSImage, to url: URL) {
        if let tiffData = image.tiffRepresentation,
           let bitmapImage = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapImage.representation(using: .png, properties: [:]) {
            try? pngData.write(to: url)
        }
    }
}

// MARK: - OCR 服务
class OCRService {
    static let shared = OCRService()
    
    func recognizeText(from image: NSImage) async throws -> [OCRResult] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "OCR", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的图片"])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let results = observations.compactMap { observation -> OCRResult? in
                    guard let topCandidate = observation.topCandidates(1).first else { return nil }
                    return OCRResult(text: topCandidate.string, confidence: topCandidate.confidence)
                }
                
                continuation.resume(returning: results)
            }
            
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
}

// MARK: - ViewModel
@MainActor
class ScreenshotViewModel: ObservableObject {
    @Published var capturedImage: NSImage?
    @Published var isCapturing = false
    @Published var showEditor = false
    @Published var ocrResults: [OCRResult] = []
    @Published var recognizedText = ""
    @Published var showToast = false
    @Published var toastMessage = ""
    @Published var delaySeconds = 3
    @Published var showDelayPicker = false
    
    private var hiddenWindows: [NSWindow] = []
    
    func startCapture(mode: CaptureMode) async {
        isCapturing = true
        hideAllWindows()
        
        let delay = mode == .timed ? delaySeconds : 0
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        if let image = await ScreenshotService.shared.capture(mode: mode, delay: delay) {
            capturedImage = image
            showEditor = true
        }
        
        showAllWindows()
        isCapturing = false
    }
    
    func performOCR() async {
        guard let image = capturedImage else { return }
        
        do {
            ocrResults = try await OCRService.shared.recognizeText(from: image)
            recognizedText = ocrResults.map { $0.text }.joined(separator: "\n")
            
            if !recognizedText.isEmpty {
                toastMessage = "识别成功，共 \(ocrResults.count) 行"
                showToast = true
            }
        } catch {
            toastMessage = "识别失败"
            showToast = true
        }
    }
    
    func copyImage() {
        guard let image = capturedImage else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        toastMessage = "已复制图片"
        showToast = true
    }
    
    func copyText() {
        guard !recognizedText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(recognizedText, forType: .string)
        toastMessage = "已复制文字"
        showToast = true
    }
    
    func saveImage() {
        guard let image = capturedImage else { return }
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = "Screenshot-\(Date().timeIntervalSince1970).png"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            ScreenshotService.shared.saveImage(image, to: url)
            toastMessage = "已保存图片"
            showToast = true
        }
    }
    
    func reset() {
        capturedImage = nil
        showEditor = false
        ocrResults = []
        recognizedText = ""
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
}

// MARK: - 主视图
struct ScreenshotToolView: View {
    @StateObject private var viewModel = ScreenshotViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            if viewModel.showEditor, let image = viewModel.capturedImage {
                EditorView(viewModel: viewModel, image: image)
            } else {
                MainCaptureView(viewModel: viewModel, dismiss: dismiss)
            }
            
            if viewModel.showToast {
                ToastView(message: viewModel.toastMessage)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                viewModel.showToast = false
                            }
                        }
                    }
            }
        }
        .frame(width: 420, height: 560)
        .focusable(false)
    }
}

// MARK: - 主截图界面
struct MainCaptureView: View {
    @ObservedObject var viewModel: ScreenshotViewModel
    let dismiss: DismissAction
    
    var body: some View {
        ZStack {
            VisualEffectBlurOCR(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(1)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 标题栏
                HStack {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue.gradient)
                    
                    Text("智能截图")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursorOCR()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Divider()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // 快速截图
                        VStack(alignment: .leading, spacing: 12) {
                            SectionTitle(icon: "bolt.fill", title: "快速截图", color: .blue)
                            
                            CaptureModeButton(
                                mode: .area,
                                isProcessing: viewModel.isCapturing
                            ) {
                                Task {
                                    await viewModel.startCapture(mode: .area)
                                }
                            }
                            
                            HStack(spacing: 12) {
                                CaptureModeButton(
                                    mode: .fullscreen,
                                    isCompact: true,
                                    isProcessing: viewModel.isCapturing
                                ) {
                                    Task {
                                        await viewModel.startCapture(mode: .fullscreen)
                                    }
                                }
                                
                                CaptureModeButton(
                                    mode: .window,
                                    isCompact: true,
                                    isProcessing: viewModel.isCapturing
                                ) {
                                    Task {
                                        await viewModel.startCapture(mode: .window)
                                    }
                                }
                            }
                        }
                        
                        // 延时截图
                        VStack(alignment: .leading, spacing: 12) {
                            SectionTitle(icon: "timer", title: "延时截图", color: .orange)
                            
                            HStack(spacing: 12) {
                                Button(action: {
                                    viewModel.showDelayPicker = true
                                }) {
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
                                    .padding(.vertical, 12)
                                    .background(Color.orange.opacity(0.15))
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                                .pointingHandCursor()
                                
                                Button(action: {
                                    Task {
                                        await viewModel.startCapture(mode: .timed)
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
                                    .padding(.vertical, 12)
                                    .background(Color.orange.gradient)
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                                .disabled(viewModel.isCapturing)
                                .pointingHandCursor()
                            }
                        }
                        
                        // 使用说明
                        VStack(spacing: 16) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.blue.gradient)
                            
                            VStack(spacing: 8) {
                                Text("截图后可以：")
                                    .font(.system(size: 13, weight: .semibold))
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    FeatureRow(icon: "wand.and.stars", text: "智能文字识别 (OCR)")
                                    FeatureRow(icon: "pencil.tip.crop.circle", text: "添加标注和马赛克")
                                    FeatureRow(icon: "doc.on.doc", text: "复制图片或文字")
                                    FeatureRow(icon: "square.and.arrow.down", text: "保存到文件")
                                }
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                    }
                    .padding(20)
                }
            }
        }
        .sheet(isPresented: $viewModel.showDelayPicker) {
            DelayPickerSheet(seconds: $viewModel.delaySeconds)
        }
    }
}

// MARK: - 编辑器视图
struct EditorView: View {
    @ObservedObject var viewModel: ScreenshotViewModel
    let image: NSImage
    @State private var selectedTool: EditTool?
    @State private var showOCRResult = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(1)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部工具栏
                HStack(spacing: 16) {
                    Button(action: viewModel.reset) {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12))
                            Text("取消")
                                .font(.system(size: 13))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                    
                    Spacer()
                    
                    Text("编辑截图")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.saveImage()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12))
                            Text("完成")
                                .font(.system(size: 13))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.gradient)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                // 图片预览区域
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 400)
                }
                .frame(maxHeight: .infinity)
                
                // 底部工具栏
                VStack(spacing: 12) {
                    // 编辑工具
                    HStack(spacing: 8) {
                        ForEach([EditTool.arrow, .rectangle, .text, .mosaic], id: \.self) { tool in
                            ToolButton(
                                icon: tool.icon,
                                label: tool.rawValue,
                                isSelected: selectedTool == tool
                            ) {
                                selectedTool = tool
                            }
                        }
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.2))
                    
                    // 操作按钮
                    HStack(spacing: 8) {
                        ActionButtonOCR(icon: "text.viewfinder", label: "OCR", color: .blue) {
                            Task {
                                await viewModel.performOCR()
                                showOCRResult = true
                            }
                        }
                        
                        ActionButtonOCR(icon: "doc.on.doc", label: "复制", color: .green) {
                            viewModel.copyImage()
                        }
                        
                        ActionButtonOCR(icon: "square.and.arrow.down", label: "保存", color: .orange) {
                            viewModel.saveImage()
                        }
                    }
                }
                .padding(16)
                .background(
                    VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                        .opacity(1)
                )
            }
            
            // OCR 结果浮窗
            if showOCRResult && !viewModel.recognizedText.isEmpty {
                OCRResultPanel(
                    text: viewModel.recognizedText,
                    confidence: viewModel.ocrResults.isEmpty ? 0 : viewModel.ocrResults.map { $0.confidence }.reduce(0, +) / Float(viewModel.ocrResults.count),
                    onCopy: {
                        viewModel.copyText()
                    },
                    onClose: {
                        showOCRResult = false
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }
}

// MARK: - OCR 结果面板
struct OCRResultPanel: View {
    let text: String
    let confidence: Float
    let onCopy: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "text.viewfinder")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                    
                    Text("识别结果")
                        .font(.system(size: 14, weight: .semibold))
                }
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
            }
            .padding(16)
            
            Divider()
            
            // 统计信息
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                    Text("\(text.components(separatedBy: "\n").count) 行")
                        .font(.system(size: 11))
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                    Text("\(Int(confidence * 100))%")
                        .font(.system(size: 11))
                }
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.05))
            
            // 文字内容
            ScrollView {
                Text(text)
                    .font(.system(size: 12))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            
            Divider()
            
            // 操作按钮
            Button(action: onCopy) {
                HStack {
                    Image(systemName: "doc.on.doc")
                    Text("复制文字")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.blue.gradient)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(16)
            .pointingHandCursor()
        }
        .frame(width: 280)
        .background(
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(0.98)
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 20)
        .padding(.trailing, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
    }
}

// MARK: - 组件

struct SectionTitle: View {
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
        }
    }
}

struct CaptureModeButton: View {
    let mode: CaptureMode
    var isCompact: Bool = false
    var isProcessing: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: isCompact ? 8 : 12) {
                ZStack {
                    Circle()
                        .fill(mode.color.opacity(0.2))
                        .frame(width: isCompact ? 40 : 48, height: isCompact ? 40 : 48)
                    
                    Image(systemName: mode.icon)
                        .font(.system(size: isCompact ? 18 : 20))
                        .foregroundStyle(mode.color.gradient)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.rawValue)
                        .font(.system(size: isCompact ? 12 : 14, weight: .semibold))
                    
                    if !isCompact {
                        Text("点击开始截图")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
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
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(mode.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isProcessing)
        .pointingHandCursor()
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .frame(width: 20)
            Text(text)
        }
    }
}

struct ToolButton: View {
    let icon: String
    let label: String
    var isSelected: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundColor(isSelected ? .blue : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.blue.opacity(0.2) : Color.white.opacity(0.1))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
    }
}

struct ActionButtonOCR: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.gradient)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
    }
}

struct DelayPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var seconds: Int
    let options = [3, 5, 10, 15, 30]
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(1)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Text("延时时长")
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
                .padding(20)
                
                Divider()
                
                VStack(spacing: 0) {
                    ForEach(options, id: \.self) { option in
                        Button(action: {
                            seconds = option
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "timer")
                                    .foregroundColor(.orange)
                                Text("\(option) 秒")
                                Spacer()
                                if seconds == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .font(.system(size: 14))
                            .padding(16)
                            .background(seconds == option ? Color.blue.opacity(0.1) : Color.clear)
                        }
                        .buttonStyle(.plain)
                        .pointingHandCursor()
                        
                        if option != options.last {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
            }
        }
        .frame(width: 260, height: 300)
        .focusable(false)
    }
}

struct ToastView: View {
    let message: String
    
    var body: some View {
        Text("✓ \(message)")
            .font(.system(size: 12))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.green.opacity(0.9))
            .foregroundColor(.white)
            .cornerRadius(18)
            .padding(.top, 70)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct VisualEffectBlurOCR: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

extension View {
    func pointingHandCursorOCR() -> some View {
        self.onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

#Preview {
    ScreenshotToolView()
}
