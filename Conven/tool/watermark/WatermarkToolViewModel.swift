import SwiftUI
import AppKit
internal import UniformTypeIdentifiers
import Combine

// MARK: - 水印工具视图模型
@MainActor
class WatermarkToolViewModel: ObservableObject {
    @Published var watermarkImages: [WatermarkImageItem] = []
    @Published var watermarkIsProcessing = false
    @Published var watermarkErrorMessage: String?
    
    // MARK: - 添加图片
    func watermarkAddImages() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        panel.message = "选择要添加水印的图片"
        
        if panel.runModal() == .OK {
            for url in panel.urls {
                if let nsImage = NSImage(contentsOf: url) {
                    let item = WatermarkImageItem(
                        watermarkOriginalURL: url,
                        watermarkOriginalImage: nsImage
                    )
                    watermarkImages.append(item)
                }
            }
        }
    }
    
    // MARK: - 移除图片
    func watermarkRemoveImage(_ item: WatermarkImageItem) {
        watermarkImages.removeAll { $0.id == item.id }
    }
    
    // MARK: - 清空所有
    func watermarkClearAll() {
        watermarkImages.removeAll()
        watermarkErrorMessage = nil
    }
    
    // MARK: - 应用水印
    func watermarkApplyWatermark(config: WatermarkConfig) {
        guard !watermarkImages.isEmpty else { return }
        
        // 验证配置
        if config.watermarkType == .text && config.watermarkText.isEmpty {
            watermarkErrorMessage = "请输入水印文字"
            return
        }
        
        if config.watermarkType == .image && config.watermarkImageData == nil {
            watermarkErrorMessage = "请选择水印图片"
            return
        }
        
        watermarkIsProcessing = true
        watermarkErrorMessage = nil
        
        Task {
            for index in watermarkImages.indices {
                watermarkImages[index].watermarkIsProcessing = true
                
                do {
                    let processedImage = try await watermarkProcessImage(
                        watermarkImages[index].watermarkOriginalImage,
                        config: config
                    )
                    
                    watermarkImages[index].watermarkProcessedImage = processedImage
                    watermarkImages[index].watermarkIsProcessing = false
                    watermarkImages[index].watermarkProcessingError = nil
                } catch {
                    watermarkImages[index].watermarkIsProcessing = false
                    watermarkImages[index].watermarkProcessingError = error.localizedDescription
                }
            }
            
            watermarkIsProcessing = false
        }
    }
    
    // MARK: - 处理单张图片
    private func watermarkProcessImage(_ image: NSImage, config: WatermarkConfig) async throws -> NSImage {
        return try await Task.detached {
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                throw WatermarkError.watermarkImageProcessingFailed
            }
            
            let width = cgImage.width
            let height = cgImage.height
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            
            guard let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                throw WatermarkError.watermarkContextCreationFailed
            }
            
            // 绘制原图
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            
            // 设置透明度
            context.setAlpha(config.watermarkOpacity)
            
            // 根据类型添加水印
            if config.watermarkType == .text {
                try await self.watermarkDrawTextWatermark(context: context, config: config, size: CGSize(width: width, height: height))
            } else {
                try await self.watermarkDrawImageWatermark(context: context, config: config, size: CGSize(width: width, height: height))
            }
            
            guard let processedCGImage = context.makeImage() else {
                throw WatermarkError.watermarkImageCreationFailed
            }
            
            let processedImage = NSImage(cgImage: processedCGImage, size: NSSize(width: width, height: height))
            return processedImage
        }.value
    }
    
    // MARK: - 绘制文字水印
    private func watermarkDrawTextWatermark(context: CGContext, config: WatermarkConfig, size: CGSize) async throws {
        let text = config.watermarkText as NSString
        let fontSize = config.watermarkFontSize
        
        // 创建字体
        let font = NSFont(name: config.watermarkFontName, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize, weight: .bold)
        
        // 文字属性
        let textColor = NSColor(config.watermarkTextColor)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]
        
        let textSize = text.size(withAttributes: attributes)
        
        // 保存上下文状态
        context.saveGState()
        
        // 翻转坐标系以匹配 AppKit 的坐标系统
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        if config.watermarkPosition == .tile {
            // 平铺模式
            watermarkDrawTiledText(context: context, text: text, attributes: attributes, textSize: textSize, config: config, canvasSize: size)
        } else {
            // 单个位置
            let position = watermarkCalculatePosition(
                for: config.watermarkPosition,
                contentSize: textSize,
                canvasSize: size,
                offset: CGPoint(x: config.watermarkOffsetX, y: config.watermarkOffsetY)
            )
            
            // 应用旋转
            if config.watermarkRotation != 0 {
                let centerX = position.x + textSize.width / 2
                let centerY = position.y + textSize.height / 2
                
                context.translateBy(x: centerX, y: centerY)
                context.rotate(by: -config.watermarkRotation * .pi / 180) // 注意这里取负值
                context.translateBy(x: -textSize.width / 2, y: -textSize.height / 2)
            } else {
                context.translateBy(x: position.x, y: position.y)
            }
            
            // 创建 NSGraphicsContext 来绘制文字
            let graphicsContext = NSGraphicsContext(cgContext: context, flipped: true)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = graphicsContext
            
            // 绘制文字
            text.draw(at: .zero, withAttributes: attributes)
            
            NSGraphicsContext.restoreGraphicsState()
        }
        
        context.restoreGState()
    }
    
    // MARK: - 平铺文字水印
    private func watermarkDrawTiledText(context: CGContext, text: NSString, attributes: [NSAttributedString.Key: Any], textSize: CGSize, config: WatermarkConfig, canvasSize: CGSize) {
        let spacing = config.watermarkTileSpacing
        let rotation = -config.watermarkRotation * .pi / 180 // 注意取负值
        
        // 计算需要的行列数
        let cols = Int(canvasSize.width / (textSize.width + spacing)) + 2
        let rows = Int(canvasSize.height / (textSize.height + spacing)) + 2
        
        // 创建 NSGraphicsContext
        let graphicsContext = NSGraphicsContext(cgContext: context, flipped: true)
        
        for row in 0..<rows {
            for col in 0..<cols {
                let x = CGFloat(col) * (textSize.width + spacing)
                let y = CGFloat(row) * (textSize.height + spacing)
                
                context.saveGState()
                
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = graphicsContext
                
                if rotation != 0 {
                    context.translateBy(x: x + textSize.width / 2, y: y + textSize.height / 2)
                    context.rotate(by: rotation)
                    context.translateBy(x: -textSize.width / 2, y: -textSize.height / 2)
                } else {
                    context.translateBy(x: x, y: y)
                }
                
                text.draw(at: .zero, withAttributes: attributes)
                
                NSGraphicsContext.restoreGraphicsState()
                context.restoreGState()
            }
        }
    }
    
    // MARK: - 绘制图片水印
    private func watermarkDrawImageWatermark(context: CGContext, config: WatermarkConfig, size: CGSize) async throws {
        guard let imageData = config.watermarkImageData,
              let watermarkNSImage = NSImage(data: imageData),
              let watermarkCGImage = watermarkNSImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw WatermarkError.watermarkImageLoadFailed
        }
        
        let originalSize = CGSize(width: watermarkCGImage.width, height: watermarkCGImage.height)
        let scaledSize = CGSize(
            width: originalSize.width * config.watermarkImageScale,
            height: originalSize.height * config.watermarkImageScale
        )
        
        if config.watermarkPosition == .tile {
            // 平铺模式
            watermarkDrawTiledImage(context: context, image: watermarkCGImage, imageSize: scaledSize, config: config, canvasSize: size)
        } else {
            // 单个位置
            let position = watermarkCalculatePosition(
                for: config.watermarkPosition,
                contentSize: scaledSize,
                canvasSize: size,
                offset: CGPoint(x: config.watermarkOffsetX, y: config.watermarkOffsetY)
            )
            
            let rect = CGRect(x: position.x, y: position.y, width: scaledSize.width, height: scaledSize.height)
            context.draw(watermarkCGImage, in: rect)
        }
    }
    
    // MARK: - 平铺图片水印
    private func watermarkDrawTiledImage(context: CGContext, image: CGImage, imageSize: CGSize, config: WatermarkConfig, canvasSize: CGSize) {
        let spacing = config.watermarkTileSpacing
        
        let cols = Int(canvasSize.width / (imageSize.width + spacing)) + 2
        let rows = Int(canvasSize.height / (imageSize.height + spacing)) + 2
        
        for row in 0..<rows {
            for col in 0..<cols {
                let x = CGFloat(col) * (imageSize.width + spacing)
                let y = CGFloat(row) * (imageSize.height + spacing)
                
                let rect = CGRect(x: x, y: y, width: imageSize.width, height: imageSize.height)
                context.draw(image, in: rect)
            }
        }
    }
    
    // MARK: - 计算水印位置
    private func watermarkCalculatePosition(for position: WatermarkPosition, contentSize: CGSize, canvasSize: CGSize, offset: CGPoint) -> CGPoint {
        switch position {
        case .topLeft:
            return CGPoint(x: offset.x, y: canvasSize.height - contentSize.height - offset.y)
        case .topCenter:
            return CGPoint(x: (canvasSize.width - contentSize.width) / 2, y: canvasSize.height - contentSize.height - offset.y)
        case .topRight:
            return CGPoint(x: canvasSize.width - contentSize.width - offset.x, y: canvasSize.height - contentSize.height - offset.y)
        case .centerLeft:
            return CGPoint(x: offset.x, y: (canvasSize.height - contentSize.height) / 2)
        case .center:
            return CGPoint(x: (canvasSize.width - contentSize.width) / 2, y: (canvasSize.height - contentSize.height) / 2)
        case .centerRight:
            return CGPoint(x: canvasSize.width - contentSize.width - offset.x, y: (canvasSize.height - contentSize.height) / 2)
        case .bottomLeft:
            return CGPoint(x: offset.x, y: offset.y)
        case .bottomCenter:
            return CGPoint(x: (canvasSize.width - contentSize.width) / 2, y: offset.y)
        case .bottomRight:
            return CGPoint(x: canvasSize.width - contentSize.width - offset.x, y: offset.y)
        case .tile:
            return .zero
        }
    }
    
    // MARK: - 导出单张图片
    func watermarkExportSingle(item: WatermarkImageItem) {
        guard let processedImage = item.watermarkProcessedImage else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.nameFieldStringValue = "watermarked_\(item.watermarkFileName)"
        panel.message = "选择保存位置"
        
        if panel.runModal() == .OK, let url = panel.url {
            watermarkSaveImage(processedImage, to: url)
        }
    }
    
    // MARK: - 导出全部
    func watermarkExportAll() {
        let processedImages = watermarkImages.filter { $0.watermarkProcessedImage != nil }
        guard !processedImages.isEmpty else { return }
        
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = "选择导出文件夹"
        
        if panel.runModal() == .OK, let directory = panel.url {
            for item in processedImages {
                guard let processedImage = item.watermarkProcessedImage else { continue }
                
                let fileName = "watermarked_\(item.watermarkFileName)"
                let fileURL = directory.appendingPathComponent(fileName)
                
                watermarkSaveImage(processedImage, to: fileURL)
            }
            
            // 显示成功提示
            DispatchQueue.main.async {
                self.watermarkShowSuccessNotification(count: processedImages.count)
            }
        }
    }
    
    // MARK: - 保存图片
    private func watermarkSaveImage(_ image: NSImage, to url: URL) {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            watermarkErrorMessage = "图片转换失败"
            return
        }
        
        let fileType: NSBitmapImageRep.FileType = url.pathExtension.lowercased() == "png" ? .png : .jpeg
        let properties: [NSBitmapImageRep.PropertyKey: Any] = fileType == .jpeg ? [.compressionFactor: 0.9] : [:]
        
        guard let imageData = bitmapImage.representation(using: fileType, properties: properties) else {
            watermarkErrorMessage = "图片数据生成失败"
            return
        }
        
        do {
            try imageData.write(to: url)
        } catch {
            watermarkErrorMessage = "保存失败: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 检查是否有已处理的图片
    func watermarkHasProcessedImages() -> Bool {
        return watermarkImages.contains { $0.watermarkProcessedImage != nil }
    }
    
    // MARK: - 显示成功通知
    private func watermarkShowSuccessNotification(count: Int) {
        let notification = NSUserNotification()
        notification.title = "导出成功"
        notification.informativeText = "已成功导出 \(count) 张图片"
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    // MARK: - 批量重新处理
    func watermarkReprocessAll(config: WatermarkConfig) {
        // 清除所有已处理的图片
        for index in watermarkImages.indices {
            watermarkImages[index].watermarkProcessedImage = nil
            watermarkImages[index].watermarkProcessingError = nil
        }
        
        // 重新应用水印
        watermarkApplyWatermark(config: config)
    }
    
    // MARK: - 预设水印样式
    func watermarkApplyPreset(_ preset: WatermarkPreset) -> WatermarkConfig {
        var config = WatermarkConfig()
        
        switch preset {
        case .copyright:
            config.watermarkType = .text
            config.watermarkText = "© 2024 Copyright"
            config.watermarkFontSize = 24
            config.watermarkTextColor = .white
            config.watermarkPosition = .bottomRight
            config.watermarkOpacity = 0.6
            config.watermarkOffsetX = 30
            config.watermarkOffsetY = 30
            
        case .draft:
            config.watermarkType = .text
            config.watermarkText = "DRAFT"
            config.watermarkFontSize = 80
            config.watermarkTextColor = .red
            config.watermarkPosition = .center
            config.watermarkOpacity = 0.3
            config.watermarkRotation = -45
            
        case .confidential:
            config.watermarkType = .text
            config.watermarkText = "CONFIDENTIAL"
            config.watermarkFontSize = 48
            config.watermarkTextColor = .red
            config.watermarkPosition = .tile
            config.watermarkOpacity = 0.15
            config.watermarkRotation = -30
            config.watermarkTileSpacing = 200
        }
        
        return config
    }
}

// MARK: - 水印预设
enum WatermarkPreset {
    case copyright
    case draft
    case confidential
}

// MARK: - 水印错误类型
enum WatermarkError: LocalizedError {
    case watermarkImageProcessingFailed
    case watermarkContextCreationFailed
    case watermarkImageCreationFailed
    case watermarkFontCreationFailed
    case watermarkImageLoadFailed
    
    var errorDescription: String? {
        switch self {
        case .watermarkImageProcessingFailed:
            return "图片处理失败"
        case .watermarkContextCreationFailed:
            return "创建绘图环境失败"
        case .watermarkImageCreationFailed:
            return "生成图片失败"
        case .watermarkFontCreationFailed:
            return "字体加载失败"
        case .watermarkImageLoadFailed:
            return "水印图片加载失败"
        }
    }
}

// MARK: - NSImage 扩展
extension NSImage {
    var watermarkPNGData: Data? {
        guard let tiffData = self.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            return nil
        }
        return pngData
    }
    
    var watermarkJPEGData: Data? {
        guard let tiffData = self.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) else {
            return nil
        }
        return jpegData
    }
}
