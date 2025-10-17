import SwiftUI
import AppKit
internal import UniformTypeIdentifiers

// MARK: - 水印类型
enum WatermarkType: String, CaseIterable {
    case text = "文字水印"
    case image = "图片水印"
    
    var watermarkIconName: String {
        switch self {
        case .text: return "textformat"
        case .image: return "photo"
        }
    }
}

// MARK: - 水印位置
enum WatermarkPosition: String, CaseIterable {
    case topLeft = "左上"
    case topCenter = "上中"
    case topRight = "右上"
    case centerLeft = "左中"
    case center = "居中"
    case centerRight = "右中"
    case bottomLeft = "左下"
    case bottomCenter = "下中"
    case bottomRight = "右下"
    case tile = "平铺"
    
    var watermarkIconName: String {
        switch self {
        case .topLeft: return "arrow.up.left"
        case .topCenter: return "arrow.up"
        case .topRight: return "arrow.up.right"
        case .centerLeft: return "arrow.left"
        case .center: return "circle"
        case .centerRight: return "arrow.right"
        case .bottomLeft: return "arrow.down.left"
        case .bottomCenter: return "arrow.down"
        case .bottomRight: return "arrow.down.right"
        case .tile: return "square.grid.3x3"
        }
    }
}

// MARK: - 水印配置
struct WatermarkConfig {
    // 通用配置
    var watermarkType: WatermarkType = .text
    var watermarkPosition: WatermarkPosition = .bottomRight
    var watermarkOpacity: Double = 0.5
    var watermarkOffsetX: CGFloat = 20
    var watermarkOffsetY: CGFloat = 20
    
    // 文字水印配置
    var watermarkText: String = "Watermark"
    var watermarkFontSize: CGFloat = 36
    var watermarkTextColor: Color = .white
    var watermarkFontName: String = "Helvetica-Bold"
    var watermarkRotation: Double = 0
    
    // 图片水印配置
    var watermarkImageData: Data?
    var watermarkImageScale: CGFloat = 1.0
    
    // 平铺配置
    var watermarkTileSpacing: CGFloat = 100
}

// MARK: - 处理的图片模型
struct WatermarkImageItem: Identifiable {
    let id = UUID()
    let watermarkOriginalURL: URL
    let watermarkOriginalImage: NSImage
    var watermarkProcessedImage: NSImage?
    var watermarkIsProcessing: Bool = false
    var watermarkProcessingError: String?
    
    var watermarkFileName: String {
        watermarkOriginalURL.lastPathComponent
    }
    
    var watermarkFileSize: String {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: watermarkOriginalURL.path),
           let size = attrs[.size] as? Int64 {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useAll]
            formatter.countStyle = .file
            return formatter.string(fromByteCount: size)
        }
        return "未知"
    }
}

// MARK: - 水印工具视图
struct WatermarkToolView: View {
    @StateObject private var watermarkViewModel = WatermarkToolViewModel()
    @State private var watermarkConfig = WatermarkConfig()
    @State private var watermarkShowPreview = false
    
    var body: some View {
        ZStack {
            // 背景
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            HStack(spacing: 0) {
                // 左侧配置面板
                watermarkConfigPanel
                    .frame(width: 280)
                
                Divider()
                
                // 右侧图片列表
                watermarkImageListPanel
            }
        }
        .frame(width: 900, height: 650)
    }
    
    // MARK: - 配置面板
    private var watermarkConfigPanel: some View {
        VStack(spacing: 0) {
            // 标题
            HStack(spacing: 12) {
                Image(systemName: "wand.and.rays")
                    .font(.system(size: 20))
                    .foregroundStyle(.purple.gradient)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("水印配置")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("\(watermarkViewModel.watermarkImages.count) 张图片")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            
            Divider()
            
            // 配置内容
            ScrollView {
                VStack(spacing: 20) {
                    // 水印类型选择
                    watermarkTypeSection
                    
                    // 根据类型显示不同配置
                    if watermarkConfig.watermarkType == .text {
                        watermarkTextConfigSection
                    } else {
                        watermarkImageConfigSection
                    }
                    
                    // 位置配置
                    watermarkPositionSection
                    
                    // 通用配置
                    watermarkCommonConfigSection
                    
                    // 操作按钮
                    watermarkActionButtons
                }
                .padding(16)
            }
        }
    }
    
    // MARK: - 水印类型选择
    private var watermarkTypeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("水印类型")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            
            HStack(spacing: 10) {
                ForEach(WatermarkType.allCases, id: \.self) { type in
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            watermarkConfig.watermarkType = type
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: type.watermarkIconName)
                                .font(.system(size: 14))
                            Text(type.rawValue)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(watermarkConfig.watermarkType == type ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(watermarkConfig.watermarkType == type ? Color.purple : Color.white.opacity(0.05))
                        )
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                }
            }
        }
    }
    
    // MARK: - 文字水印配置
    private var watermarkTextConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("文字设置")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            
            // 水印文字
            VStack(alignment: .leading, spacing: 6) {
                Text("水印文字")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                TextField("输入水印文字", text: $watermarkConfig.watermarkText)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(6)
            }
            
            // 字体大小
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("字体大小")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(watermarkConfig.watermarkFontSize))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.blue)
                }
                
                Slider(value: $watermarkConfig.watermarkFontSize, in: 12...120, step: 1)
                    .accentColor(.purple)
                    .controlSize(.regular)
            }
            
            // 文字颜色
            HStack(spacing: 10) {
                Text("文字颜色")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                ColorPicker("", selection: $watermarkConfig.watermarkTextColor)
                    .labelsHidden()
                    .frame(width: 40, height: 28)
            }
            
            // 旋转角度
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("旋转角度")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(watermarkConfig.watermarkRotation))°")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.blue)
                }
                
                Slider(value: $watermarkConfig.watermarkRotation, in: -180...180, step: 1)
                    .accentColor(.purple)
                    .controlSize(.regular)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    // MARK: - 图片水印配置
    private var watermarkImageConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("图片设置")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            
            // 选择水印图片
            if watermarkConfig.watermarkImageData == nil {
                Button(action: { watermarkSelectWatermarkImage() }) {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                        
                        Text("选择水印图片")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 2]))
                            .foregroundColor(.blue.opacity(0.5))
                    )
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
            } else {
                // 显示已选择的水印图片
                HStack(spacing: 10) {
                    if let data = watermarkConfig.watermarkImageData,
                       let nsImage = NSImage(data: data) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                            .cornerRadius(6)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("水印图片")
                            .font(.system(size: 12, weight: .medium))
                        
                        Button("更换图片") {
                            watermarkSelectWatermarkImage()
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                        .buttonStyle(.plain)
                        .pointingHandCursor()
                    }
                    
                    Spacer()
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                )
            }
            
            // 图片缩放
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("缩放比例")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.1f%%", watermarkConfig.watermarkImageScale * 100))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.blue)
                }
                
                Slider(value: $watermarkConfig.watermarkImageScale, in: 0.1...2.0, step: 0.1)
                    .accentColor(.purple)
                    .controlSize(.regular)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    // MARK: - 位置配置
    private var watermarkPositionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("水印位置")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(WatermarkPosition.allCases.prefix(9), id: \.self) { position in
                    watermarkPositionButton(position)
                }
            }
            
            // 平铺选项
            watermarkPositionButton(.tile)
        }
    }
    
    private func watermarkPositionButton(_ position: WatermarkPosition) -> some View {
        Button(action: {
            watermarkConfig.watermarkPosition = position
        }) {
            VStack(spacing: 4) {
                Image(systemName: position.watermarkIconName)
                    .font(.system(size: 16))
                
                Text(position.rawValue)
                    .font(.system(size: 10))
            }
            .foregroundColor(watermarkConfig.watermarkPosition == position ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(watermarkConfig.watermarkPosition == position ? Color.purple : Color.white.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
    }
    
    // MARK: - 通用配置
    private var watermarkCommonConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("通用设置")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            
            // 透明度
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("透明度")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.0f%%", watermarkConfig.watermarkOpacity * 100))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.blue)
                }
                
                Slider(value: $watermarkConfig.watermarkOpacity, in: 0.1...1.0, step: 0.1)
                    .accentColor(.purple)
                    .controlSize(.regular)
            }
            
            // 边距调整
            if watermarkConfig.watermarkPosition != .tile {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("边距")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(watermarkConfig.watermarkOffsetX)) px")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.blue)
                    }
                    
                    Slider(value: $watermarkConfig.watermarkOffsetX, in: 0...200, step: 5)
                        .accentColor(.purple)
                        .controlSize(.regular)
                }
            }
            
            // 平铺间距
            if watermarkConfig.watermarkPosition == .tile {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("平铺间距")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(watermarkConfig.watermarkTileSpacing)) px")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.blue)
                    }
                    
                    Slider(value: $watermarkConfig.watermarkTileSpacing, in: 50...300, step: 10)
                        .accentColor(.purple)
                        .controlSize(.regular)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    // MARK: - 操作按钮
    private var watermarkActionButtons: some View {
        VStack(spacing: 10) {
            Button(action: { watermarkViewModel.watermarkAddImages() }) {
                Label("添加图片", systemImage: "photo.badge.plus")
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(WatermarkPrimaryButtonStyle(color: .blue))
            
            Button(action: { watermarkApplyWatermark() }) {
                Label("应用水印", systemImage: "wand.and.stars")
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(WatermarkPrimaryButtonStyle(color: .purple))
            .disabled(watermarkViewModel.watermarkImages.isEmpty || watermarkViewModel.watermarkIsProcessing)
            
            if !watermarkViewModel.watermarkImages.isEmpty {
                Button(action: { watermarkExportAll() }) {
                    Label("导出全部", systemImage: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(WatermarkPrimaryButtonStyle(color: .green))
                .disabled(!watermarkViewModel.watermarkHasProcessedImages())
            }
        }
    }
    
    // MARK: - 图片列表面板
    private var watermarkImageListPanel: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack(spacing: 12) {
                Text("图片列表")
                    .font(.system(size: 14, weight: .semibold))
                
                if watermarkViewModel.watermarkIsProcessing {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                    
                    Text("处理中...")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { watermarkViewModel.watermarkClearAll() }) {
                    Label("清空", systemImage: "trash")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
                .pointingHandCursor()
                .disabled(watermarkViewModel.watermarkImages.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            
            Divider()
            
            // 图片网格
            if watermarkViewModel.watermarkImages.isEmpty {
                watermarkEmptyState
            } else {
                watermarkImageGrid
            }
        }
    }
    
    // MARK: - 空状态
    private var watermarkEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 56))
                .foregroundStyle(.secondary.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("还没有添加图片")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Text("点击左侧添加图片按钮开始")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 图片网格
    private var watermarkImageGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 180), spacing: 16)
            ], spacing: 16) {
                ForEach(watermarkViewModel.watermarkImages) { item in
                    WatermarkImageCard(item: item) {
                        watermarkViewModel.watermarkRemoveImage(item)
                    } onExport: {
                        watermarkExportSingle(item)
                    }
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - 辅助方法
    private func watermarkSelectWatermarkImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        
        if panel.runModal() == .OK, let url = panel.url {
            if let data = try? Data(contentsOf: url) {
                watermarkConfig.watermarkImageData = data
            }
        }
    }
    
    private func watermarkApplyWatermark() {
        watermarkViewModel.watermarkApplyWatermark(config: watermarkConfig)
    }
    
    private func watermarkExportAll() {
        watermarkViewModel.watermarkExportAll()
    }
    
    private func watermarkExportSingle(_ item: WatermarkImageItem) {
        watermarkViewModel.watermarkExportSingle(item: item)
    }
}

// MARK: - 图片卡片
struct WatermarkImageCard: View {
    let item: WatermarkImageItem
    let onRemove: () -> Void
    let onExport: () -> Void
    
    @State private var watermarkIsHovered = false
    
    var body: some View {
        VStack(spacing: 10) {
            // 图片预览
            ZStack(alignment: .topTrailing) {
                Group {
                    if let processed = item.watermarkProcessedImage {
                        Image(nsImage: processed)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(nsImage: item.watermarkOriginalImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                }
                .frame(width: 180, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                // 处理状态
                if item.watermarkIsProcessing {
                    ZStack {
                        Color.black.opacity(0.6)
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    }
                    .frame(width: 180, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                // 删除按钮
                if watermarkIsHovered {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white, .red)
                            .shadow(radius: 2)
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .pointingHandCursor()
                }
                
                // 已处理标记
                if item.watermarkProcessedImage != nil && !item.watermarkIsProcessing {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                        Text("已处理")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.green)
                    )
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            
            // 文件信息
            VStack(spacing: 4) {
                Text(item.watermarkFileName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(item.watermarkFileSize)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // 导出按钮
            if item.watermarkProcessedImage != nil {
                Button(action: onExport) {
                    Label("导出", systemImage: "square.and.arrow.up")
                        .font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(WatermarkCompactButtonStyle(color: .blue))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(watermarkIsHovered ? 0.08 : 0.05))
        )
        .onHover { hovering in
            watermarkIsHovered = hovering
        }
    }
}

// MARK: - 按钮样式
struct WatermarkPrimaryButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(configuration.isPressed ? 0.8 : 1.0))
            )
    }
}

struct WatermarkCompactButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(color)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(configuration.isPressed ? 0.2 : 0.1))
            )
    }
}

#Preview {
    WatermarkToolView()
}
