import SwiftUI
import Vision
import AppKit
import ScreenCaptureKit

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
            
            // 配置识别选项
            request.recognitionLevel = .accurate  // 使用高精度识别
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]  // 支持中英文
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

// MARK: - 截图服务
class ScreenshotService {
    static let shared = ScreenshotService()
    
    // 使用系统截图快捷键（需要用户手动截图）
    func captureScreenInteractive() async -> NSImage? {
        // 方案1：调用系统截图工具
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = ["-i", "-c"]  // -i 交互式, -c 复制到剪贴板
        
        try? task.run()
        task.waitUntilExit()
        
        // 从剪贴板读取
        if let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            return image
        }
        
        return nil
    }
    
    // 从剪贴板读取图片
    func getImageFromClipboard() -> NSImage? {
        return NSPasteboard.general.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage
    }
    
    // 从文件选择图片
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
    
    private let ocrService = OCRService.shared
    private let screenshotService = ScreenshotService.shared
    
    func captureAndRecognize() async {
        isProcessing = true
        errorMessage = nil
        
        // 调用系统截图
        if let image = await screenshotService.captureScreenInteractive() {
            currentImage = image
            await performOCR(on: image)
        } else {
            errorMessage = "截图失败或已取消"
            isProcessing = false
        }
    }
    
    func recognizeFromClipboard() async {
        guard let image = screenshotService.getImageFromClipboard() else {
            errorMessage = "剪贴板中没有图片"
            return
        }
        
        currentImage = image
        await performOCR(on: image)
    }
    
    func recognizeFromFile() async {
        guard let image = screenshotService.selectImageFile() else {
            return
        }
        
        currentImage = image
        await performOCR(on: image)
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
                
                // 计算平均置信度
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
    
    func clear() {
        recognizedText = ""
        ocrResults = []
        currentImage = nil
        errorMessage = nil
        averageConfidence = 0
    }
}

// MARK: - Main View
struct OCRScreenshotView: View {
    @StateObject private var viewModel = OCRViewModel()
    @Environment(\.dismiss) var dismiss
    
    private enum Layout {
        static let width: CGFloat = 420
        static let height: CGFloat = 560
        static let padding: CGFloat = 20
        static let cornerRadius: CGFloat = 10
    }
    
    var body: some View {
        ZStack {
            backgroundView
            
            VStack(spacing: 0) {
                headerBar
                Divider()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // 操作按钮
                        actionButtons
                        
                        // 图片预览
                        if let image = viewModel.currentImage {
                            imagePreview(image)
                        }
                        
                        // 状态显示
                        if viewModel.isProcessing {
                            loadingView
                        } else if let error = viewModel.errorMessage {
                            errorView(error)
                        } else if !viewModel.recognizedText.isEmpty {
                            resultSection
                        } else {
                            emptyState
                        }
                        
                        Spacer(minLength: 20)
                    }
                    .padding(Layout.padding)
                }
            }
        }
        .frame(width: Layout.width, height: Layout.height)
        .focusable(false)
        .overlay(alignment: .top) {
            if viewModel.showSuccessToast {
                toastView
            }
        }
    }
    
    // MARK: - Background
    private var backgroundView: some View {
        VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
            .opacity(0.95)
            .ignoresSafeArea()
    }
    
    // MARK: - Header
    private var headerBar: some View {
        HStack {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 16))
                .foregroundStyle(.blue.gradient)
            
            Text("截图识字")
                .font(.system(size: 16, weight: .semibold))
            
            Spacer()
            
            if !viewModel.recognizedText.isEmpty {
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
        .padding(.horizontal, Layout.padding)
        .padding(.vertical, 16)
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button(action: {
                Task {
                    await viewModel.captureAndRecognize()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 14))
                    Text("截图识字")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.blue.gradient)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isProcessing)
            .keyboardShortcut("n", modifiers: .command)
            
            HStack(spacing: 10) {
                Button(action: {
                    Task {
                        await viewModel.recognizeFromClipboard()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 12))
                        Text("剪贴板")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isProcessing)
                
                Button(action: {
                    Task {
                        await viewModel.recognizeFromFile()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo")
                            .font(.system(size: 12))
                        Text("选择图片")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isProcessing)
            }
        }
    }
    
    // MARK: - Image Preview
    private func imagePreview(_ image: NSImage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("图片预览")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 150)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
    }
    
    // MARK: - Result Section
    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("识别结果")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // 置信度指示
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(confidenceColor)
                    Text("\(viewModel.averageConfidence * 100, specifier: "%.0f")%")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(confidenceColor)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(confidenceColor.opacity(0.15))
                .cornerRadius(12)
                
                Button(action: viewModel.copyToClipboard) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text("复制")
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
            }
            
            // 文字内容
            ScrollView {
                Text(viewModel.recognizedText)
                    .font(.system(size: 13))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(height: 200)
            .background(Color.white.opacity(0.05))
            .cornerRadius(Layout.cornerRadius)
            
            // 详细结果
            if viewModel.ocrResults.count > 1 {
                DisclosureGroup {
                    VStack(spacing: 6) {
                        ForEach(viewModel.ocrResults) { result in
                            HStack(spacing: 8) {
                                Text(result.text)
                                    .font(.system(size: 11))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Text("\(result.confidencePercentage)%")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                            
                            if result.id != viewModel.ocrResults.last?.id {
                                Divider()
                            }
                        }
                    }
                } label: {
                    Text("查看 \(viewModel.ocrResults.count) 行详情")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                }
                .padding(10)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
            }
        }
    }
    
    private var confidenceColor: Color {
        let confidence = viewModel.averageConfidence
        if confidence > 0.9 { return .green }
        if confidence > 0.7 { return .orange }
        return .red
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(.blue.gradient)
            
            Text("截图识别文字")
                .font(.system(size: 14, weight: .medium))
            
            VStack(spacing: 8) {
                Text("• 点击「截图识字」进行截图")
                Text("• 从剪贴板或文件识别")
                Text("• 支持中英文混合识别")
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Loading
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            Text("识别中...")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Error
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(.orange.gradient)
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical: 40)
    }
    
    // MARK: - Toast
    private var toastView: some View {
        Text("✓ \(viewModel.toastMessage)")
            .font(.system(size: 12))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.green.opacity(0.9))
            .foregroundColor(.white)
            .cornerRadius(16)
            .padding(.top, 60)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                withAnimation(.easeInOut(duration: 0.3).delay(1.5)) {
                    viewModel.showSuccessToast = false
                }
            }
    }
}

#Preview {
    OCRScreenshotView()
}