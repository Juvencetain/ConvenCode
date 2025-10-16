import SwiftUI
import AppKit
internal import UniformTypeIdentifiers
import Combine

// MARK: - ViewModel
@MainActor
class ImageToolsViewModel: ObservableObject {
    // MARK: - State
    @Published private(set) var originalImage: NSImage?
    @Published private(set) var processedImage: NSImage?
    @Published var compressionQuality: Double = 0.7
    @Published var isCropping = false
    @Published var cropSelection: CGRect?
    @Published private(set) var errorMessage: String?
    @Published private(set) var toastMessage = ""
    @Published private(set) var showSuccessToast = false
    @Published private(set) var imageFrame: CGRect = .zero
    
    // MARK: - Computed Properties
    var hasImage: Bool {
        originalImage != nil
    }
    
    var displayImage: NSImage? {
        processedImage ?? originalImage
    }
    
    var imageInfo: ImageInfo? {
        guard let image = displayImage else { return nil }
        return ImageInfo(image: image, compressionQuality: compressionQuality)
    }
    
    // MARK: - Public Methods
    func selectImageFromPanel() {
        let imagePanel = NSOpenPanel()
        imagePanel.allowedContentTypes = [.image]
        imagePanel.allowsMultipleSelection = false
        imagePanel.message = "选择要处理的图片"
        
        if imagePanel.runModal() == .OK, let imageURL = imagePanel.url {
            loadImageFromURL(imageURL)
        }
    }
    
    func handleImageDrop(providers: [NSItemProvider]) -> Bool {
        guard let imageProvider = providers.first else { return false }
        
        imageProvider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, _ in
            guard let imageData = item as? Data,
                  let imageURL = URL(dataRepresentation: imageData, relativeTo: nil) else { return }
            
            Task { @MainActor [weak self] in
                self?.loadImageFromURL(imageURL)
            }
        }
        
        return true
    }
    
    func compressImage() {
        guard let imageToCompress = originalImage else { return }
        
        do {
            let compressedImage = try ImageProcessor.compressImage(
                imageToCompress,
                quality: compressionQuality
            )
            processedImage = compressedImage
            showSuccessMessage("压缩已应用")
        } catch {
            showErrorMessage("压缩失败: \(error.localizedDescription)")
        }
    }
    
    func convertImageFormat(to format: ImageFormat) {
        guard let imageToConvert = displayImage else { return }
        
        do {
            let convertedImage = try ImageProcessor.convertImage(
                imageToConvert,
                to: format,
                quality: compressionQuality
            )
            processedImage = convertedImage
            showSuccessMessage("已转换为 \(format.displayName)")
        } catch {
            showErrorMessage("格式转换失败")
        }
    }
    
    func startImageCropping() {
        isCropping = true
        cropSelection = nil
    }
    
    func applyImageCrop() {
        guard let imageToCrop = displayImage,
              let cropRect = cropSelection,
              !cropRect.isEmpty else {
            showErrorMessage("请先选择裁切区域")
            return
        }
        
        do {
            let croppedImage = try ImageProcessor.cropImage(
                imageToCrop,
                rect: cropRect,
                imageFrame: imageFrame
            )
            
            processedImage = croppedImage
            originalImage = croppedImage
            cancelImageCrop()
            showSuccessMessage("裁切成功")
        } catch {
            showErrorMessage("裁切失败")
        }
    }
    
    func cancelImageCrop() {
        isCropping = false
        cropSelection = nil
    }
    
    func saveImageDirectly(as format: ImageFormat) {
        guard let imageToSave = displayImage else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [format.utType]
        savePanel.nameFieldStringValue = "image-\(Date().timeIntervalSince1970).\(format.fileExtension)"
        savePanel.message = "保存为 \(format.displayName) 格式"
        
        guard savePanel.runModal() == .OK, let saveURL = savePanel.url else { return }
        
        do {
            try ImageExporter.exportImage(
                imageToSave,
                to: saveURL,
                format: format,
                quality: compressionQuality
            )
            showSuccessMessage("已保存为 \(format.displayName)")
        } catch {
            showErrorMessage("保存失败: \(error.localizedDescription)")
        }
    }
    
    func resetImage() {
        originalImage = nil
        resetProcessingImageState()
    }
    
    func cleanup() {
        resetImage()
    }
    
    func clearImageError() {
        errorMessage = nil
    }
    
    func updateImageFrameRect(_ frame: CGRect) {
        imageFrame = frame
    }
    
    // MARK: - Private Methods
    private func loadImageFromURL(_ url: URL) {
        guard let loadedImage = NSImage(contentsOf: url) else {
            showErrorMessage("无法加载图片文件")
            return
        }
        
        originalImage = loadedImage
        resetProcessingImageState()
    }
    
    private func resetProcessingImageState() {
        processedImage = nil
        errorMessage = nil
        isCropping = false
        cropSelection = nil
        compressionQuality = 0.7
    }
    
    private func showErrorMessage(_ message: String) {
        errorMessage = message
    }
    
    private func showSuccessMessage(_ message: String) {
        toastMessage = message
        showSuccessToast = true
        
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                withAnimation(.easeOut) {
                    showSuccessToast = false
                }
            }
        }
    }
}

// MARK: - Models
struct ImageInfo {
    let width: Int
    let height: Int
    let estimatedSize: String
    
    init(image: NSImage, compressionQuality: Double) {
        self.width = Int(image.size.width)
        self.height = Int(image.size.height)
        self.estimatedSize = Self.calculateImageSize(for: image, quality: compressionQuality)
    }
    
    private static func calculateImageSize(for image: NSImage, quality: Double) -> String {
        guard let imageTiffData = image.tiffRepresentation,
              let imageBitmap = NSBitmapImageRep(data: imageTiffData),
              let jpegImageData = imageBitmap.representation(
                using: .jpeg,
                properties: [.compressionFactor: quality]
              ) else {
            return "未知"
        }
        
        return ByteCountFormatter.string(
            fromByteCount: Int64(jpegImageData.count),
            countStyle: .file
        )
    }
}

enum ImageFormat: String, CaseIterable, Identifiable {
    case jpeg = "JPEG"
    case png = "PNG"
    case tiff = "TIFF"
    case heic = "HEIC"
    case webp = "WebP"
    case gif = "GIF"
    case bmp = "BMP"
    
    var id: String { rawValue }
    var displayName: String { rawValue }
    
    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .png: return "png"
        case .tiff: return "tiff"
        case .heic: return "heic"
        case .webp: return "webp"
        case .gif: return "gif"
        case .bmp: return "bmp"
        }
    }
    
    var utType: UTType {
        switch self {
        case .jpeg: return .jpeg
        case .png: return .png
        case .tiff: return .tiff
        case .heic: return .heic
        case .webp: return .webP
        case .gif: return .gif
        case .bmp: return .bmp
        }
    }
    
    var bitmapFormat: NSBitmapImageRep.FileType {
        switch self {
        case .jpeg: return .jpeg
        case .png: return .png
        case .tiff: return .tiff
        case .gif: return .gif
        case .bmp: return .bmp
        case .heic, .webp: return .jpeg
        }
    }
    
    var icon: String {
        switch self {
        case .jpeg: return "photo"
        case .png: return "photo.on.rectangle"
        case .tiff: return "doc.richtext"
        case .heic: return "photo.badge.arrow.down"
        case .webp: return "globe"
        case .gif: return "photo.stack"
        case .bmp: return "photo.fill"
        }
    }
}

// MARK: - Image Processor
enum ImageProcessingError: LocalizedError {
    case invalidImageData
    case imageCompressionFailed
    case imageConversionFailed
    case imageCroppingFailed
    case imageExportFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImageData: return "无效的图片数据"
        case .imageCompressionFailed: return "压缩处理失败"
        case .imageConversionFailed: return "格式转换失败"
        case .imageCroppingFailed: return "裁切操作失败"
        case .imageExportFailed: return "导出文件失败"
        }
    }
}

struct ImageProcessor {
    // MARK: - Compression
    static func compressImage(_ image: NSImage, quality: Double) throws -> NSImage {
        guard let imageTiffData = image.tiffRepresentation,
              let imageBitmap = NSBitmapImageRep(data: imageTiffData) else {
            throw ImageProcessingError.invalidImageData
        }
        
        guard let compressedImageData = imageBitmap.representation(
            using: .jpeg,
            properties: [.compressionFactor: NSNumber(value: quality)]
        ) else {
            throw ImageProcessingError.imageCompressionFailed
        }
        
        guard let resultImage = NSImage(data: compressedImageData) else {
            throw ImageProcessingError.imageCompressionFailed
        }
        
        return resultImage
    }
    
    // MARK: - Format Conversion
    static func convertImage(_ image: NSImage, to format: ImageFormat, quality: Double) throws -> NSImage {
        guard let imageTiffData = image.tiffRepresentation,
              let imageBitmap = NSBitmapImageRep(data: imageTiffData) else {
            throw ImageProcessingError.invalidImageData
        }
        
        let convertedImageData: Data?
        
        switch format {
        case .heic:
            convertedImageData = try convertImageToHEIC(bitmap: imageBitmap, quality: quality)
        case .webp:
            // WebP 需要第三方库，这里使用高质量 JPEG 作为替代
            convertedImageData = imageBitmap.representation(
                using: .jpeg,
                properties: [.compressionFactor: NSNumber(value: quality)]
            )
        default:
            convertedImageData = imageBitmap.representation(
                using: format.bitmapFormat,
                properties: [.compressionFactor: NSNumber(value: quality)]
            )
        }
        
        guard let imageData = convertedImageData,
              let resultImage = NSImage(data: imageData) else {
            throw ImageProcessingError.imageConversionFailed
        }
        
        return resultImage
    }
    
    private static func convertImageToHEIC(bitmap: NSBitmapImageRep, quality: Double) throws -> Data {
        guard let imageCGImage = bitmap.cgImage else {
            throw ImageProcessingError.invalidImageData
        }
        
        let imageData = NSMutableData()
        guard let imageDestination = CGImageDestinationCreateWithData(
            imageData as CFMutableData,
            UTType.heic.identifier as CFString,
            1,
            nil
        ) else {
            throw ImageProcessingError.imageConversionFailed
        }
        
        let imageOptions: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        
        CGImageDestinationAddImage(imageDestination, imageCGImage, imageOptions as CFDictionary)
        
        guard CGImageDestinationFinalize(imageDestination) else {
            throw ImageProcessingError.imageConversionFailed
        }
        
        return imageData as Data
    }
    
    // MARK: - Cropping
    static func cropImage(_ image: NSImage, rect: CGRect, imageFrame: CGRect) throws -> NSImage {
        let imageSize = image.size
        let viewSize = imageFrame.size
        
        // 计算缩放比例
        let imageScaleX = imageSize.width / viewSize.width
        let imageScaleY = imageSize.height / viewSize.height
        
        // 将视图坐标转换为图片坐标
        let imageCropRect = CGRect(
            x: (rect.origin.x - imageFrame.origin.x) * imageScaleX,
            y: (imageSize.height - (rect.origin.y - imageFrame.origin.y + rect.height) * imageScaleY),
            width: rect.width * imageScaleX,
            height: rect.height * imageScaleY
        )
        
        // 验证裁切区域
        guard imageCropRect.width > 0,
              imageCropRect.height > 0,
              imageCropRect.origin.x >= 0,
              imageCropRect.origin.y >= 0,
              imageCropRect.maxX <= imageSize.width,
              imageCropRect.maxY <= imageSize.height else {
            throw ImageProcessingError.imageCroppingFailed
        }
        
        guard let imageCGImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let croppedImageCGImage = imageCGImage.cropping(to: imageCropRect) else {
            throw ImageProcessingError.imageCroppingFailed
        }
        
        return NSImage(cgImage: croppedImageCGImage, size: imageCropRect.size)
    }
}

// MARK: - Image Exporter
struct ImageExporter {
    static func exportImage(
        _ image: NSImage,
        to url: URL,
        format: ImageFormat,
        quality: Double
    ) throws {
        guard let imageTiffData = image.tiffRepresentation,
              let imageBitmap = NSBitmapImageRep(data: imageTiffData) else {
            throw ImageProcessingError.invalidImageData
        }
        
        switch format {
        case .heic:
            try exportImageAsHEIC(bitmap: imageBitmap, to: url, quality: quality)
        case .webp:
            try exportImageAsWebP(bitmap: imageBitmap, to: url, quality: quality)
        default:
            try exportImageAsStandard(bitmap: imageBitmap, to: url, format: format, quality: quality)
        }
    }
    
    private static func exportImageAsHEIC(
        bitmap: NSBitmapImageRep,
        to url: URL,
        quality: Double
    ) throws {
        guard let imageCGImage = bitmap.cgImage,
              let imageDestination = CGImageDestinationCreateWithURL(
                url as CFURL,
                UTType.heic.identifier as CFString,
                1,
                nil
              ) else {
            throw ImageProcessingError.imageExportFailed
        }
        
        let imageOptions: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        
        CGImageDestinationAddImage(imageDestination, imageCGImage, imageOptions as CFDictionary)
        
        guard CGImageDestinationFinalize(imageDestination) else {
            throw ImageProcessingError.imageExportFailed
        }
    }
    
    private static func exportImageAsWebP(
        bitmap: NSBitmapImageRep,
        to url: URL,
        quality: Double
    ) throws {
        // WebP 需要第三方库，使用 JPEG 作为替代
        guard let imageData = bitmap.representation(
            using: .jpeg,
            properties: [.compressionFactor: NSNumber(value: quality)]
        ) else {
            throw ImageProcessingError.imageExportFailed
        }
        
        try imageData.write(to: url)
    }
    
    private static func exportImageAsStandard(
        bitmap: NSBitmapImageRep,
        to url: URL,
        format: ImageFormat,
        quality: Double
    ) throws {
        guard let imageData = bitmap.representation(
            using: format.bitmapFormat,
            properties: [.compressionFactor: NSNumber(value: quality)]
        ) else {
            throw ImageProcessingError.imageExportFailed
        }
        
        try imageData.write(to: url)
    }
}
