import Foundation
import SwiftUI
import Combine

// MARK: - Text Processor Tab
enum TextProcessorTab: String, CaseIterable {
    case statistics = "字数统计"
    case diff = "差异对比"
    case caseConversion = "大小写转换"
    case sortDedupe = "排序去重"
    case findReplace = "查找替换"
    case charInfo = "字符信息"
    
    var icon: String {
        switch self {
        case .statistics: return "chart.bar.doc.horizontal"
        case .diff: return "arrow.left.arrow.right.square"
        case .caseConversion: return "textformat.size"
        case .sortDedupe: return "arrow.up.arrow.down.square"
        case .findReplace: return "magnifyingglass"
        case .charInfo: return "character.cursor.ibeam"
        }
    }
}

// MARK: - Diff Line Type
enum TextProcessorDiffLineType {
    case unchanged
    case deleted
    case added
}

// MARK: - IDEA Style Diff Pair Model
struct TextProcessorDiffPair {
    let leftLineNumber: String
    let leftContent: String
    let leftType: TextProcessorDiffLineType
    
    let rightLineNumber: String
    let rightContent: String
    let rightType: TextProcessorDiffLineType
}

// MARK: - Case Type
enum TextProcessorCaseType {
    case uppercase
    case lowercase
    case capitalized
    case camelCase
    case snakeCase
    case kebabCase
}

// MARK: - Character Info Model
struct TextProcessorCharacterInfo {
    let character: String
    let unicode: String
    let unicodeDecimal: String
    let htmlEntity: String
    let htmlDecimal: String
    let urlEncoded: String
    let utf8: String
    let description: String
}

// MARK: - Text Processor ViewModel
class TextProcessorViewModel: ObservableObject {
    // MARK: - Statistics Properties
    @Published var textProcessorStatsInput: String = "" {
        didSet { textProcessorCalculateStats() }
    }
    @Published var textProcessorCharCount: Int = 0
    @Published var textProcessorWordCount: Int = 0
    @Published var textProcessorLineCount: Int = 0
    @Published var textProcessorParagraphCount: Int = 0
    
    // MARK: - Diff Properties
    @Published var textProcessorDiffText1: String = ""
    @Published var textProcessorDiffText2: String = ""
    @Published var textProcessorDiffPairs: [TextProcessorDiffPair] = []
    @Published var textProcessorDiffEnabled: Bool = false
    @Published var textProcessorWindowExpanded: Bool = false
    
    // MARK: - Case Conversion Properties
    @Published var textProcessorCaseInput: String = ""
    @Published var textProcessorCaseOutput: String = ""
    
    // MARK: - Sort & Dedupe Properties
    @Published var textProcessorSortInput: String = ""
    @Published var textProcessorSortOutput: String = ""
    
    // MARK: - Find & Replace Properties
    @Published var textProcessorFindReplaceInput: String = ""
    @Published var textProcessorFindText: String = ""
    @Published var textProcessorReplaceText: String = ""
    @Published var textProcessorUseRegex: Bool = false
    @Published var textProcessorCaseSensitive: Bool = true
    @Published var textProcessorMatchCount: Int = 0
    @Published var textProcessorFindReplaceOutput: String = ""
    
    // MARK: - Character Info Properties
    @Published var textProcessorCharInput: String = ""
    @Published var textProcessorCharInfo: TextProcessorCharacterInfo?
    
    // MARK: - Statistics Methods
    private func textProcessorCalculateStats() {
        let text = textProcessorStatsInput
        
        // 字符数（包括空格）
        textProcessorCharCount = text.count
        
        // 词数（按空白字符分割）
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        textProcessorWordCount = words.count
        
        // 行数
        let lines = text.components(separatedBy: .newlines)
        textProcessorLineCount = lines.filter { !$0.isEmpty }.count
        
        // 段落数（连续非空行为一段）
        let paragraphs = text.components(separatedBy: .newlines)
        var paragraphCount = 0
        var inParagraph = false
        
        for line in paragraphs {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                inParagraph = false
            } else if !inParagraph {
                paragraphCount += 1
                inParagraph = true
            }
        }
        textProcessorParagraphCount = paragraphCount
    }
    
    // MARK: - Diff Methods (Optimized IDEA-style)
    func textProcessorCompareDiff() {
        // 使用后台线程进行计算，避免卡顿
        let text1 = textProcessorDiffText1
        let text2 = textProcessorDiffText2
        
        DispatchQueue.global(qos: .userInitiated).async {
            let lines1 = text1.components(separatedBy: .newlines)
            let lines2 = text2.components(separatedBy: .newlines)
            
            let diffs = self.textProcessorCalculateDiffOptimized(lines1, lines2)
            
            var diffPairs: [TextProcessorDiffPair] = []
            var leftLineNum = 1
            var rightLineNum = 1
            
            for diff in diffs {
                switch diff.type {
                case .unchanged:
                    diffPairs.append(TextProcessorDiffPair(
                        leftLineNumber: "\(leftLineNum)",
                        leftContent: diff.content,
                        leftType: .unchanged,
                        rightLineNumber: "\(rightLineNum)",
                        rightContent: diff.content,
                        rightType: .unchanged
                    ))
                    leftLineNum += 1
                    rightLineNum += 1
                    
                case .deleted:
                    diffPairs.append(TextProcessorDiffPair(
                        leftLineNumber: "\(leftLineNum)",
                        leftContent: diff.content,
                        leftType: .deleted,
                        rightLineNumber: "",
                        rightContent: "",
                        rightType: .unchanged
                    ))
                    leftLineNum += 1
                    
                case .added:
                    diffPairs.append(TextProcessorDiffPair(
                        leftLineNumber: "",
                        leftContent: "",
                        leftType: .unchanged,
                        rightLineNumber: "\(rightLineNum)",
                        rightContent: diff.content,
                        rightType: .added
                    ))
                    rightLineNum += 1
                }
            }
            
            if diffPairs.isEmpty {
                diffPairs.append(TextProcessorDiffPair(
                    leftLineNumber: "✓",
                    leftContent: "两段文本完全相同",
                    leftType: .unchanged,
                    rightLineNumber: "✓",
                    rightContent: "两段文本完全相同",
                    rightType: .unchanged
                ))
            }
            
            DispatchQueue.main.async {
                self.textProcessorDiffPairs = diffPairs
                self.textProcessorDiffEnabled = true
            }
        }
    }
    
    func textProcessorDisableDiff() {
        textProcessorDiffEnabled = false
        textProcessorDiffPairs = []
    }
    
    // 优化的差异计算算法 - Myers Diff Algorithm (更快速)
    private func textProcessorCalculateDiffOptimized(_ lines1: [String], _ lines2: [String]) -> [TextProcessorDiffLine] {
        let n = lines1.count
        let m = lines2.count
        let max = n + m
        
        var v = Array(repeating: 0, count: 2 * max + 1)
        var trace: [[Int]] = []
        
        // Myers算法核心 - 寻找最短编辑路径
        outerLoop: for d in 0...max {
            trace.append(v)
            
            for k in stride(from: -d, through: d, by: 2) {
                var x: Int
                if k == -d || (k != d && v[max + k - 1] < v[max + k + 1]) {
                    x = v[max + k + 1]
                } else {
                    x = v[max + k - 1] + 1
                }
                
                var y = x - k
                
                while x < n && y < m && lines1[x] == lines2[y] {
                    x += 1
                    y += 1
                }
                
                v[max + k] = x
                
                if x >= n && y >= m {
                    break outerLoop
                }
            }
        }
        
        // 回溯构建差异结果
        return textProcessorBacktrack(lines1, lines2, trace)
    }
    
    private func textProcessorBacktrack(_ lines1: [String], _ lines2: [String], _ trace: [[Int]]) -> [TextProcessorDiffLine] {
        var result: [TextProcessorDiffLine] = []
        var x = lines1.count
        var y = lines2.count
        
        let max = lines1.count + lines2.count
        
        for (d, v) in trace.enumerated().reversed() {
            let k = x - y
            
            var prevK: Int
            if k == -d || (k != d && v[max + k - 1] < v[max + k + 1]) {
                prevK = k + 1
            } else {
                prevK = k - 1
            }
            
            let prevX = v[max + prevK]
            let prevY = prevX - prevK
            
            while x > prevX && y > prevY {
                x -= 1
                y -= 1
                result.insert(TextProcessorDiffLine(
                    type: .unchanged,
                    content: lines1[x],
                    prefix: "\(x + 1)"
                ), at: 0)
            }
            
            if d > 0 {
                if x == prevX {
                    // 添加
                    y -= 1
                    result.insert(TextProcessorDiffLine(
                        type: .added,
                        content: lines2[y],
                        prefix: "+"
                    ), at: 0)
                } else {
                    // 删除
                    x -= 1
                    result.insert(TextProcessorDiffLine(
                        type: .deleted,
                        content: lines1[x],
                        prefix: "-"
                    ), at: 0)
                }
            }
        }
        
        return result
    }
    
    // LCS 辅助数据结构
    private struct TextProcessorDiffLine {
        let type: TextProcessorDiffLineType
        let content: String
        let prefix: String
    }
    
    // MARK: - Case Conversion Methods
    func textProcessorConvertCase(_ type: TextProcessorCaseType) {
        let input = textProcessorCaseInput
        
        switch type {
        case .uppercase:
            textProcessorCaseOutput = input.uppercased()
            
        case .lowercase:
            textProcessorCaseOutput = input.lowercased()
            
        case .capitalized:
            textProcessorCaseOutput = input.capitalized
            
        case .camelCase:
            let words = input.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
            if words.isEmpty {
                textProcessorCaseOutput = ""
            } else {
                let first = words[0].lowercased()
                let rest = words.dropFirst().map { $0.capitalized }.joined()
                textProcessorCaseOutput = first + rest
            }
            
        case .snakeCase:
            let cleaned = input.replacingOccurrences(of: "[^a-zA-Z0-9\\s]", with: "", options: .regularExpression)
            let words = cleaned.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
            textProcessorCaseOutput = words.map { $0.lowercased() }.joined(separator: "_")
            
        case .kebabCase:
            let cleaned = input.replacingOccurrences(of: "[^a-zA-Z0-9\\s]", with: "", options: .regularExpression)
            let words = cleaned.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
            textProcessorCaseOutput = words.map { $0.lowercased() }.joined(separator: "-")
        }
    }
    
    // MARK: - Sort & Dedupe Methods
    func textProcessorSortLines(ascending: Bool) {
        let lines = textProcessorSortInput.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        let sorted = ascending ? lines.sorted() : lines.sorted(by: >)
        textProcessorSortOutput = sorted.joined(separator: "\n")
    }
    
    func textProcessorRemoveDuplicates() {
        let lines = textProcessorSortInput.components(separatedBy: .newlines)
        var seen = Set<String>()
        var unique: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !seen.contains(line) {
                seen.insert(line)
                unique.append(line)
            }
        }
        
        textProcessorSortOutput = unique.joined(separator: "\n")
    }
    
    func textProcessorReverseLines() {
        let lines = textProcessorSortInput.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        textProcessorSortOutput = lines.reversed().joined(separator: "\n")
    }
    
    // MARK: - Find & Replace Methods
    func textProcessorFindMatches() {
        guard !textProcessorFindText.isEmpty else {
            textProcessorMatchCount = 0
            return
        }
        
        let text = textProcessorFindReplaceInput
        
        if textProcessorUseRegex {
            do {
                let options: NSRegularExpression.Options = textProcessorCaseSensitive ? [] : [.caseInsensitive]
                let regex = try NSRegularExpression(pattern: textProcessorFindText, options: options)
                let range = NSRange(text.startIndex..., in: text)
                let matches = regex.matches(in: text, range: range)
                textProcessorMatchCount = matches.count
            } catch {
                textProcessorMatchCount = 0
            }
        } else {
            let searchText = textProcessorCaseSensitive ? text : text.lowercased()
            let findText = textProcessorCaseSensitive ? textProcessorFindText : textProcessorFindText.lowercased()
            
            var count = 0
            var searchRange = searchText.startIndex..<searchText.endIndex
            
            while let range = searchText.range(of: findText, range: searchRange) {
                count += 1
                searchRange = range.upperBound..<searchText.endIndex
            }
            
            textProcessorMatchCount = count
        }
    }
    
    func textProcessorReplaceAll() {
        guard !textProcessorFindText.isEmpty else {
            textProcessorFindReplaceOutput = textProcessorFindReplaceInput
            return
        }
        
        let text = textProcessorFindReplaceInput
        
        if textProcessorUseRegex {
            do {
                let options: NSRegularExpression.Options = textProcessorCaseSensitive ? [] : [.caseInsensitive]
                let regex = try NSRegularExpression(pattern: textProcessorFindText, options: options)
                let range = NSRange(text.startIndex..., in: text)
                let result = regex.stringByReplacingMatches(
                    in: text,
                    range: range,
                    withTemplate: textProcessorReplaceText
                )
                textProcessorFindReplaceOutput = result
            } catch {
                textProcessorFindReplaceOutput = "正则表达式错误: \(error.localizedDescription)"
            }
        } else {
            let options: String.CompareOptions = textProcessorCaseSensitive ? [] : [.caseInsensitive]
            textProcessorFindReplaceOutput = text.replacingOccurrences(
                of: textProcessorFindText,
                with: textProcessorReplaceText,
                options: options
            )
        }
        
        // 更新匹配计数
        textProcessorFindMatches()
    }
    
    // MARK: - Character Info Methods
    func textProcessorAnalyzeCharacter() {
        guard let firstChar = textProcessorCharInput.first else {
            textProcessorCharInfo = nil
            return
        }
        
        let char = String(firstChar)
        let scalar = char.unicodeScalars.first!
        let value = scalar.value
        
        // Unicode
        let unicode = String(format: "U+%04X", value)
        let unicodeDecimal = String(value)
        
        // HTML
        let htmlEntity = textProcessorGetHTMLEntity(for: char)
        let htmlDecimal = String(format: "&#%d;", value)
        
        // URL 编码
        let urlEncoded = char.addingPercentEncoding(withAllowedCharacters: .init(charactersIn: "")) ?? ""
        
        // UTF-8
        let utf8Bytes = char.utf8.map { String(format: "0x%02X", $0) }.joined(separator: " ")
        
        // 描述
        let description = textProcessorGetCharDescription(scalar: scalar)
        
        textProcessorCharInfo = TextProcessorCharacterInfo(
            character: char,
            unicode: unicode,
            unicodeDecimal: unicodeDecimal,
            htmlEntity: htmlEntity,
            htmlDecimal: htmlDecimal,
            urlEncoded: urlEncoded,
            utf8: utf8Bytes,
            description: description
        )
    }
    
    private func textProcessorGetHTMLEntity(for char: String) -> String {
        let entities: [String: String] = [
            "&": "&amp;",
            "<": "&lt;",
            ">": "&gt;",
            "\"": "&quot;",
            "'": "&apos;",
            " ": "&nbsp;",
            "©": "&copy;",
            "®": "&reg;",
            "™": "&trade;",
            "€": "&euro;",
            "£": "&pound;",
            "¥": "&yen;",
            "¢": "&cent;",
            "§": "&sect;",
            "¶": "&para;",
            "•": "&bull;",
            "…": "&hellip;",
            "′": "&prime;",
            "″": "&Prime;",
            "°": "&deg;",
            "±": "&plusmn;",
            "×": "&times;",
            "÷": "&divide;",
            "←": "&larr;",
            "↑": "&uarr;",
            "→": "&rarr;",
            "↓": "&darr;",
            "↔": "&harr;",
            "♠": "&spades;",
            "♣": "&clubs;",
            "♥": "&hearts;",
            "♦": "&diams;"
        ]
        
        return entities[char] ?? "无常用实体"
    }
    
    private func textProcessorGetCharDescription(scalar: Unicode.Scalar) -> String {
        let value = scalar.value
        
        // ASCII 范围
        if value <= 0x7F {
            if value < 0x20 || value == 0x7F {
                return "ASCII 控制字符"
            }
            if (0x30...0x39).contains(value) {
                return "ASCII 数字"
            }
            if (0x41...0x5A).contains(value) {
                return "ASCII 大写字母"
            }
            if (0x61...0x7A).contains(value) {
                return "ASCII 小写字母"
            }
            return "ASCII 可打印字符"
        }
        
        // 基本多语言平面
        if value <= 0xFFFF {
            if (0x4E00...0x9FFF).contains(value) {
                return "CJK 统一汉字"
            }
            if (0x3040...0x309F).contains(value) {
                return "日文平假名"
            }
            if (0x30A0...0x30FF).contains(value) {
                return "日文片假名"
            }
            if (0xAC00...0xD7AF).contains(value) {
                return "韩文音节"
            }
            if (0x0600...0x06FF).contains(value) {
                return "阿拉伯文"
            }
            if (0x0400...0x04FF).contains(value) {
                return "西里尔字母"
            }
            if (0x0370...0x03FF).contains(value) {
                return "希腊字母"
            }
            if (0x2000...0x206F).contains(value) {
                return "常用标点符号"
            }
            if (0x2190...0x21FF).contains(value) {
                return "箭头符号"
            }
            if (0x2200...0x22FF).contains(value) {
                return "数学运算符"
            }
            if (0x2300...0x23FF).contains(value) {
                return "杂项技术符号"
            }
            if (0x2500...0x257F).contains(value) {
                return "制表符"
            }
            if (0x2580...0x259F).contains(value) {
                return "方块元素"
            }
            if (0x25A0...0x25FF).contains(value) {
                return "几何图形"
            }
            if (0x2600...0x26FF).contains(value) {
                return "杂项符号"
            }
            return "Unicode 基本平面字符"
        }
        
        // 辅助平面
        if (0x1F300...0x1F9FF).contains(value) {
            return "表情符号 (Emoji)"
        }
        
        return "Unicode 扩展字符"
    }
}
