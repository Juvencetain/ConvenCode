import SwiftUI
import Combine
import PDFKit
internal import UniformTypeIdentifiers

// MARK: - PDF 转图片视图模型
class PDFToImageViewModel: ObservableObject {
    
    // MARK: - 图片格式枚举
    enum PDFToImageFormat: String, CaseIterable {
        case png = "PNG"
        case jpeg = "JPEG"
        case tiff = "TIFF"
        
        var pdfToImageFileExtension: String {
            switch self {
            case .png: return "png"
            case .jpeg: return "jpg"
            case .tiff: return "tiff"
            }
        }
        
        var pdfToImageUTType: UTType {
            switch self {
            case .png: return .png
            case .jpeg: return .jpeg
            case .tiff: return .tiff
            }
        }
    }
    
    // MARK: - 转换质量枚举
    enum PDFToImageQuality: String, CaseIterable {
        case low = "低质量 (72 DPI)"
        case medium = "中等质量 (150 DPI)"
        case high = "高质量 (300 DPI)"
        case veryHigh = "超高质量 (600 DPI)"
        
        var pdfToImageDPI: CGFloat {
            switch self {
            case .low: return 72
            case .medium: return 150
            case .high: return 300
            case .veryHigh: return 600
            }
        }
        
        var pdfToImageScale: CGFloat {
            return pdfToImageDPI / 72.0
        }
    }
    
    // MARK: - 页面范围枚举
    enum PDFToImagePageRange: String, CaseIterable {
        case all = "所有页面"
        case current = "当前页面"
        case custom = "自定义范围"
    }
    
    // MARK: - Published Properties
    @Published var pdfToImageDocuments: [(url: URL, document: PDFDocument)] = []
    @Published var pdfToImageSelectedDocIndex: Int = 0
    @Published var pdfToImageSelectedFormat: PDFToImageFormat = .png
    @Published var pdfToImageSelectedQuality: PDFToImageQuality = .high
    @Published var pdfToImagePageRangeOption: PDFToImagePageRange = .all
    @Published var pdfToImageCustomStartPage: String = "1"
    @Published var pdfToImageCustomEndPage: String = "1"
    @Published var pdfToImageIsConverting: Bool = false
    @Published var pdfToImageProgress: Double = 0
    @Published var pdfToImageCurrentFileProgress: String = ""
    @Published var pdfToImageAlertMessage: String = ""
    @Published var pdfToImageShowAlert: Bool = false
    @Published var pdfToImageJPEGQuality: Double = 0.9
    @Published var pdfToImageCurrentPage: Int = 0
    
    // MARK: - Computed Properties
    var pdfToImageTotalPages: Int {
        guard !pdfToImageDocuments.isEmpty, pdfToImageSelectedDocIndex < pdfToImageDocuments.count else {
            return 0
        }
        return pdfToImageDocuments[pdfToImageSelectedDocIndex].document.pageCount
    }
    
    var pdfToImageCurrentPageObject: PDFPage? {
        guard !pdfToImageDocuments.isEmpty, pdfToImageSelectedDocIndex < pdfToImageDocuments.count else {
            return nil
        }
        return pdfToImageDocuments[pdfToImageSelectedDocIndex].document.page(at: pdfToImageCurrentPage)
    }
    
    var pdfToImageFileName: String {
        if pdfToImageDocuments.isEmpty {
            return "未选择文件"
        }
        if pdfToImageDocuments.count == 1 {
            return pdfToImageDocuments[0].url.lastPathComponent
        }
        return "已选择 \(pdfToImageDocuments.count) 个文件"
    }
    
    var pdfToImageCurrentDocument: PDFDocument? {
        guard !pdfToImageDocuments.isEmpty, pdfToImageSelectedDocIndex < pdfToImageDocuments.count else {
            return nil
        }
        return pdfToImageDocuments[pdfToImageSelectedDocIndex].document
    }
    
    // MARK: - 选择 PDF 文件
    func pdfToImageSelectFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.pdf]
        panel.message = "选择要转换的 PDF 文件（可多选）"
        
        if panel.runModal() == .OK {
            var newDocuments: [(url: URL, document: PDFDocument)] = []
            
            for url in panel.urls {
                if let document = PDFDocument(url: url) {
                    newDocuments.append((url: url, document: document))
                }
            }
            
            if !newDocuments.isEmpty {
                DispatchQueue.main.async {
                    self.pdfToImageDocuments = newDocuments
                    self.pdfToImageSelectedDocIndex = 0
                    self.pdfToImageCurrentPage = 0
                    if let firstDoc = newDocuments.first {
                        self.pdfToImageCustomEndPage = "\(firstDoc.document.pageCount)"
                    }
                }
            } else {
                pdfToImageShowError("无法打开所选的 PDF 文件")
            }
        }
    }
    
    // MARK: - 移除文件
    func pdfToImageRemoveFile(at index: Int) {
        guard index < pdfToImageDocuments.count else { return }
        pdfToImageDocuments.remove(at: index)
        
        if pdfToImageDocuments.isEmpty {
            pdfToImageSelectedDocIndex = 0
            pdfToImageCurrentPage = 0
        } else if pdfToImageSelectedDocIndex >= pdfToImageDocuments.count {
            pdfToImageSelectedDocIndex = pdfToImageDocuments.count - 1
            pdfToImageCurrentPage = 0
        }
    }
    
    // MARK: - 切换文档
    func pdfToImageSelectDocument(at index: Int) {
        guard index < pdfToImageDocuments.count else { return }
        pdfToImageSelectedDocIndex = index
        pdfToImageCurrentPage = 0
        pdfToImageCustomEndPage = "\(pdfToImageDocuments[index].document.pageCount)"
    }
    
    // MARK: - 开始转换
    func pdfToImageStartConversion() {
        guard !pdfToImageDocuments.isEmpty else {
            pdfToImageShowError("请先选择 PDF 文件")
            return
        }
        
        // 使用目录选择面板
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.message = "选择图片保存文件夹"
        openPanel.prompt = "选择"
        
        if openPanel.runModal() == .OK, let selectedFolder = openPanel.url {
            pdfToImageIsConverting = true
            pdfToImageProgress = 0
            pdfToImageCurrentFileProgress = ""
            
            DispatchQueue.global(qos: .userInitiated).async {
                self.pdfToImageConvertAllDocuments(to: selectedFolder)
            }
        }
    }
    
    // MARK: - 转换所有文档
    private func pdfToImageConvertAllDocuments(to baseFolder: URL) {
        let totalFiles = pdfToImageDocuments.count
        var successFiles = 0
        var totalPagesConverted = 0
        
        for (fileIndex, docInfo) in pdfToImageDocuments.enumerated() {
            let document = docInfo.document
            let url = docInfo.url
            
            // 更新当前文件进度
            DispatchQueue.main.async {
                self.pdfToImageCurrentFileProgress = "正在处理: \(url.lastPathComponent) (\(fileIndex + 1)/\(totalFiles))"
            }
            
            // 创建以PDF文件名命名的子文件夹
            let pdfName = url.deletingPathExtension().lastPathComponent
            let targetFolder = baseFolder.appendingPathComponent(pdfName)
            
            // 获取要转换的页面
            let pagesToConvert = pdfToImageGetPagesToConvert(document: document)
            
            if pagesToConvert.isEmpty {
                continue
            }
            
            // 创建目标文件夹
            do {
                try FileManager.default.createDirectory(at: targetFolder, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("无法创建文件夹 \(targetFolder.path): \(error)")
                continue
            }
            
            // 转换页面
            var fileSuccess = true
            for (pageLocalIndex, pageIndex) in pagesToConvert.enumerated() {
                guard let page = document.page(at: pageIndex) else { continue }
                
                let fileName = "page_\(pageIndex + 1).\(pdfToImageSelectedFormat.pdfToImageFileExtension)"
                let fileURL = targetFolder.appendingPathComponent(fileName)
                
                if pdfToImageSavePage(page, to: fileURL) {
                    totalPagesConverted += 1
                } else {
                    fileSuccess = false
                }
                
                // 更新总进度
                let currentProgress = Double(fileIndex) / Double(totalFiles) +
                                    (Double(pageLocalIndex + 1) / Double(pagesToConvert.count)) / Double(totalFiles)
                DispatchQueue.main.async {
                    self.pdfToImageProgress = currentProgress
                }
            }
            
            if fileSuccess {
                successFiles += 1
            }
        }
        
        DispatchQueue.main.async {
            self.pdfToImageIsConverting = false
            self.pdfToImageProgress = 0
            self.pdfToImageCurrentFileProgress = ""
            
            if successFiles == totalFiles {
                self.pdfToImageShowSuccess("成功转换 \(totalFiles) 个PDF文件，共 \(totalPagesConverted) 个页面\n保存位置:\n\(baseFolder.path)")
                // 打开保存文件夹
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: baseFolder.path)
            } else {
                self.pdfToImageShowError("转换完成，成功 \(successFiles)/\(totalFiles) 个文件")
            }
        }
    }
    
    // MARK: - 获取要转换的页面
    private func pdfToImageGetPagesToConvert(document: PDFDocument) -> [Int] {
        let totalPages = document.pageCount
        
        switch pdfToImagePageRangeOption {
        case .all:
            return Array(0..<totalPages)
            
        case .current:
            // 对于多文件，当前页面只对当前选中的文档有效
            if pdfToImageDocuments.count == 1 {
                return [pdfToImageCurrentPage]
            } else {
                // 多文件模式下，"当前页面"转换所有文件的所有页面
                return Array(0..<totalPages)
            }
            
        case .custom:
            guard let start = Int(pdfToImageCustomStartPage),
                  let end = Int(pdfToImageCustomEndPage),
                  start >= 1, end >= start, end <= totalPages else {
                return []
            }
            return Array((start - 1)..<end)
        }
    }
    
    // MARK: - 保存页面为图片
    private func pdfToImageSavePage(_ page: PDFPage, to url: URL) -> Bool {
        let bounds = page.bounds(for: .mediaBox)
        let scale = pdfToImageSelectedQuality.pdfToImageScale
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        
        guard let image = pdfToImageRenderPage(page, size: size) else {
            return false
        }
        
        return pdfToImageSaveImage(image, to: url)
    }
    
    // MARK: - 渲染 PDF 页面为图片
    private func pdfToImageRenderPage(_ page: PDFPage, size: CGSize) -> NSImage? {
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return nil
        }
        
        // 设置白色背景
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        // 保存图形状态
        context.saveGState()
        
        // 计算缩放比例
        let bounds = page.bounds(for: .mediaBox)
        let scaleX = size.width / bounds.width
        let scaleY = size.height / bounds.height
        
        // 应用变换以正确渲染 PDF
        context.scaleBy(x: scaleX, y: scaleY)
        
        // 渲染 PDF 页面
        page.draw(with: .mediaBox, to: context)
        
        context.restoreGState()
        
        image.unlockFocus()
        
        return image
    }
    
    // MARK: - 保存图片到文件
    private func pdfToImageSaveImage(_ image: NSImage, to url: URL) -> Bool {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return false
        }
        
        var imageData: Data?
        
        switch pdfToImageSelectedFormat {
        case .png:
            imageData = bitmap.representation(using: .png, properties: [:])
            
        case .jpeg:
            let properties: [NSBitmapImageRep.PropertyKey: Any] = [
                .compressionFactor: pdfToImageJPEGQuality
            ]
            imageData = bitmap.representation(using: .jpeg, properties: properties)
            
        case .tiff:
            imageData = bitmap.representation(using: .tiff, properties: [:])
        }
        
        guard let data = imageData else {
            return false
        }
        
        do {
            try data.write(to: url)
            return true
        } catch {
            print("保存图片失败: \(error)")
            return false
        }
    }
    
    // MARK: - 显示错误
    private func pdfToImageShowError(_ message: String) {
        DispatchQueue.main.async {
            self.pdfToImageAlertMessage = message
            self.pdfToImageShowAlert = true
        }
    }
    
    // MARK: - 显示成功
    private func pdfToImageShowSuccess(_ message: String) {
        DispatchQueue.main.async {
            self.pdfToImageAlertMessage = message
            self.pdfToImageShowAlert = true
        }
    }
    
    // MARK: - 页面导航
    func pdfToImageGoToNextPage() {
        if pdfToImageCurrentPage < pdfToImageTotalPages - 1 {
            pdfToImageCurrentPage += 1
        }
    }
    
    func pdfToImageGoToPreviousPage() {
        if pdfToImageCurrentPage > 0 {
            pdfToImageCurrentPage -= 1
        }
    }
    
    func pdfToImageGoToFirstPage() {
        pdfToImageCurrentPage = 0
    }
    
    func pdfToImageGoToLastPage() {
        pdfToImageCurrentPage = max(0, pdfToImageTotalPages - 1)
    }
}
