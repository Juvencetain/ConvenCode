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

// MARK: - Unified Diff Line Model
struct UnifiedDiffLine: Identifiable {
    let id = UUID()
    let oldLineNumber: String
    let newLineNumber: String
    let content: AttributedString
    let type: UnifiedDiffLineType
}

enum UnifiedDiffLineType {
    case unchanged
    case added
    case deleted
    case modified // Although no longer generated, kept for potential future use.
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
    @Published var textProcessorUnifiedDiffLines: [UnifiedDiffLine] = []
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
    
    func textProcessorCompareDiffUnified() {
        let text1 = textProcessorDiffText1
        let text2 = textProcessorDiffText2
        
        DispatchQueue.global(qos: .userInitiated).async {
            let lines1 = text1.components(separatedBy: .newlines)
            let lines2 = text2.components(separatedBy: .newlines)
            
            let unifiedLines = self.textProcessorCalculateUnifiedDiff(lines1, lines2)
            
            DispatchQueue.main.async {
                self.textProcessorUnifiedDiffLines = unifiedLines
                self.textProcessorDiffEnabled = true
            }
        }
    }
    
    // MARK: - Character-level Diff Calculation (New)
    /// Calculates character-level differences and returns attributed strings for both old and new text.
    private func textProcessorCalculateCharDiffs(_ old: String, _ new: String) -> (old: AttributedString, new: AttributedString) {
        let oldChars = Array(old)
        let newChars = Array(new)
        
        let n = oldChars.count
        let m = newChars.count
        
        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        
        if n > 0 && m > 0 {
            for i in 1...n {
                for j in 1...m {
                    if oldChars[i-1] == newChars[j-1] {
                        dp[i][j] = dp[i-1][j-1] + 1
                    } else {
                        dp[i][j] = max(dp[i-1][j], dp[i][j-1])
                    }
                }
            }
        }
        
        var i = n
        var j = m
        var oldSegments: [(text: String, isDifferent: Bool)] = []
        var newSegments: [(text: String, isDifferent: Bool)] = []
        
        while i > 0 || j > 0 {
            if i > 0 && j > 0 && oldChars[i-1] == newChars[j-1] {
                oldSegments.insert((String(oldChars[i-1]), false), at: 0)
                newSegments.insert((String(newChars[j-1]), false), at: 0)
                i -= 1
                j -= 1
            } else if j > 0 && (i == 0 || dp[i][j-1] >= dp[i-1][j]) {
                newSegments.insert((String(newChars[j-1]), true), at: 0)
                j -= 1
            } else if i > 0 && (j == 0 || dp[i-1][j] >= dp[i][j-1]) {
                oldSegments.insert((String(oldChars[i-1]), true), at: 0)
                i -= 1
            } else {
                i -= 1
                j -= 1
            }
        }
        
        var oldResult = AttributedString()
        for segment in oldSegments {
            var attrText = AttributedString(segment.text)
            if segment.isDifferent {
                attrText.backgroundColor = Color.red.opacity(0.4)
                attrText.font = .system(size: 11, design: .monospaced).weight(.semibold)
            }
            oldResult.append(attrText)
        }
        
        var newResult = AttributedString()
        for segment in newSegments {
            var attrText = AttributedString(segment.text)
            if segment.isDifferent {
                attrText.backgroundColor = Color.green.opacity(0.4)
                attrText.font = .system(size: 11, design: .monospaced).weight(.semibold)
            }
            newResult.append(attrText)
        }

        return (oldResult, newResult)
    }
    
    // MARK: - Optimized and Safer Diff Calculation
    private func textProcessorCalculateUnifiedDiff(_ lines1: [String], _ lines2: [String]) -> [UnifiedDiffLine] {
        let n = lines1.count
        let m = lines2.count
        
        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        if n > 0 && m > 0 {
            for i in 1...n {
                for j in 1...m {
                    if lines1[i-1] == lines2[j-1] {
                        dp[i][j] = dp[i-1][j-1] + 1
                    } else {
                        dp[i][j] = max(dp[i-1][j], dp[i][j-1])
                    }
                }
            }
        }
        
        var i = n
        var j = m
        var diffOps: [(type: UnifiedDiffLineType, oldIdx: Int?, newIdx: Int?)] = []
        while i > 0 || j > 0 {
            if i > 0 && j > 0 && lines1[i-1] == lines2[j-1] {
                diffOps.insert((.unchanged, i-1, j-1), at: 0)
                i -= 1
                j -= 1
            } else if j > 0 && (i == 0 || dp[i][j-1] >= dp[i-1][j]) {
                diffOps.insert((.added, nil, j-1), at: 0)
                j -= 1
            } else if i > 0 {
                diffOps.insert((.deleted, i-1, nil), at: 0)
                i -= 1
            }
        }
        
        var result: [UnifiedDiffLine] = []
        var oldLineNum = 1
        var newLineNum = 1
        
        var idx = 0
        while idx < diffOps.count {
            let op = diffOps[idx]
            
            if op.type == .deleted, let oldIdx = op.oldIdx, oldIdx < lines1.count,
               idx + 1 < diffOps.count, let nextOp = Optional(diffOps[idx + 1]), nextOp.type == .added,
               let newIdx = nextOp.newIdx, newIdx < lines2.count {
                
                let oldContent = lines1[oldIdx]
                let newContent = lines2[newIdx]
                let (deletedAttr, addedAttr) = textProcessorCalculateCharDiffs(oldContent, newContent)
                
                result.append(UnifiedDiffLine(
                    oldLineNumber: "\(oldLineNum)",
                    newLineNumber: "",
                    content: deletedAttr,
                    type: .deleted
                ))
                
                result.append(UnifiedDiffLine(
                    oldLineNumber: "",
                    newLineNumber: "\(newLineNum)",
                    content: addedAttr,
                    type: .added
                ))
                
                oldLineNum += 1
                newLineNum += 1
                idx += 2
            } else {
                switch op.type {
                case .unchanged:
                    if let oldIdx = op.oldIdx, oldIdx < lines1.count {
                        result.append(UnifiedDiffLine(
                            oldLineNumber: "\(oldLineNum)",
                            newLineNumber: "\(newLineNum)",
                            content: AttributedString(lines1[oldIdx]),
                            type: .unchanged
                        ))
                        oldLineNum += 1
                        newLineNum += 1
                    }
                case .deleted:
                    if let oldIdx = op.oldIdx, oldIdx < lines1.count {
                        result.append(UnifiedDiffLine(
                            oldLineNumber: "\(oldLineNum)",
                            newLineNumber: "",
                            content: AttributedString(lines1[oldIdx]),
                            type: .deleted
                        ))
                        oldLineNum += 1
                    }
                case .added:
                    if let newIdx = op.newIdx, newIdx < lines2.count {
                        result.append(UnifiedDiffLine(
                            oldLineNumber: "",
                            newLineNumber: "\(newLineNum)",
                            content: AttributedString(lines2[newIdx]),
                            type: .added
                        ))
                        newLineNum += 1
                    }
                default:
                    break
                }
                idx += 1
            }
        }
        
        if result.isEmpty && textProcessorDiffText1 == textProcessorDiffText2 && !textProcessorDiffText1.isEmpty {
            result.append(UnifiedDiffLine(
                oldLineNumber: "✓",
                newLineNumber: "✓",
                content: AttributedString("两段文本完全相同"),
                type: .unchanged
            ))
        }
        
        return result
    }
    
    // MARK: - Statistics Methods
    private func textProcessorCalculateStats() {
        let text = textProcessorStatsInput
        
        textProcessorCharCount = text.count
        
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        textProcessorWordCount = words.count
        
        let lines = text.components(separatedBy: .newlines)
        textProcessorLineCount = text.isEmpty ? 0 : lines.count
        
        let paragraphs = text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        textProcessorParagraphCount = paragraphs.count
    }
    
    // MARK: - Diff Methods (Optimized IDEA-style)
    func textProcessorCompareDiff() {
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
            
            if diffPairs.isEmpty && text1 == text2 && !text1.isEmpty {
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
        textProcessorUnifiedDiffLines = []
    }
    
    private func textProcessorCalculateDiffOptimized(_ lines1: [String], _ lines2: [String]) -> [TextProcessorDiffLine] {
        let n = lines1.count
        let m = lines2.count
        let max = n + m
        
        var v = Array(repeating: 0, count: 2 * max + 1)
        var trace: [[Int]] = []
        
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
                    content: lines1[x]
                ), at: 0)
            }
            
            if d > 0 {
                if x == prevX {
                    y -= 1
                    result.insert(TextProcessorDiffLine(
                        type: .added,
                        content: lines2[y]
                    ), at: 0)
                } else {
                    x -= 1
                    result.insert(TextProcessorDiffLine(
                        type: .deleted,
                        content: lines1[x]
                    ), at: 0)
                }
            }
        }
        
        return result
    }
    
    private struct TextProcessorDiffLine {
        let type: TextProcessorDiffLineType
        let content: String
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
            if !seen.contains(line) {
                seen.insert(line)
                unique.append(line)
            }
        }
        
        textProcessorSortOutput = unique.joined(separator: "\n")
    }
    
    func textProcessorReverseLines() {
        let lines = textProcessorSortInput.components(separatedBy: .newlines)
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
                textProcessorMatchCount = regex.numberOfMatches(in: text, range: range)
            } catch {
                textProcessorMatchCount = 0
            }
        } else {
            let options: String.CompareOptions = textProcessorCaseSensitive ? [] : [.caseInsensitive]
            var count = 0
            var searchRange = text.startIndex..<text.endIndex
            while let range = text.range(of: textProcessorFindText, options: options, range: searchRange) {
                count += 1
                searchRange = range.upperBound..<text.endIndex
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
                textProcessorFindReplaceOutput = regex.stringByReplacingMatches(in: text, range: range, withTemplate: textProcessorReplaceText)
            } catch {
                textProcessorFindReplaceOutput = "正则表达式错误: \(error.localizedDescription)"
            }
        } else {
            let options: String.CompareOptions = textProcessorCaseSensitive ? [.literal] : [.literal, .caseInsensitive]
            textProcessorFindReplaceOutput = text.replacingOccurrences(of: textProcessorFindText, with: textProcessorReplaceText, options: options)
        }
        
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
        
        let unicode = String(format: "U+%04X", value)
        let unicodeDecimal = String(value)
        
        let htmlEntity = textProcessorGetHTMLEntity(for: char)
        let htmlDecimal = String(format: "&#%d;", value)
        
        let urlEncoded = char.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let utf8Bytes = char.utf8.map { String(format: "0x%02X", $0) }.joined(separator: " ")
        
        let description = scalar.properties.name ?? "无描述"
        
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
            "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&apos;",
            " ": "&nbsp;", "©": "&copy;", "®": "&reg;", "™": "&trade;", "€": "&euro;",
            "£": "&pound;", "¥": "&yen;", "¢": "&cent;", "§": "&sect;", "¶": "&para;",
            "•": "&bull;", "…": "&hellip;", "′": "&prime;", "″": "&Prime;", "°": "&deg;",
            "±": "&plusmn;", "×": "&times;", "÷": "&divide;", "←": "&larr;", "↑": "&uarr;",
            "→": "&rarr;", "↓": "&darr;", "↔": "&harr;", "♠": "&spades;", "♣": "&clubs;",
            "♥": "&hearts;", "♦": "&diams;"
        ]
        
        return entities[char] ?? "无常用实体"
    }
}

