import SwiftUI
internal import UniformTypeIdentifiers
import Combine

// MARK: - Tool-Specific Enums
enum QRCodeToolCorrectionLevel: String, CaseIterable, Identifiable {
    case L = "低 (L)"
    case M = "中 (M)"
    case Q = "较高 (Q)"
    case H = "高 (H)"
    
    var id: String { self.rawValue }
    
    var filterValue: String {
        switch self {
        case .L: return "L"
        case .M: return "M"
        case .Q: return "Q"
        case .H: return "H"
        }
    }
}


// MARK: - QR Code Tool ViewModel

class QRCodeToolViewModel: ObservableObject {
    
    // MARK: - Published Properties for UI Binding
    
    @Published var qrCodeToolInputText: String = ""
    @Published var qrCodeToolGeneratedImage: NSImage?
    @Published var qrCodeToolCorrectionLevel: QRCodeToolCorrectionLevel = .M
    
    @Published var qrCodeToolSelectedImageForReading: NSImage?
    @Published var qrCodeToolDetectedText: String?
    
    @Published var qrCodeToolIsProcessing: Bool = false
    @Published var qrCodeToolStatusMessage: (text: String, isError: Bool)?
    
    private var qrCodeToolStatusTimer: Timer?
    private var qrCodeToolGenerationWorkItem: DispatchWorkItem?

    // MARK: - Public Methods for Generation
    
    /// Schedules a QR code generation task with a debounce mechanism.
    func qrCodeToolScheduleGeneration() {
        qrCodeToolGenerationWorkItem?.cancel()
        
        let task = DispatchWorkItem { [weak self] in
            self?.qrCodeToolGenerate()
        }
        
        qrCodeToolGenerationWorkItem = task
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300), execute: task)
    }
    
    /// Generates a QR code image using a backward-compatible method.
    private func qrCodeToolGenerate() {
        guard !qrCodeToolInputText.isEmpty else {
            DispatchQueue.main.async {
                self.qrCodeToolGeneratedImage = nil
            }
            return
        }
        
        DispatchQueue.main.async {
            self.qrCodeToolIsProcessing = true
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let context = CIContext()
            
            // --- FIXED: Use the compatible CIFilter initializer ---
            guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
                DispatchQueue.main.async {
                    self.qrCodeToolShowStatus("无法创建二维码滤镜", isError: true)
                    self.qrCodeToolIsProcessing = false
                }
                return
            }
            
            // Set filter parameters using KVC
            filter.setValue(Data(self.qrCodeToolInputText.utf8), forKey: "inputMessage")
            filter.setValue(self.qrCodeToolCorrectionLevel.filterValue, forKey: "inputCorrectionLevel")
            // --- END OF FIX ---
            
            guard let outputImage = filter.outputImage else {
                DispatchQueue.main.async {
                    self.qrCodeToolShowStatus("生成二维码失败", isError: true)
                    self.qrCodeToolIsProcessing = false
                }
                return
            }
            
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)
            
            guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
                DispatchQueue.main.async {
                    self.qrCodeToolShowStatus("无法渲染二维码图片", isError: true)
                    self.qrCodeToolIsProcessing = false
                }
                return
            }
            
            let nsImage = NSImage(cgImage: cgImage, size: scaledImage.extent.size)
            
            DispatchQueue.main.async {
                self.qrCodeToolGeneratedImage = nsImage
                self.qrCodeToolIsProcessing = false
            }
        }
    }
    
    /// Opens a save panel to save the generated QR code image.
    func qrCodeToolSaveGeneratedImage() {
        guard let image = qrCodeToolGeneratedImage else {
            qrCodeToolShowStatus("没有可保存的二维码", isError: true)
            return
        }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "QRCode.png"

        if savePanel.runModal() == .OK, let url = savePanel.url {
            guard let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else {
                qrCodeToolShowStatus("无法转换图片格式", isError: true)
                return
            }
            
            do {
                try pngData.write(to: url)
                qrCodeToolShowStatus("保存成功", isError: false)
            } catch {
                qrCodeToolShowStatus("保存失败: \(error.localizedDescription)", isError: true)
            }
        }
    }
    
    // MARK: - Public Methods for Reading
    
    func qrCodeToolSelectImageForReading() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.image]
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            qrCodeToolProcessImage(from: url)
        }
    }
    
    func qrCodeToolProcessImage(from url: URL) {
        guard let image = NSImage(contentsOf: url) else {
            qrCodeToolShowStatus("无法加载图片", isError: true)
            return
        }
        qrCodeToolDetect(from: image)
    }

    func qrCodeToolDetect(from image: NSImage) {
        DispatchQueue.main.async {
            self.qrCodeToolIsProcessing = true
            self.qrCodeToolSelectedImageForReading = image
            self.qrCodeToolDetectedText = nil
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                DispatchQueue.main.async {
                    self.qrCodeToolShowStatus("无法转换图片进行识别", isError: true)
                    self.qrCodeToolIsProcessing = false
                }
                return
            }
            
            let ciImage = CIImage(cgImage: cgImage)
            let context = CIContext()
            let options = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
            guard let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: context, options: options) else {
                DispatchQueue.main.async {
                    self.qrCodeToolIsProcessing = false
                }
                return
            }
            
            let features = detector.features(in: ciImage)
            
            if let qrCodeFeature = features.first as? CIQRCodeFeature, let message = qrCodeFeature.messageString {
                DispatchQueue.main.async {
                    self.qrCodeToolDetectedText = message
                    self.qrCodeToolShowStatus("识别成功！", isError: false)
                }
            } else {
                DispatchQueue.main.async {
                    self.qrCodeToolShowStatus("未识别到二维码", isError: true)
                }
            }
            
            DispatchQueue.main.async {
                self.qrCodeToolIsProcessing = false
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func qrCodeToolShowStatus(_ message: String, isError: Bool) {
        qrCodeToolStatusMessage = (text: message, isError: isError)
        qrCodeToolStatusTimer?.invalidate()
        qrCodeToolStatusTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            self.qrCodeToolStatusMessage = nil
        }
    }
}

