import SwiftUI
import AppKit
internal import UniformTypeIdentifiers // [FIX] 导入必要的框架

// MARK: - 主视图
struct ImageToolsView: View {
    // MARK: - State Properties
    @State private var originalImage: NSImage?
    @State private var processedImage: NSImage?
    
    // Tool States
    @State private var compressionQuality: Double = 0.7
    @State private var isCropping = false
    @State private var cropSelection: CGRect?
    
    // UI States
    @State private var errorMessage: String?
    @State private var showSuccessToast = false
    @State private var toastMessage = ""
    @State private var imageFrame: CGRect = .zero

    private var displayImage: NSImage? {
        processedImage ?? originalImage
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                Divider()
                
                HSplitView {
                    imageDisplayArea
                        .frame(minWidth: 250, maxWidth: .infinity)

                    controlsArea
                        .frame(width: 200)
                }
            }
        }
        .overlay(alignment: .top) {
            if showSuccessToast {
                toastView
            }
        }
    }

    // MARK: - 子视图
    private var headerBar: some View {
        HStack {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 16))
                .foregroundStyle(.purple.gradient)
            Text("图片工具箱")
                .font(.system(size: 14, weight: .medium))
            Spacer()
        }
        .padding()
    }

    private var imageDisplayArea: some View {
        ZStack {
            if let image = displayImage {
                GeometryReader { geo in
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .background(GeometryReader { imageGeo -> Color in
                            DispatchQueue.main.async {
                                self.imageFrame = imageGeo.frame(in: .local)
                            }
                            return Color.clear
                        })
                }
                .overlay(croppingOverlay)
            } else {
                imageDropView
            }
            
            if let errorMessage = errorMessage {
                errorView(errorMessage)
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private var croppingOverlay: some View {
        if isCropping {
            CroppingRectangle(selection: $cropSelection)
        }
    }

    private var controlsArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let image = displayImage {
                    imageInfoSection(image: image)
                }

                compressionSection
                croppingSection
                
                Spacer(minLength: 20)
                
                actionSection
            }
            .padding()
        }
        .disabled(originalImage == nil)
    }

    private var imageDropView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
            Text("拖拽图片到这里\n或点击选择文件")
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.2))
        .cornerRadius(12)
        .onTapGesture(perform: selectImage)
        .onDrop(of: [.fileURL], isTargeted: nil, perform: handleDrop)
    }
    
    private func imageInfoSection(image: NSImage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("图片信息").font(.headline)
            Divider()
            HStack {
                Text("尺寸:")
                Spacer()
                Text("\(Int(image.size.width)) x \(Int(image.size.height))")
            }
            HStack {
                Text("大小:")
                Spacer()
                if let data = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: data) {
                    if let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality]) {
                        Text(ByteCountFormatter.string(fromByteCount: Int64(jpegData.count), countStyle: .file))
                    }
                }
            }
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
    }
    
    private var compressionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("压缩").font(.headline)
            Divider()
            HStack {
                Text("质量")
                Spacer()
                Text("\(Int(compressionQuality * 100))%")
            }
            Slider(value: $compressionQuality, in: 0.1...1.0)
            Button(action: compressImage) {
                Label("应用压缩", systemImage: "arrow.down.to.line.compact")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ModernButtonStyle(style: .accent))
        }
    }
    
    private var croppingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("裁切").font(.headline)
            Divider()
            if isCropping {
                Button(action: applyCrop) {
                    Label("确认裁切", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ModernButtonStyle(style: .execute))
                Button(action: cancelCrop) {
                    Label("取消", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ModernButtonStyle(style: .danger))
            } else {
                Button(action: { isCropping = true }) {
                    Label("选择裁切区域", systemImage: "crop")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ModernButtonStyle())
            }
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("导出 / 重置").font(.headline)
            Divider()
            
            Button(action: { saveImage(as: .png) }) {
                Label("另存为 PNG", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ModernButtonStyle(style: .execute))
            
            Button(action: { saveImage(as: .jpeg) }) {
                Label("另存为 JPG", systemImage: "photo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ModernButtonStyle(style: .execute))

            Button(action: reset) {
                Label("移除图片", systemImage: "xmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ModernButtonStyle(style: .danger))
            .padding(.top)
        }
    }
    
    // MARK: - 浮动视图 (Toast & Error)

    private func errorView(_ message: String) -> some View {
        Text(message)
            .padding()
            .background(VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow))
            .cornerRadius(10)
            .foregroundColor(.red)
            .transition(.opacity)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    errorMessage = nil
                }
            }
    }
    
    private var toastView: some View {
        Text("✓ \(toastMessage)")
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.green.opacity(0.9))
            .foregroundColor(.white)
            .cornerRadius(20)
            .padding(.top, 40)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { showSuccessToast = false }
                }
            }
    }

    // MARK: - 功能函数

    private func selectImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.jpeg, UTType.png, UTType.tiff, UTType.gif, UTType.bmp]
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
            originalImage = image
            resetProcessing()
        } else {
            errorMessage = "无法加载所选图片"
        }
    }
    
    private func compressImage() {
        guard let imageToProcess = originalImage else { return }
        
        guard let tiffData = imageToProcess.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let compressedData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: NSNumber(value: compressionQuality)])
        else {
            errorMessage = "压缩图片失败"
            return
        }
        
        processedImage = NSImage(data: compressedData)
        toastMessage = "压缩已应用"
        showSuccessToast = true
    }

    private func applyCrop() {
        guard let imageToCrop = displayImage, let selection = cropSelection else { return }
        
        let imageSize = imageToCrop.size
        let viewSize = imageFrame.size
        
        let scaleX = imageSize.width / viewSize.width
        let scaleY = imageSize.height / viewSize.height
        
        let cropRectInImageCoords = CGRect(
            x: (selection.origin.x - imageFrame.origin.x) * scaleX,
            y: (imageSize.height - (selection.origin.y - imageFrame.origin.y + selection.height) * scaleY),
            width: selection.width * scaleX,
            height: selection.height * scaleY
        )

        guard let cgImage = imageToCrop.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let croppedCGImage = cgImage.cropping(to: cropRectInImageCoords)
        else {
            errorMessage = "裁切失败"
            return
        }

        let croppedNSImage = NSImage(cgImage: croppedCGImage, size: cropRectInImageCoords.size)
        processedImage = croppedNSImage
        originalImage = croppedNSImage
        
        cancelCrop()
        toastMessage = "裁切成功"
        showSuccessToast = true
    }
    
    private func cancelCrop() {
        isCropping = false
        cropSelection = nil
    }

    // [修改] 创建一个更通用的保存函数
    private func saveImage(as fileType: NSBitmapImageRep.FileType) {
        guard let imageToSave = displayImage else { return }
        
        let panel = NSSavePanel()
        let fileExtension = fileType == .png ? "png" : "jpg"
        let contentType = fileType == .png ? UTType.png : UTType.jpeg
        
        panel.allowedContentTypes = [contentType]
        panel.nameFieldStringValue = "processed-image.\(fileExtension)"
        
        if panel.runModal() == .OK, let url = panel.url {
            if let tiffData = imageToSave.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let data = bitmap.representation(using: fileType, properties: [.compressionFactor: NSNumber(value: compressionQuality)]) {
                do {
                    try data.write(to: url)
                    toastMessage = "已保存为 \(fileExtension.uppercased())"
                    showSuccessToast = true
                } catch {
                    errorMessage = "保存失败: \(error.localizedDescription)"
                }
            } else {
                errorMessage = "图像数据转换失败"
            }
        }
    }

    private func reset() {
        originalImage = nil
        resetProcessing()
    }
    
    private func resetProcessing() {
        processedImage = nil
        errorMessage = nil
        isCropping = false
        cropSelection = nil
        compressionQuality = 0.7
    }
}

// MARK: - 裁切选择框视图
struct CroppingRectangle: View {
    @Binding var selection: CGRect?
    @State private var startPoint: CGPoint?

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                if let selection = selection {
                    var fullRect = Path(CGRect(origin: .zero, size: size))
                    fullRect.addPath(Path(selection))
                    context.fill(fullRect, with: .color(.black.opacity(0.4)), style: FillStyle(eoFill: true))
                    
                    var selectionPath = Path()
                    selectionPath.addRect(selection)
                    context.stroke(selectionPath, with: .color(.blue), lineWidth: 1)
                }
            }
            .gesture(dragGesture(in: geometry.frame(in: .local)))
        }
    }

    private func dragGesture(in rect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if startPoint == nil {
                    startPoint = value.startLocation
                }
                let endPoint = value.location
                
                let boundedEnd = CGPoint(
                    x: max(0, min(rect.width, endPoint.x)),
                    y: max(0, min(rect.height, endPoint.y))
                )
                selection = CGRect(start: startPoint!, end: boundedEnd)
            }
            .onEnded { _ in
                startPoint = nil
            }
    }
}


extension CGRect {
    init(start: CGPoint, end: CGPoint) {
        self.init(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(start.x - end.x), height: abs(start.y - end.y))
    }
}
