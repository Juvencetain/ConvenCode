import SwiftUI
import AppKit
internal import UniformTypeIdentifiers
import ImageIO

// MARK: - 主视图 (布局已修复)
struct IconGeneratorView: View {
    // MARK: - State Properties
    @State private var sourceImage: NSImage?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showSuccessToast = false
    @State private var toastMessage = ""

    @State private var generateForMacOS = true
    @State private var generateForIOS = true
    @State private var generateIcnsFile = true
    @State private var roundCorners = true

    // MARK: - Body
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                
                Divider().padding(.horizontal, 20)

                if let image = sourceImage {
                    // 仅在加载图片后使用 ScrollView，因为此时内容可能超出
                    ScrollView {
                        loadedStateContent(with: image)
                    }
                } else {
                    // 在初始状态下，不使用 ScrollView，让 VStack 自动填充
                    imageDropView
                }
            }
        }
        .frame(width: 420, height: 600)
        .overlay(alignment: .top) {
            if showSuccessToast {
                toastView
            }
        }
    }

    // MARK: - 子视图
    private var headerBar: some View {
        HStack {
            Image(systemName: "app.dashed")
                .font(.system(size: 16))
                .foregroundStyle(.teal.gradient)
            Text("App Icon 生成器")
                .font(.system(size: 14, weight: .medium))
            Spacer()
        }
        .padding(20)
    }

    private var imageDropView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 80))
                .foregroundColor(.secondary.opacity(0.5))
            Text("拖拽一张 1024x1024 的图片\n或点击选择文件")
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // 关键：让 VStack 填满所有可用空间
        .background(Color.black.opacity(0.2))
        .cornerRadius(12)
        .padding(20)
        .onTapGesture(perform: selectImage)
        .onDrop(of: [.fileURL], isTargeted: nil, perform: handleDrop)
    }
    
    // 这是一个纯粹的内容容器，将被放入 ScrollView 中
    private func loadedStateContent(with image: NSImage) -> some View {
        VStack(spacing: 20) {
            imagePreview(image: image)
            
            if let errorMessage = errorMessage {
                errorView(errorMessage)
            }
            
            generationOptions
            actionButton
        }
        .padding(20)
    }

    private func imagePreview(image: NSImage) -> some View {
        VStack {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 150, height: 150)
                .cornerRadius(roundCorners ? 150 * 0.2257 : 0)
                .animation(.spring(), value: roundCorners)
                .shadow(radius: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: roundCorners ? 150 * 0.2257 : 8)
                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                        .animation(.spring(), value: roundCorners)
                )
            
            Text("建议使用 1024x1024 或更大的方形图片")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
    }

    private var generationOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("生成选项")
                .font(.headline)
                .padding(.bottom, 4)

            Toggle(isOn: $generateForMacOS) {
                Label("macOS AppIcon.appiconset", systemImage: "desktopcomputer")
            }
            .toggleStyle(.switch)

            Toggle(isOn: $generateForIOS) {
                Label("iOS AppIcon.appiconset", systemImage: "iphone")
            }
            .toggleStyle(.switch)

            Toggle(isOn: $generateIcnsFile) {
                Label("macOS .icns 文件", systemImage: "app.fill")
            }
            .toggleStyle(.switch)
            
            Divider()
            
            Toggle(isOn: $roundCorners) {
                Label("圆角图标 (macOS Big Sur+ 风格)", systemImage: "square.on.circle")
            }
            .toggleStyle(.switch)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }

    private var actionButton: some View {
        VStack(spacing: 10) {
            if isProcessing {
                ProgressView("正在生成...")
                    .frame(height: 38)
            } else {
                Button(action: generateAndSaveIcons) {
                    Label("生成并保存", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ModernButtonStyle(style: .execute))
                .disabled(sourceImage == nil || (!generateForMacOS && !generateForIOS && !generateIcnsFile))
            }
            
            Button(action: reset) {
                Label("移除图片", systemImage: "xmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ModernButtonStyle(style: .danger))
        }
    }
    
    private func errorView(_ message: String) -> some View {
        HStack {
            Image(systemName: "xmark.octagon.fill")
            Text(message)
            Spacer()
        }
        .font(.system(size: 12))
        .padding(12)
        .background(Color.red.opacity(0.15))
        .foregroundColor(.red)
        .cornerRadius(10)
    }
    
    private var toastView: some View {
        Text("✓ \(toastMessage)")
            .font(.system(size: 13))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.green.opacity(0.9))
            .foregroundColor(.white)
            .cornerRadius(20)
            .padding(.top, 60)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { showSuccessToast = false }
                }
            }
    }


    // MARK: - 核心逻辑 (无变动)
    private func selectImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.jpeg, UTType.png, UTType.tiff]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            loadImage(from: url)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
            guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            DispatchQueue.main.async {
                loadImage(from: url)
            }
        }
        return true
    }
    
    private func loadImage(from url: URL) {
        if let image = NSImage(contentsOf: url) {
            sourceImage = image
            errorMessage = nil
        } else {
            errorMessage = "无法加载图片"
        }
    }

    private func generateAndSaveIcons() {
        guard let image = sourceImage else { return }
        
        isProcessing = true
        errorMessage = nil

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.title = "选择保存图标的文件夹"
        
        panel.begin { response in
            if response == .OK, let directoryURL = panel.url {
                Task {
                    do {
                        var generatedSomething = false
                        if generateForMacOS {
                            let macURL = directoryURL.appendingPathComponent("macOS/AppIcon.appiconset")
                            try generateIconSet(for: .macOS, image: image, at: macURL)
                            generatedSomething = true
                        }
                        
                        if generateForIOS {
                            let iosURL = directoryURL.appendingPathComponent("iOS/AppIcon.appiconset")
                            try generateIconSet(for: .iOS, image: image, at: iosURL)
                            generatedSomething = true
                        }
                        
                        if generateIcnsFile {
                            let macosDirectoryURL = directoryURL.appendingPathComponent("macOS")
                            try FileManager.default.createDirectory(at: macosDirectoryURL, withIntermediateDirectories: true, attributes: nil)
                            let icnsURL = macosDirectoryURL.appendingPathComponent("AppIcon.icns")
                            try createIcnsFile(from: image, at: icnsURL)
                            generatedSomething = true
                        }
                        
                        await MainActor.run {
                            if generatedSomething {
                                toastMessage = "图标已成功生成！"
                                showSuccessToast = true
                            } else {
                                errorMessage = "请至少选择一个生成选项"
                            }
                        }

                    } catch {
                        await MainActor.run {
                            errorMessage = "生成失败: \(error.localizedDescription)"
                        }
                    }
                    await MainActor.run {
                        isProcessing = false
                    }
                }
            } else {
                isProcessing = false
            }
        }
    }

    private func generateIconSet(for platform: IconGenerator.Platform, image: NSImage, at folderURL: URL) throws {
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
        
        let iconSpecs = (platform == .macOS) ? IconGenerator.macOSIconSpecs : IconGenerator.iOSIconSpecs
        
        for spec in iconSpecs {
            let shouldRound = (platform == .macOS && self.roundCorners)
            if let resizedImage = resizeImage(image: image, size: spec.pixelSize, roundCorners: shouldRound) {
                try saveImage(resizedImage, to: folderURL, fileName: spec.filename(for: platform))
            }
        }
        
        try createContentsJSON(for: platform, at: folderURL)
    }

    private func createIcnsFile(from image: NSImage, at url: URL) throws {
        let icnsType = "com.apple.icns"
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, icnsType as CFString, IconGenerator.macOSIconSpecs.count, nil) else {
            throw NSError(domain: "IconGenerator", code: 3, userInfo: [NSLocalizedDescriptionKey: "无法创建 CGImageDestination"])
        }

        for spec in IconGenerator.macOSIconSpecs {
            if let resizedImage = resizeImage(image: image, size: spec.pixelSize, roundCorners: self.roundCorners),
               let cgImage = resizedImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                CGImageDestinationAddImage(destination, cgImage, nil)
            }
        }

        if !CGImageDestinationFinalize(destination) {
            throw NSError(domain: "IconGenerator", code: 4, userInfo: [NSLocalizedDescriptionKey: "无法完成 ICNS 文件生成"])
        }
    }

    private func resizeImage(image: NSImage, size: CGSize, roundCorners: Bool) -> NSImage? {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high

        if roundCorners {
            let cornerRadius = size.width * 0.2257
            let path = NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: cornerRadius, yRadius: cornerRadius)
            path.addClip()
        }

        image.draw(in: NSRect(origin: .zero, size: size), from: NSRect(origin: .zero, size: image.size), operation: .sourceOver, fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }

    private func saveImage(_ image: NSImage, to folderURL: URL, fileName: String) throws {
        let fileURL = folderURL.appendingPathComponent(fileName)
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "IconGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法将图片转换为 PNG 数据"])
        }
        try pngData.write(to: fileURL)
    }

    private func createContentsJSON(for platform: IconGenerator.Platform, at folderURL: URL) throws {
        let specs = (platform == .macOS) ? IconGenerator.macOSIconSpecs : IconGenerator.iOSIconSpecs
        let idiom = (platform == .macOS) ? "mac" : "iphone"
        
        let images = specs.map { IconGenerator.JSONImage(size: "\($0.pointSize)x\($0.pointSize)", idiom: idiom, filename: $0.filename(for: platform), scale: "\($0.scale)x") }
        let jsonContent = IconGenerator.ContentsJSON(images: images, info: .init(version: 1, author: "xcode"))
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(jsonContent)
        
        let fileURL = folderURL.appendingPathComponent("Contents.json")
        try jsonData.write(to: fileURL)
    }
    
    private func reset() {
        sourceImage = nil
        errorMessage = nil
        isProcessing = false
    }
}

// MARK: - Icon Generator Models (无变动)
struct IconGenerator {
    enum Platform { case macOS, iOS }

    struct IconSpec {
        let pointSize: Int
        let scale: Int
        var pixelSize: CGSize { CGSize(width: pointSize * scale, height: pointSize * scale) }
        
        func filename(for platform: Platform) -> String {
            switch platform {
            case .macOS:
                return "icon_\(pointSize)x\(pointSize)@\(scale)x.png"
            case .iOS:
                if pointSize == 1024 {
                    return "icon-1024.png"
                }
                return "icon-\(pointSize)@\(scale)x.png"
            }
        }
    }
    
    static let macOSIconSpecs: [IconSpec] = [
        .init(pointSize: 16, scale: 1), .init(pointSize: 16, scale: 2),
        .init(pointSize: 32, scale: 1), .init(pointSize: 32, scale: 2),
        .init(pointSize: 128, scale: 1), .init(pointSize: 128, scale: 2),
        .init(pointSize: 256, scale: 1), .init(pointSize: 256, scale: 2),
        .init(pointSize: 512, scale: 1), .init(pointSize: 512, scale: 2)
    ]

    static let iOSIconSpecs: [IconSpec] = [
        .init(pointSize: 20, scale: 2), .init(pointSize: 20, scale: 3),
        .init(pointSize: 29, scale: 2), .init(pointSize: 29, scale: 3),
        .init(pointSize: 40, scale: 2), .init(pointSize: 40, scale: 3),
        .init(pointSize: 60, scale: 2), .init(pointSize: 60, scale: 3),
        .init(pointSize: 1024, scale: 1)
    ]

    struct ContentsJSON: Codable {
        let images: [JSONImage]
        let info: JSONInfo
    }

    struct JSONImage: Codable {
        let size: String
        let idiom: String
        let filename: String
        let scale: String
    }

    struct JSONInfo: Codable {
        let version: Int
        let author: String
    }
}
