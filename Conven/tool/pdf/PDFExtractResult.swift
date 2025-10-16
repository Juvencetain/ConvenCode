import Foundation
import PDFKit
import Vision

// MARK: - Data Structure
/// 用于存储从单个PDF中提取的数据和文件名
struct PDFExtractResult {
    let fileName: String
    let content: String
}

/// 用于表示最终表格中的一行数据
struct CSVRow {
    var columns: [String]
}

// MARK: - PDF Extractor Logic
class PDFExtractorLogic {

    /// 异步处理多个PDF文件
    /// - Parameter urls: 用户选择的PDF文件的URL数组
    /// - Returns: 一个包含每个文件提取结果的数组
    func processPDFs(urls: [URL]) async -> [PDFExtractResult] {
        var results: [PDFExtractResult] = []
        for url in urls {
            let fileName = url.lastPathComponent
            let text = await extractText(from: url)
            results.append(PDFExtractResult(fileName: fileName, content: text))
        }
        return results
    }

    /// 从单个PDF URL中提取文本（混合策略）
    /// - Parameter url: PDF文件的URL
    /// - Returns: 提取出的文本字符串
    private func extractText(from url: URL) async -> String {
        guard let pdfDocument = PDFDocument(url: url) else {
            return "无法打开PDF文件。"
        }

        var fullText = ""

        for i in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: i) else { continue }

            // 策略1：优先使用PDFKit直接提取文本（快速、准确）
            if let text = page.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                fullText += text + "\n\n--- Page \(i+1) ---\n\n"
                continue
            }

            // 策略2：如果无法直接提取文本（如扫描件），则使用Vision OCR
            // 将PDF页面渲染为图像
            let pageRect = page.bounds(for: .mediaBox)
            let image = NSImage(size: pageRect.size, flipped: false) { (rect) -> Bool in
                guard let context = NSGraphicsContext.current?.cgContext else { return false }
                context.setFillColor(NSColor.white.cgColor)
                context.fill(rect)
                page.draw(with: .mediaBox, to: context)
                return true
            }

            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }

            let textFromImage = await performOCR(on: cgImage)
            fullText += textFromImage + "\n\n--- Page \(i+1) (OCR) ---\n\n"
        }

        return fullText
    }

    /// 执行OCR识别
    private func performOCR(on image: CGImage) async -> String {
        let requestHandler = VNImageRequestHandler(cgImage: image)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "en-US"] // 支持中英文

        return await withCheckedContinuation { continuation in
            do {
                try requestHandler.perform([request])
                guard let observations = request.results else {
                    continuation.resume(returning: "")
                    return
                }
                let recognizedText = observations.compactMap {
                    $0.topCandidates(1).first?.string
                }.joined(separator: "\n")
                continuation.resume(returning: recognizedText)
            } catch {
                continuation.resume(returning: "OCR识别失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 将提取结果转换为CSV字符串（通用模板）
    /// - Parameter results: 提取结果数组
    /// - Returns: CSV格式的字符串
    func convertToCSV(results: [PDFExtractResult]) -> String {
        // 简易的发票关键词识别
        let invoiceKeywords: [String: [String]] = [
            "发票代码": ["发票代码"],
            "发票号码": ["发票号码"],
            "开票日期": ["开票日期"],
            "金额": ["合计", "金额", "价税合计", "小写"],
            "购买方": ["购买方", "名称"]
        ]

        var rows: [CSVRow] = []
        // 添加表头
        let headers = ["文件名", "发票代码", "发票号码", "开票日期", "金额", "购买方", "原始文本"]
        rows.append(CSVRow(columns: headers))

        for result in results {
            var rowData = [String: String]()
            rowData["文件名"] = result.fileName
            rowData["原始文本"] = result.content

            let lines = result.content.components(separatedBy: .newlines)
            for line in lines {
                for (header, keywords) in invoiceKeywords {
                    // 如果这一行已经找到数据，则跳过
                    if rowData[header] != nil { continue }
                    
                    for keyword in keywords {
                        if let range = line.range(of: keyword) {
                            var value = String(line[range.upperBound...])
                            // 清理常见的前缀和后缀
                            value = value.replacingOccurrences(of: "：", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                            rowData[header] = value
                            break // 找到一个关键词就跳出
                        }
                    }
                }
            }
            
            // 按照表头顺序构建行
            var columns = [String]()
            for header in headers {
                columns.append(rowData[header] ?? "")
            }
            rows.append(CSVRow(columns: columns))
        }
        
        // 拼接CSV字符串
        return rows.map { row in
            row.columns.map { field in
                // 为确保CSV格式正确，对包含逗号或引号的字段进行处理
                let sanitized = field.replacingOccurrences(of: "\"", with: "\"\"")
                if sanitized.contains(",") || sanitized.contains("\"") || sanitized.contains("\n") {
                    return "\"\(sanitized)\""
                }
                return sanitized
            }.joined(separator: ",")
        }.joined(separator: "\n")
    }
}