import SwiftUI
internal import UniformTypeIdentifiers

// MARK: - Main View
struct ImageToolsView: View {
    @StateObject private var imageViewModel = ImageToolsViewModel()

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ImageToolHeader()
                Divider()
                
                if imageViewModel.hasImage {
                    ImageWorkspaceView(imageViewModel: imageViewModel)
                } else {
                    ImageEmptyStateView(imageViewModel: imageViewModel)
                }
            }
        }
        .frame(width: 1000, height: 700)
        .overlay(alignment: .top) {
            if imageViewModel.showSuccessToast {
                ImageSuccessToast(message: imageViewModel.toastMessage)
            }
        }
        .onDisappear(perform: imageViewModel.cleanup)
    }
}

// MARK: - Header
private struct ImageToolHeader: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(Color.accentColor.gradient)

            Text("图片工具箱")
                .font(.system(size: 16, weight: .semibold))

            Spacer()

            ImageStatusBadge(text: "拖拽图片开始处理")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }
}

private struct ImageStatusBadge: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.12))
            )
    }
}

// MARK: - Empty State
private struct ImageEmptyStateView: View {
    @ObservedObject var imageViewModel: ImageToolsViewModel

    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 90, weight: .ultraLight))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 12) {
                Text("拖拽图片到这里")
                    .font(.title.weight(.semibold))

                Text("或点击选择文件")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            ImageSupportedFormatsTag()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 3, dash: [15, 8])
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.5), Color.accentColor.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.accentColor.opacity(0.04))
                )
        )
        .padding(32)
        .contentShape(Rectangle())
        .onTapGesture(perform: imageViewModel.selectImageFromPanel)
        .onDrop(of: [.fileURL], isTargeted: nil, perform: imageViewModel.handleImageDrop)
    }
}

private struct ImageSupportedFormatsTag: View {
    var body: some View {
        Text("支持 JPG, PNG, HEIC, TIFF, WebP, GIF, BMP")
            .font(.callout.weight(.medium))
            .foregroundColor(.secondary.opacity(0.9))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(0.12))
            )
    }
}

// MARK: - Workspace
private struct ImageWorkspaceView: View {
    @ObservedObject var imageViewModel: ImageToolsViewModel

    var body: some View {
        HSplitView {
            ImageCanvasView(imageViewModel: imageViewModel)
                .frame(minWidth: 400)

            ImageOperationsPanel(imageViewModel: imageViewModel)
                .frame(width: 340)
        }
    }
}

// MARK: - Image Canvas
private struct ImageCanvasView: View {
    @ObservedObject var imageViewModel: ImageToolsViewModel

    var body: some View {
        ZStack {
            if let image = imageViewModel.displayImage {
                VStack(spacing: 0) {
                    // 图片预览区
                    ImagePreviewView(image: image, imageViewModel: imageViewModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // 底部信息栏
                    ImageInfoBar(imageViewModel: imageViewModel)
                }
            }

            if let error = imageViewModel.errorMessage {
                ImageErrorAlert(message: error, onDismiss: imageViewModel.clearImageError)
            }
        }
        .background(Color.black.opacity(0.02))
    }
}

private struct ImagePreviewView: View {
    let image: NSImage
    @ObservedObject var imageViewModel: ImageToolsViewModel
    
    var body: some View {
        GeometryReader { geometry in
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .background(
                    GeometryReader { imageGeo in
                        Color.clear.onAppear {
                            imageViewModel.updateImageFrameRect(imageGeo.frame(in: .local))
                        }
                    }
                )
                .overlay {
                    if imageViewModel.isCropping {
                        ImageCropOverlay(selection: $imageViewModel.cropSelection)
                    }
                }
                .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
        }
        .padding(24)
    }
}

private struct ImageInfoBar: View {
    @ObservedObject var imageViewModel: ImageToolsViewModel
    
    var body: some View {
        HStack(spacing: 24) {
            if let info = imageViewModel.imageInfo {
                HStack(spacing: 8) {
                    Image(systemName: "ruler")
                        .foregroundColor(.secondary)
                    Text("\(info.width) × \(info.height) px")
                        .font(.subheadline.weight(.medium))
                }
                
                Divider()
                    .frame(height: 20)
                
                HStack(spacing: 8) {
                    Image(systemName: "doc")
                        .foregroundColor(.secondary)
                    Text(info.estimatedSize)
                        .font(.subheadline.weight(.medium))
                }
            }
            
            Spacer()
            
            Button(action: imageViewModel.resetImage) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("重新选择")
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.secondary.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
    }
}

// MARK: - Crop Overlay
private struct ImageCropOverlay: View {
    @Binding var selection: CGRect?
    @State private var imageDragStart: CGPoint?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let rect = selection {
                    ImageCropDimmedBackground(selection: rect, canvasSize: geometry.size)
                    ImageCropSelectionBorder(rect: rect)
                }
            }
            .gesture(createImageCropDragGesture(in: geometry.frame(in: .local)))
        }
    }
    
    private func createImageCropDragGesture(in bounds: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if imageDragStart == nil {
                    imageDragStart = value.startLocation
                }
                
                let clampedEnd = CGPoint(
                    x: value.location.x.clamped(to: 0...bounds.width),
                    y: value.location.y.clamped(to: 0...bounds.height)
                )
                
                if let start = imageDragStart {
                    selection = CGRect(from: start, to: clampedEnd)
                }
            }
            .onEnded { _ in
                imageDragStart = nil
            }
    }
}

private struct ImageCropDimmedBackground: View {
    let selection: CGRect
    let canvasSize: CGSize
    
    var body: some View {
        Canvas { context, size in
            var outerPath = Path(CGRect(origin: .zero, size: size))
            outerPath.addPath(Path(selection))
            
            context.fill(
                outerPath,
                with: .color(.black.opacity(0.55)),
                style: FillStyle(eoFill: true)
            )
        }
    }
}

private struct ImageCropSelectionBorder: View {
    let rect: CGRect
    
    var body: some View {
        Rectangle()
            .path(in: rect)
            .stroke(Color.accentColor, lineWidth: 2.5)
            .overlay(
                Rectangle()
                    .path(in: rect)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
            )
    }
}

// MARK: - Operations Panel
private struct ImageOperationsPanel: View {
    @ObservedObject var imageViewModel: ImageToolsViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // 压缩质量
                ImageCompressionSection(imageViewModel: imageViewModel)
                
                Divider()
                
                // 裁切工具
                ImageCropSection(imageViewModel: imageViewModel)
                
                Divider()
                
                // 格式转换 & 导出
                ImageExportSection(imageViewModel: imageViewModel)

                Spacer(minLength: 24)
            }
            .padding(24)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
    }
}

// MARK: - Compression Section
private struct ImageCompressionSection: View {
    @ObservedObject var imageViewModel: ImageToolsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("压缩质量", systemImage: "slider.horizontal.3")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.accentColor.gradient)
            
            VStack(spacing: 14) {
                HStack {
                    Text("质量等级")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(imageViewModel.compressionQuality * 100))%")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.accentColor.gradient)
                }
                
                Slider(value: $imageViewModel.compressionQuality, in: 0.1...1.0)
                    .tint(Color.accentColor)
                
                Text("调整质量后，在下方选择格式即可自动应用")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Crop Section
private struct ImageCropSection: View {
    @ObservedObject var imageViewModel: ImageToolsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("裁切工具", systemImage: "crop")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.accentColor.gradient)
            
            if imageViewModel.isCropping {
                VStack(spacing: 12) {
                    Text("在图片上拖拽选择裁切区域")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 12) {
                        Button(action: imageViewModel.applyImageCrop) {
                            Label("确认裁切", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ImageOperationButtonStyle(color: .green))
                        
                        Button(action: imageViewModel.cancelImageCrop) {
                            Label("取消", systemImage: "xmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ImageOperationButtonStyle(color: .red))
                    }
                }
            } else {
                Button(action: imageViewModel.startImageCropping) {
                    Label("开始裁切", systemImage: "crop.rotate")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ImageOperationButtonStyle(color: .accentColor))
            }
        }
    }
}

// MARK: - Export Section
private struct ImageExportSection: View {
    @ObservedObject var imageViewModel: ImageToolsViewModel
    
    let imageFormatColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("选择格式并导出", systemImage: "square.and.arrow.down")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.accentColor.gradient)
            
            Text("点击任意格式即可保存为该格式")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: imageFormatColumns, spacing: 12) {
                ForEach(ImageFormat.allCases) { format in
                    ImageFormatExportButton(imageFormat: format) {
                        imageViewModel.saveImageDirectly(as: format)
                    }
                }
            }
        }
    }
}

private struct ImageFormatExportButton: View {
    let imageFormat: ImageFormat
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: imageFormat.icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Color.accentColor.gradient)
                
                Text(imageFormat.displayName)
                    .font(.caption.weight(.bold))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accentColor.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor.opacity(0.25), lineWidth: 1.5)
            )
        }
        .buttonStyle(ImageFormatButtonPressStyle())
    }
}

private struct ImageFormatButtonPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Button Styles
private struct ImageOperationButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(color)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Toast & Alerts
private struct ImageSuccessToast: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.white)
            
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.green, Color.green.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
        .padding(.top, 60)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

private struct ImageErrorAlert: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(Color.red.gradient)

            Text(message)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.red.opacity(0.4), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.3), radius: 20)
        .transition(.scale.combined(with: .opacity))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { onDismiss() }
            }
        }
    }
}

// MARK: - Extensions
private extension CGRect {
    init(from start: CGPoint, to end: CGPoint) {
        self.init(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
