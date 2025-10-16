import Foundation
import PDFKit
import Vision
import AppKit
import Accelerate

struct InvoiceData {
    let fileName: String
    var invoiceCode: String = "未识别"
    var invoiceNumber: String = "未识别"
    var issueDate: String = "未识别"
    var buyerName: String = "未识别"
    var buyerTaxId: String = "未识别"
    var sellerName: String = "未识别"
    var sellerTaxId: String = "未识别"
    var totalAmountLower: String = "未识别"
    var totalAmountUpper: String = "未识别"
    var taxAmount: String = "未识别"
    var preTaxAmount: String = "未识别"
    var taxRate: String = "未识别"
    let rawText: String
    
    mutating func validateAndFix() {
        fixDuplicateTaxIds()
        fixInvoiceNumbers()
        validateAndFixTaxRate()
        fixAmountRelationshipsEnhanced()
        fixChineseAmountBidirectional()
        performFinalValidation()
    }
    
    // Enhanced amount relationship fixing with strict rules
    private mutating func fixAmountRelationshipsEnhanced() {
        var total = parseAmount(totalAmountLower)
        var tax = parseAmount(taxAmount)
        var preTax = parseAmount(preTaxAmount)
        var rate = parseTaxRate(taxRate) ?? 0
        
        // Collect all valid amounts
        var amounts = [(value: total, field: "total"), (value: tax, field: "tax"), (value: preTax, field: "preTax")]
            .filter { $0.value > 0.01 }
            .sorted { $0.value < $1.value }
        
        // Rule 1: Enforce tax < preTax < total
        if amounts.count == 3 {
            tax = amounts[0].value
            preTax = amounts[1].value
            total = amounts[2].value
            
            taxAmount = formatAmount(tax)
            preTaxAmount = formatAmount(preTax)
            totalAmountLower = formatAmount(total)
        }
        
        // Try to calculate missing values
        let knownCount = [total > 0.01, tax > 0.01, preTax > 0.01, rate > 0].filter { $0 }.count
        
        if knownCount >= 2 {
            // Case 1: Known total and rate
            if total > 0.01 && rate > 0 {
                let calculatedPreTax = total / (1 + rate / 100.0)
                let calculatedTax = total - calculatedPreTax
                
                if preTax <= 0.01 {
                    preTax = calculatedPreTax
                    preTaxAmount = formatAmount(preTax)
                }
                if tax <= 0.01 {
                    tax = calculatedTax
                    taxAmount = formatAmount(tax)
                }
            }
            // Case 2: Known preTax and rate
            else if preTax > 0.01 && rate > 0 {
                let calculatedTax = preTax * (rate / 100.0)
                let calculatedTotal = preTax + calculatedTax
                
                if tax <= 0.01 {
                    tax = calculatedTax
                    taxAmount = formatAmount(tax)
                }
                if total <= 0.01 {
                    total = calculatedTotal
                    totalAmountLower = formatAmount(total)
                }
            }
            // Case 3: Known preTax and tax
            else if preTax > 0.01 && tax > 0.01 {
                let calculatedTotal = preTax + tax
                if abs(total - calculatedTotal) > 0.02 || total <= 0.01 {
                    total = calculatedTotal
                    totalAmountLower = formatAmount(total)
                }
                
                if rate <= 0 {
                    let calculatedRate = (tax / preTax) * 100
                    rate = findClosestValidRate(calculatedRate)
                    taxRate = formatTaxRate(rate)
                }
            }
        }
        
        // Final validation
        if total > 0.01 && tax > 0.01 && preTax > 0.01 {
            let tolerance = 0.02
            let calculatedTotal = preTax + tax
            
            if abs(total - calculatedTotal) > tolerance {
                total = calculatedTotal
                totalAmountLower = formatAmount(total)
            }
            
            // Ensure tax < preTax < total
            if tax >= preTax || preTax >= total {
                let sortedAmounts = [tax, preTax, total].sorted()
                tax = sortedAmounts[0]
                preTax = sortedAmounts[1]
                total = sortedAmounts[2]
                
                taxAmount = formatAmount(tax)
                preTaxAmount = formatAmount(preTax)
                totalAmountLower = formatAmount(total)
            }
        }
    }
    
    private mutating func validateAndFixTaxRate() {
        let validRates: [Double] = [0, 3, 6, 9, 13]
        
        if taxRate == "未识别" || taxRate.isEmpty {
            let tax = parseAmount(taxAmount)
            let preTax = parseAmount(preTaxAmount)
            
            if tax > 0.01 && preTax > 0.01 {
                let calculatedRate = (tax / preTax) * 100
                let closestRate = findClosestValidRate(calculatedRate)
                taxRate = formatTaxRate(closestRate)
            }
        } else {
            if let currentRate = parseTaxRate(taxRate) {
                if !validRates.contains(currentRate) {
                    let closestRate = findClosestValidRate(currentRate)
                    taxRate = formatTaxRate(closestRate)
                }
            }
        }
    }
    
    private func findClosestValidRate(_ calculatedRate: Double) -> Double {
        let validRates: [Double] = [0, 3, 6, 9, 13]
        var closestRate: Double = 6 // Default to 6%
        var minDiff = Double.infinity
        
        for rate in validRates {
            let diff = abs(calculatedRate - rate)
            if diff < minDiff && diff < 1.0 { // 1% tolerance
                minDiff = diff
                closestRate = rate
            }
        }
        
        return closestRate
    }
    
    private func formatTaxRate(_ rate: Double) -> String {
        return rate == 0 ? "0%" : "\(Int(rate))%"
    }
    
    private mutating func fixDuplicateTaxIds() {
        // Rule 8: Buyer and seller info must be different
        if buyerTaxId == sellerTaxId && buyerTaxId != "未识别" {
            // Use position to determine which is correct
            let buyerScore = calculatePositionScore(for: buyerTaxId, keywords: ["购买方", "购方", "买方"], isLeft: true)
            let sellerScore = calculatePositionScore(for: sellerTaxId, keywords: ["销售方", "销方", "售方", "卖方"], isLeft: false)
            
            if buyerScore > sellerScore {
                sellerTaxId = "未识别"
            } else {
                buyerTaxId = "未识别"
            }
        }
        
        if buyerName == sellerName && buyerName != "未识别" {
            let buyerScore = calculatePositionScore(for: buyerName, keywords: ["购买方", "购方", "买方"], isLeft: true)
            let sellerScore = calculatePositionScore(for: sellerName, keywords: ["销售方", "销方", "售方", "卖方"], isLeft: false)
            
            if buyerScore > sellerScore {
                sellerName = "未识别"
            } else {
                buyerName = "未识别"
            }
        }
    }
    
    private func calculatePositionScore(for value: String, keywords: [String], isLeft: Bool) -> Int {
        guard let range = rawText.range(of: value) else { return 0 }
        
        var score = 0
        let beforeDistance = rawText.distance(from: rawText.startIndex, to: range.lowerBound)
        let contextStart = rawText.index(range.lowerBound, offsetBy: -min(100, beforeDistance))
        let context = String(rawText[contextStart..<range.upperBound])
        
        for keyword in keywords {
            if context.contains(keyword) {
                score += 10
            }
        }
        
        // Rule 2: Left side is buyer, right side is seller
        let position = beforeDistance
        let totalLength = rawText.count
        let relativePosition = Double(position) / Double(totalLength)
        
        if isLeft && relativePosition < 0.5 {
            score += 5
        } else if !isLeft && relativePosition >= 0.5 {
            score += 5
        }
        
        return score
    }
    
    private mutating func fixInvoiceNumbers() {
        // Rule 6: Invoice numbers at top right
        if invoiceCode != "未识别" {
            let cleaned = invoiceCode.filter { $0.isNumber }
            if cleaned.count >= 10 && cleaned.count <= 12 {
                invoiceCode = cleaned
            } else {
                invoiceCode = "未识别"
            }
        }
        
        if invoiceNumber != "未识别" {
            let cleaned = invoiceNumber.filter { $0.isNumber }
            if cleaned.count == 8 {
                invoiceNumber = cleaned
            } else {
                invoiceNumber = "未识别"
            }
        }
    }
    
    private mutating func fixChineseAmountBidirectional() {
        let lowerValue = parseAmount(totalAmountLower)
        let upperValue = parseChineseAmount(totalAmountUpper)
        
        if lowerValue > 0 && totalAmountUpper == "未识别" {
            totalAmountUpper = Self.convertToChineseAmount(totalAmountLower)
        } else if upperValue > 0 && totalAmountLower == "未识别" {
            totalAmountLower = formatAmount(upperValue)
        } else if lowerValue > 0 && upperValue > 0 {
            if abs(lowerValue - upperValue) > 0.01 {
                totalAmountUpper = Self.convertToChineseAmount(totalAmountLower)
            }
        }
    }
    
    private mutating func performFinalValidation() {
        let total = parseAmount(totalAmountLower)
        let tax = parseAmount(taxAmount)
        let preTax = parseAmount(preTaxAmount)
        
        if tax > 0 && preTax > 0 && total > 0 {
            if tax >= preTax || preTax >= total {
                print("警告：\(fileName) 的金额关系异常 - 税额:\(tax) 税前:\(preTax) 合计:\(total)")
            }
        }
    }
    
    // Helper functions
    private func parseAmount(_ amount: String) -> Double {
        guard amount != "未识别" else { return 0 }
        let cleaned = amount.filter { $0.isNumber || $0 == "." }
        return Double(cleaned) ?? 0
    }
    
    private func formatAmount(_ amount: Double) -> String {
        return String(format: "%.2f", amount)
    }
    
    private func parseTaxRate(_ rate: String) -> Double? {
        guard rate != "未识别" else { return nil }
        let cleaned = rate.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
        return Double(cleaned)
    }
    
    private func parseChineseAmount(_ amount: String) -> Double {
        guard amount != "未识别" && !amount.isEmpty else { return 0 }
        
        let digitMap: [Character: Int] = [
            "零": 0, "壹": 1, "贰": 2, "叁": 3, "肆": 4,
            "伍": 5, "陆": 6, "柒": 7, "捌": 8, "玖": 9
        ]
        
        let unitMap: [Character: Double] = [
            "拾": 10, "佰": 100, "仟": 1000, "万": 10000, "亿": 100000000
        ]
        
        var result: Double = 0
        var current: Double = 0
        var temp: Double = 0
        
        for char in amount {
            if let digit = digitMap[char] {
                temp = Double(digit)
            } else if let unit = unitMap[char] {
                if temp == 0 { temp = 1 }
                current += temp * unit
                temp = 0
                
                if unit >= 10000 {
                    result += current
                    current = 0
                }
            } else if char == "元" {
                if temp > 0 { current += temp }
                result += current
                current = 0
                temp = 0
            } else if char == "角" {
                result += temp * 0.1
                temp = 0
            } else if char == "分" {
                result += temp * 0.01
                temp = 0
            }
        }
        
        if temp > 0 { current += temp }
        result += current
        
        return result
    }
    
    static func convertToChineseAmount(_ amount: String) -> String {
        guard let value = Double(amount), value >= 0 else { return "未识别" }
        
        let digits = ["零", "壹", "贰", "叁", "肆", "伍", "陆", "柒", "捌", "玖"]
        let units = ["", "拾", "佰", "仟"]
        
        let yuan = Int(value)
        let jiao = Int((value - Double(yuan)) * 10)
        let fen = Int(round((value - Double(yuan)) * 100)) % 10
        
        if yuan == 0 && jiao == 0 && fen == 0 {
            return "零元整"
        }
        
        var result = ""
        var yuanStr = String(yuan)
        var unitIndex = 0
        
        // Process integer part
        while !yuanStr.isEmpty {
            if let digit = Int(String(yuanStr.removeLast())) {
                if digit != 0 {
                    result = digits[digit] + (unitIndex < units.count ? units[unitIndex] : "") + result
                } else if !result.isEmpty && !result.hasPrefix("零") {
                    result = "零" + result
                }
            }
            unitIndex += 1
        }
        
        if result.isEmpty { result = "零" }
        result += "元"
        
        // Process decimal part
        if jiao > 0 {
            result += digits[jiao] + "角"
        }
        if fen > 0 {
            if jiao == 0 { result += "零" }
            result += digits[fen] + "分"
        }
        if jiao == 0 && fen == 0 {
            result += "整"
        }
        
        return result
    }
}

class CompanyTaxCache {
    static let shared = CompanyTaxCache()
    
    private var companyToTax: [String: String] = [:]
    private var taxToCompany: [String: String] = [:]
    private var confidence: [String: Int] = [:]
    private let lock = NSLock()
    
    func associate(company: String, taxId: String) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = "\(company)-\(taxId)"
        confidence[key, default: 0] += 1
        
        if let existingTax = companyToTax[company] {
            let existingKey = "\(company)-\(existingTax)"
            if confidence[key, default: 0] > confidence[existingKey, default: 0] {
                companyToTax[company] = taxId
                taxToCompany[taxId] = company
            }
        } else {
            companyToTax[company] = taxId
            taxToCompany[taxId] = company
        }
    }
    
    func getTaxId(for company: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return companyToTax[company]
    }
    
    func getCompany(for taxId: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return taxToCompany[taxId]
    }
}

class PDFExtractorLogic {
    
    private let cache = CompanyTaxCache.shared
    private let queue = DispatchQueue(label: "pdf.extractor", attributes: .concurrent)
    
    func processPDFs(urls: [URL]) async -> [InvoiceData] {
        let results = await withTaskGroup(of: InvoiceData?.self) { group in
            for url in urls {
                group.addTask {
                    do {
                        return try await self.processSinglePDF(url: url)
                    } catch {
                        print("处理PDF失败 \(url.lastPathComponent): \(error)")
                        return nil
                    }
                }
            }
            
            var allResults: [InvoiceData] = []
            for await result in group {
                if let result = result {
                    allResults.append(result)
                }
            }
            return allResults
        }
        
        return crossDocumentValidation(results)
    }
    
    private func processSinglePDF(url: URL) async throws -> InvoiceData {
        let fileName = url.lastPathComponent
        
        // Parallel text extraction
        async let directText = extractTextDirect(from: url)
        async let ocrText = extractTextWithOCR(from: url)
        
        let allTexts = await [directText, ocrText]
        let rawText = allTexts.enumerated()
            .map { "===方法\($0.offset + 1)===\n\($0.element)" }
            .joined(separator: "\n\n")
        
        // 打印未处理的原始数据
        print("==============================================")
        print("文件: \(fileName)")
        print("原始文本总长度: \(rawText.count) 字符")
        print("----------------------------------------------")
        // 打印前500个字符（避免控制台输出过长）
        if rawText.count > 500 {
            print(String(rawText.prefix(500)) + "...")
        } else {
            print(rawText)
        }
        print("==============================================")
        
        var invoiceData = parseEnhanced(fileName: fileName, rawText: rawText)
        invoiceData = applyCache(to: invoiceData)
        invoiceData.validateAndFix()
        updateCache(from: invoiceData)
        
        return invoiceData
    }
    
    private func parseEnhanced(fileName: String, rawText: String) -> InvoiceData {
        var data = InvoiceData(fileName: fileName, rawText: rawText)
        let cleanText = preprocessText(rawText)
        
        // Extract all components with improved patterns
        extractInvoiceNumbers(&data, from: cleanText)
        extractBuyerSellerInfo(&data, from: cleanText)
        extractAmounts(&data, from: cleanText)
        extractTaxRate(&data, from: cleanText)
        extractDate(&data, from: cleanText)
        
        return data
    }
    
    private func extractInvoiceNumbers(_ data: inout InvoiceData, from text: String) {
        // Enhanced patterns for invoice code
        let codePatterns = [
            "发票代码[\\s：:]*([0-9]{10,12})(?![0-9])",
            "代\\s*码[\\s：:]*([0-9]{10,12})(?![0-9])",
            "(?:^|\\s)([0-9]{10,12})(?=\\s*(?:发票|号码|\\n))"
        ]
        
        for pattern in codePatterns {
            if let result = extractWithRegex(pattern: pattern, from: text) {
                let cleaned = result.filter { $0.isNumber }
                if cleaned.count >= 10 && cleaned.count <= 12 {
                    data.invoiceCode = cleaned
                    break
                }
            }
        }
        
        // Enhanced patterns for invoice number
        let numberPatterns = [
            "发票号码[\\s：:]*([0-9]{8})(?![0-9])",
            "号\\s*码[\\s：:]*([0-9]{8})(?![0-9])",
            "No\\.?[\\s：:]*([0-9]{8})(?![0-9])"
        ]
        
        for pattern in numberPatterns {
            if let result = extractWithRegex(pattern: pattern, from: text) {
                let cleaned = result.filter { $0.isNumber }
                if cleaned.count == 8 {
                    data.invoiceNumber = cleaned
                    break
                }
            }
        }
    }
    
    private func extractBuyerSellerInfo(_ data: inout InvoiceData, from text: String) {
        // Enhanced buyer extraction with position awareness
        let buyerNamePatterns = [
            "购买方名称[\\s：:]*([^\\n\\r纳税统一]{2,100})",
            "购方名称[\\s：:]*([^\\n\\r纳税统一]{2,100})",
            "买方[\\s：:]*([^\\n\\r纳税统一]{2,100})",
            "付款方[\\s：:]*([^\\n\\r纳税统一]{2,100})"
        ]
        
        for pattern in buyerNamePatterns {
            if let matches = extractAllMatches(pattern: pattern, from: text) {
                for match in matches {
                    let cleaned = cleanCompanyName(match)
                    if isValidCompanyName(cleaned) && isLeftSide(text: text, value: match) {
                        data.buyerName = cleaned
                        break
                    }
                }
                if data.buyerName != "未识别" { break }
            }
        }
        
        // Enhanced buyer tax ID extraction
        let buyerTaxPatterns = [
            "购买方[\\s\\S]{0,100}?纳税人识别号[\\s：:]*([0-9A-Z]{15,20})",
            "购买方[\\s\\S]{0,100}?统一社会信用代码[\\s：:]*([0-9A-Z]{15,20})",
            "购方[\\s\\S]{0,100}?税号[\\s：:]*([0-9A-Z]{15,20})"
        ]
        
        for pattern in buyerTaxPatterns {
            if let result = extractWithRegex(pattern: pattern, from: text) {
                let cleaned = result.uppercased().filter { $0.isNumber || $0.isLetter }
                if isValidTaxId(cleaned) && isLeftSide(text: text, value: result) {
                    data.buyerTaxId = cleaned
                    break
                }
            }
        }
        
        // Enhanced seller extraction with position awareness
        let sellerNamePatterns = [
            "销售方名称[\\s：:]*([^\\n\\r纳税统一]{2,100})",
            "销方名称[\\s：:]*([^\\n\\r纳税统一]{2,100})",
            "卖方[\\s：:]*([^\\n\\r纳税统一]{2,100})",
            "收款方[\\s：:]*([^\\n\\r纳税统一]{2,100})"
        ]
        
        for pattern in sellerNamePatterns {
            if let matches = extractAllMatches(pattern: pattern, from: text) {
                for match in matches {
                    let cleaned = cleanCompanyName(match)
                    if isValidCompanyName(cleaned) && !isLeftSide(text: text, value: match) {
                        data.sellerName = cleaned
                        break
                    }
                }
                if data.sellerName != "未识别" { break }
            }
        }
        
        // Enhanced seller tax ID extraction
        let sellerTaxPatterns = [
            "销售方[\\s\\S]{0,100}?纳税人识别号[\\s：:]*([0-9A-Z]{15,20})",
            "销售方[\\s\\S]{0,100}?统一社会信用代码[\\s：:]*([0-9A-Z]{15,20})",
            "销方[\\s\\S]{0,100}?税号[\\s：:]*([0-9A-Z]{15,20})"
        ]
        
        for pattern in sellerTaxPatterns {
            if let result = extractWithRegex(pattern: pattern, from: text) {
                let cleaned = result.uppercased().filter { $0.isNumber || $0.isLetter }
                if isValidTaxId(cleaned) && !isLeftSide(text: text, value: result) {
                    data.sellerTaxId = cleaned
                    break
                }
            }
        }
    }
    
    private func extractAmounts(_ data: inout InvoiceData, from text: String) {
        // Enhanced patterns with ¥ symbol (Rule 5)
        let totalPatterns = [
            "价税合计[^¥￥]{0,50}?[¥￥]\\s*([0-9]+\\.?[0-9]{0,2})",
            "合\\s*计[^¥￥]{0,50}?[¥￥]\\s*([0-9]+\\.?[0-9]{0,2})",
            "总金额[^¥￥]{0,50}?[¥￥]\\s*([0-9]+\\.?[0-9]{0,2})",
            "小写[^¥￥]{0,30}?[¥￥]\\s*([0-9]+\\.?[0-9]{0,2})"
        ]
        
        var amounts: [(String, Double, String)] = []
        
        for pattern in totalPatterns {
            if let result = extractWithRegex(pattern: pattern, from: text) {
                if let amount = parseAmountString(result) {
                    amounts.append(("total", amount, result))
                    if data.totalAmountLower == "未识别" {
                        data.totalAmountLower = formatAmount(amount)
                    }
                }
            }
        }
        
        let taxPatterns = [
            "税\\s*额[^¥￥]{0,30}?[¥￥]\\s*([0-9]+\\.?[0-9]{0,2})",
            "增值税[^¥￥]{0,30}?[¥￥]\\s*([0-9]+\\.?[0-9]{0,2})"
        ]
        
        for pattern in taxPatterns {
            if let result = extractWithRegex(pattern: pattern, from: text) {
                if let amount = parseAmountString(result) {
                    amounts.append(("tax", amount, result))
                    if data.taxAmount == "未识别" {
                        data.taxAmount = formatAmount(amount)
                    }
                }
            }
        }
        
        let preTaxPatterns = [
            "金\\s*额[^税¥￥]{0,30}?[¥￥]\\s*([0-9]+\\.?[0-9]{0,2})",
            "不含税[^¥￥]{0,30}?[¥￥]\\s*([0-9]+\\.?[0-9]{0,2})",
            "税前[^¥￥]{0,30}?[¥￥]\\s*([0-9]+\\.?[0-9]{0,2})"
        ]
        
        for pattern in preTaxPatterns {
            if let result = extractWithRegex(pattern: pattern, from: text) {
                if let amount = parseAmountString(result) {
                    amounts.append(("preTax", amount, result))
                    if data.preTaxAmount == "未识别" {
                        data.preTaxAmount = formatAmount(amount)
                    }
                }
            }
        }
        
        // Apply Rule 1: tax < preTax < total
        if amounts.count >= 3 {
            let sorted = amounts.sorted { $0.1 < $1.1 }
            data.taxAmount = formatAmount(sorted[0].1)
            data.preTaxAmount = formatAmount(sorted[1].1)
            data.totalAmountLower = formatAmount(sorted[2].1)
        }
        
        // Extract Chinese amount
        let upperPatterns = [
            "大写[^壹贰叁肆伍陆柒捌玖]{0,20}?([壹贰叁肆伍陆柒捌玖拾佰仟万亿零元角分整]+)",
            "￥([壹贰叁肆伍陆柒捌玖拾佰仟万亿零元角分整]+)"
        ]
        
        for pattern in upperPatterns {
            if let result = extractWithRegex(pattern: pattern, from: text) {
                if isValidChineseAmount(result) {
                    data.totalAmountUpper = result
                    break
                }
            }
        }
    }
    
    private func extractTaxRate(_ data: inout InvoiceData, from text: String) {
        let taxRatePatterns = [
            "税率[\\s：:]*([0-9]{1,2})\\s*%",
            "征收率[\\s：:]*([0-9]{1,2})\\s*%",
            "([0-9]{1,2})\\s*%[\\s]*(?:税率|征收率)",
            "税率[\\s：:]*([0-9]{1,2}(?:\\.[0-9]{1,2})?)\\s*%?"
        ]
        
        for pattern in taxRatePatterns {
            if let result = extractWithRegex(pattern: pattern, from: text) {
                if let rate = Double(result.replacingOccurrences(of: "%", with: "")) {
                    let validRates: [Double] = [0, 3, 6, 9, 13]
                    let closest = validRates.min(by: { abs($0 - rate) < abs($1 - rate) }) ?? 6
                    if abs(closest - rate) < 1.0 {
                        data.taxRate = "\(Int(closest))%"
                        break
                    }
                }
            }
        }
    }
    
    private func extractDate(_ data: inout InvoiceData, from text: String) {
        let datePatterns = [
            "开票日期[\\s：:]*([0-9]{4}年[0-9]{1,2}月[0-9]{1,2}日)",
            "日\\s*期[\\s：:]*([0-9]{4}年[0-9]{1,2}月[0-9]{1,2}日)",
            "([0-9]{4}年[0-9]{1,2}月[0-9]{1,2}日)"
        ]
        
        for pattern in datePatterns {
            if let result = extractWithRegex(pattern: pattern, from: text) {
                data.issueDate = result
                break
            }
        }
    }
    
    // Cross-document validation
    private func crossDocumentValidation(_ invoices: [InvoiceData]) -> [InvoiceData] {
        var validated = invoices
        
        // Build company-tax mappings
        var companyTaxFrequency: [String: [String: Int]] = [:]
        
        for invoice in invoices {
            if invoice.buyerName != "未识别" && invoice.buyerTaxId != "未识别" {
                companyTaxFrequency[invoice.buyerName, default: [:]][invoice.buyerTaxId, default: 0] += 1
            }
            if invoice.sellerName != "未识别" && invoice.sellerTaxId != "未识别" {
                companyTaxFrequency[invoice.sellerName, default: [:]][invoice.sellerTaxId, default: 0] += 1
            }
        }
        
        // Find most common mappings
        var trustedMapping: [String: String] = [:]
        for (company, taxIds) in companyTaxFrequency {
            if let mostCommon = taxIds.max(by: { $0.value < $1.value }) {
                trustedMapping[company] = mostCommon.key
            }
        }
        
        // Apply validated mappings
        for i in 0..<validated.count {
            if validated[i].buyerName != "未识别" && validated[i].buyerTaxId == "未识别" {
                if let taxId = trustedMapping[validated[i].buyerName] {
                    validated[i].buyerTaxId = taxId
                }
            }
            
            if validated[i].sellerName != "未识别" && validated[i].sellerTaxId == "未识别" {
                if let taxId = trustedMapping[validated[i].sellerName] {
                    validated[i].sellerTaxId = taxId
                }
            }
            
            // Validate amounts
            validated[i].validateAndFix()
        }
        
        return validated
    }
    
    // Helper functions
    private func isLeftSide(text: String, value: String) -> Bool {
        guard let range = text.range(of: value) else { return false }
        let position = text.distance(from: text.startIndex, to: range.lowerBound)
        let relativePosition = Double(position) / Double(text.count)
        return relativePosition < 0.5
    }
    
    private func parseAmountString(_ str: String) -> Double? {
        let cleaned = str.filter { $0.isNumber || $0 == "." }
        return Double(cleaned)
    }
    
    private func extractAllMatches(pattern: String, from text: String) -> [String]? {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, options: [], range: range)
            
            return matches.compactMap { match in
                if match.numberOfRanges > 1,
                   let captureRange = Range(match.range(at: 1), in: text) {
                    return String(text[captureRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                return nil
            }
        } catch {
            return nil
        }
    }
    
    private func applyCache(to invoice: InvoiceData) -> InvoiceData {
        var result = invoice
        
        if result.buyerName != "未识别" && result.buyerTaxId == "未识别" {
            if let taxId = cache.getTaxId(for: result.buyerName) {
                result.buyerTaxId = taxId
            }
        }
        
        if result.sellerName != "未识别" && result.sellerTaxId == "未识别" {
            if let taxId = cache.getTaxId(for: result.sellerName) {
                result.sellerTaxId = taxId
            }
        }
        
        return result
    }
    
    private func updateCache(from invoice: InvoiceData) {
        if invoice.buyerName != "未识别" && invoice.buyerTaxId != "未识别" {
            cache.associate(company: invoice.buyerName, taxId: invoice.buyerTaxId)
        }
        
        if invoice.sellerName != "未识别" && invoice.sellerTaxId != "未识别" {
            cache.associate(company: invoice.sellerName, taxId: invoice.sellerTaxId)
        }
    }
    
    private func isValidInvoiceCode(_ code: String) -> Bool {
        let cleaned = code.filter { $0.isNumber }
        return cleaned.count >= 10 && cleaned.count <= 12
    }
    
    private func isValidInvoiceNumber(_ number: String) -> Bool {
        let cleaned = number.filter { $0.isNumber }
        return cleaned.count == 8
    }
    
    private func isValidTaxId(_ taxId: String) -> Bool {
        let uppercased = taxId.uppercased()
        guard uppercased.count >= 15 && uppercased.count <= 20 else { return false }
        
        // Must contain at least some numbers
        let numberCount = uppercased.filter { $0.isNumber }.count
        guard numberCount >= 10 else { return false }
        
        return uppercased.allSatisfy { $0.isNumber || ($0 >= "A" && $0 <= "Z") }
    }
    
    private func isValidCompanyName(_ name: String) -> Bool {
        guard name.count >= 4 && name.count <= 100 else { return false }
        
        // Rule 3: Company name keywords
        let companyIndicators = ["公司", "有限", "集团", "企业", "厂", "店", "中心", "院", "所", "局", "部", "室", "行"]
        let hasIndicator = companyIndicators.contains { name.contains($0) }
        
        // Invalid words that shouldn't be in company names
        let invalidWords = ["纳税", "识别", "代码", "号码", "税额", "合计", "金额", "：", ":", "发票", "税率", "%", "¥"]
        let hasInvalid = invalidWords.contains { name.contains($0) }
        
        return hasIndicator && !hasInvalid
    }
    
    private func isValidAmount(_ amount: String) -> Bool {
        guard let value = Double(amount), value > 0 else { return false }
        return amount.range(of: "^\\d+\\.\\d{2}$", options: .regularExpression) != nil
    }
    
    private func isValidChineseAmount(_ amount: String) -> Bool {
        let validChars = "壹贰叁肆伍陆柒捌玖拾佰仟万亿元角分整零"
        return amount.count >= 3 && amount.contains("元") && amount.allSatisfy { validChars.contains($0) }
    }
    
    private func preprocessText(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "：", with: ":")
            .replacingOccurrences(of: "（", with: "(")
            .replacingOccurrences(of: "）", with: ")")
    }
    
    private func cleanCompanyName(_ name: String) -> String {
        var cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove prefixes
        let prefixes = ["名称:", "名称：", "购买方", "销售方", "买方", "卖方", "购方", "销方", "付款方", "收款方"]
        for prefix in prefixes {
            if cleaned.hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            }
        }
        
        // Remove suffixes that indicate field transitions
        let suffixes = ["纳税", "识别", "统一", "信用", "代码", "税号", "地址", "电话", "开户"]
        for suffix in suffixes {
            if let range = cleaned.range(of: suffix) {
                let beforeSuffix = String(cleaned[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                if beforeSuffix.count >= 4 {
                    cleaned = beforeSuffix
                    break
                }
            }
        }
        
        return cleaned
    }
    
    private func extractWithRegex(pattern: String, from text: String, group: Int = 1) -> String? {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range) {
                if match.numberOfRanges > group,
                   let captureRange = Range(match.range(at: group), in: text) {
                    return String(text[captureRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        } catch {
            print("正则表达式错误: \(error)")
        }
        return nil
    }
    
    // Text extraction methods remain the same
    private func extractTextDirect(from url: URL) async -> String {
        guard let pdfDocument = PDFDocument(url: url) else { return "" }
        
        var allText = ""
        for i in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: i),
               let text = page.string {
                allText += text + "\n"
            }
        }
        return allText
    }
    
    private func extractTextWithOCR(from url: URL) async -> String {
        guard let pdfDocument = PDFDocument(url: url) else { return "" }
        
        var allText = ""
        for i in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: i) {
                let ocrText = await performOCR(on: page)
                allText += ocrText + "\n"
            }
        }
        return allText
    }
    
    private func performOCR(on page: PDFPage) async -> String {
        let pageRect = page.bounds(for: .mediaBox)
        let scale: CGFloat = 3.0
        let scaledSize = NSSize(width: pageRect.size.width * scale,
                                height: pageRect.size.height * scale)
        
        let image = NSImage(size: scaledSize)
        image.lockFocus()
        
        if let context = NSGraphicsContext.current?.cgContext {
            context.scaleBy(x: scale, y: scale)
            context.setFillColor(NSColor.white.cgColor)
            context.fill(CGRect(origin: .zero, size: pageRect.size))
            context.interpolationQuality = .high
            page.draw(with: .mediaBox, to: context)
        }
        
        image.unlockFocus()
        
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return ""
        }
        
        return await withCheckedContinuation { continuation in
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                
                let recognizedText = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                
                continuation.resume(returning: recognizedText)
            }
            
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
            request.usesLanguageCorrection = true
            
            do {
                try requestHandler.perform([request])
            } catch {
                continuation.resume(returning: "")
            }
        }
    }
    
    func convertToCSV(invoices: [InvoiceData]) -> String {
        let headers = ["文件名", "发票代码", "发票号码", "开票日期",
                      "购买方名称", "购买方税号", "销售方名称", "销售方税号",
                      "价税合计(小写)", "价税合计(大写)", "税额", "不含税金额", "税率"]
        var csvString = headers.joined(separator: ",") + "\n"
        
        for invoice in invoices {
            let row = [
                invoice.fileName,
                invoice.invoiceCode,
                invoice.invoiceNumber,
                invoice.issueDate,
                invoice.buyerName,
                invoice.buyerTaxId,
                invoice.sellerName,
                invoice.sellerTaxId,
                invoice.totalAmountLower,
                invoice.totalAmountUpper,
                invoice.taxAmount,
                invoice.preTaxAmount,
                invoice.taxRate
            ].map { escapeCSVField($0) }.joined(separator: ",")
            csvString += row + "\n"
        }
        return csvString
    }
    
    private func escapeCSVField(_ field: String) -> String {
        let sanitized = field.replacingOccurrences(of: "\"", with: "\"\"")
        if sanitized.contains(",") || sanitized.contains("\"") || sanitized.contains("\n") {
            return "\"\(sanitized)\""
        }
        return sanitized
    }
}

extension Array where Element: Hashable {
    func mostCommon() -> Element? {
        let counts = self.reduce(into: [:]) { counts, element in
            counts[element, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }
}

private func formatAmount(_ amount: Double) -> String {
    return String(format: "%.2f", amount)
}
private func printInvoiceData(_ data: InvoiceData) {
    print("文件名: \(data.fileName)")
    print("发票代码: \(data.invoiceCode)")
    print("发票号码: \(data.invoiceNumber)")
    print("开票日期: \(data.issueDate)")
    print("购买方名称: \(data.buyerName)")
    print("购买方税号: \(data.buyerTaxId)")
    print("销售方名称: \(data.sellerName)")
    print("销售方税号: \(data.sellerTaxId)")
    print("价税合计(小写): \(data.totalAmountLower)")
    print("价税合计(大写): \(data.totalAmountUpper)")
    print("税额: \(data.taxAmount)")
    print("不含税金额: \(data.preTaxAmount)")
    print("税率: \(data.taxRate)")
}
