import SwiftUI
import AppKit

// MARK: - JSON Processing Mode
enum JSONMode: String, CaseIterable {
    case format = "格式化"
    case minify = "压缩"
    case escape = "转义"
    case unescape = "去转义"
    
    var icon: String {
        switch self {
        case .format: return "text.alignleft"
        case .minify: return "arrow.down.to.line.compact"
        case .escape: return "chevron.left.slash.chevron.right"
        case .unescape: return "slash.circle"
        }
    }
    
    var tooltip: String {
        switch self {
        case .format: return "美化 JSON 格式"
        case .minify: return "压缩为单行"
        case .escape: return "转义特殊字符"
        case .unescape: return "去除转义字符"
        }
    }
}

// MARK: - Main View
struct JSONFormatterView: View {
    // MARK: - State Properties
    @State private var inputText = ""
    @State private var outputText = ""
    @State private var errorMessage: String?
    @State private var isResultFullscreen = false
    @State private var selectedMode: JSONMode = .format
    @State private var showSuccessToast = false
    @State private var indentSize = 2
    @State private var sortKeys = true
    
    // MARK: - Layout Constants
    private enum Layout {
        static let defaultWidth: CGFloat = 420
        static let defaultHeight: CGFloat = 560
        static let fullscreenHeight: CGFloat = 800
        static let horizontalPadding: CGFloat = 20
        static let verticalSpacing: CGFloat = 12
        static let cornerRadius: CGFloat = 10
        static let minInputHeight: CGFloat = 120
    }
    
    // MARK: - JSON Processor
    private let processor = JSONProcessor()
    
    // MARK: - Body
    var body: some View {
        ZStack {
            backgroundView
            
            VStack(spacing: 0) {
                headerBar
                contentArea
            }
        }
        .frame(
            width: Layout.defaultWidth,
            height: isResultFullscreen ? Layout.fullscreenHeight : Layout.defaultHeight
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isResultFullscreen)
        .overlay(alignment: .top) {
            if showSuccessToast {
                toastView
            }
        }
    }
    
    // MARK: - Background
    private var backgroundView: some View {
        VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
            .opacity(1)
            .ignoresSafeArea()
    }
    
    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(spacing: 12) {
            headerTitle
            Spacer()
            if !outputText.isEmpty {
                headerActions
            }
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.vertical, 16)
    }
    
    private var headerTitle: some View {
        HStack(spacing: 8) {
            Image(systemName: "curlybraces.square.fill")
                .font(.system(size: 16))
                .foregroundStyle(.orange.gradient)
            Text("JSON 工具箱")
                .font(.system(size: 14, weight: .medium))
        }
    }
    
    private var headerActions: some View {
        HStack(spacing: 8) {
            ActionButtonJson(icon: "doc.on.doc", tooltip: "复制结果") {
                copyToClipboard(outputText)
                showSuccessToast = true
            }
            
            ActionButtonJson(icon: "arrow.2.squarepath", tooltip: "交换输入输出") {
                swapInputOutput()
            }
            
            ActionButtonJson(icon: "plus.square", tooltip: "新建窗口") {
                openNewWindow()
            }
            
            ActionButtonJson(
                icon: isResultFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                tooltip: isResultFullscreen ? "退出全屏" : "全屏显示"
            ) {
                isResultFullscreen.toggle()
            }
        }
    }
    
    // MARK: - Content Area
    private var contentArea: some View {
        VStack(spacing: Layout.verticalSpacing) {
            if !isResultFullscreen {
                inputSection
                    .frame(maxHeight: outputText.isEmpty ? .infinity : nil)
                    .transition(.opacity)
            }
            
            if !outputText.isEmpty {
                outputSection
            }
            
            if isResultFullscreen || outputText.isEmpty {
                Spacer(minLength: 0)
            }
        }
        .padding(.bottom, 12)
    }
    
    // MARK: - Input Section
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("输入 JSON")
            
            inputEditor
            
            HStack(spacing: 8) {
                modeSelector
                controlButtons
                Spacer()
                if selectedMode == .format {
                    formatOptions
                }
            }
            
            if let error = errorMessage {
                ErrorLabel(message: error)
            }
        }
        .padding(.horizontal, Layout.horizontalPadding)
    }
    
    private var inputEditor: some View {
        TextEditor(text: $inputText)
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(8)
            .frame(minHeight: Layout.minInputHeight)
            .frame(maxHeight: .infinity)
            .background(Color.white.opacity(0.15))
            .cornerRadius(Layout.cornerRadius)
            .onChange(of: inputText) { _ in
                errorMessage = nil
            }
    }
    
    private var modeSelector: some View {
        Menu {
            ForEach(JSONMode.allCases, id: \.self) { mode in
                Button {
                    selectedMode = mode
                } label: {
                    Label(mode.rawValue, systemImage: mode.icon)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: selectedMode.icon)
                Text(selectedMode.rawValue)
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(6)
        }
        .menuStyle(.borderlessButton)
        .help(selectedMode.tooltip)
    }
    
    private var controlButtons: some View {
        HStack(spacing: 8) {
            Button("执行", action: processJSON)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
            
            Button("清空", action: clearAll)
                .buttonStyle(.bordered)
                .keyboardShortcut("k", modifiers: .command)
        }
    }
    
    private var formatOptions: some View {
        HStack(spacing: 12) {
            Picker("缩进", selection: $indentSize) {
                Text("2").tag(2)
                Text("4").tag(4)
                Text("Tab").tag(1)
            }
            .pickerStyle(.segmented)
            .frame(width: 120)
            
            Toggle("排序键", isOn: $sortKeys)
                .toggleStyle(.checkbox)
                .help("按字母顺序排序对象键")
        }
    }
    
    // MARK: - Output Section
    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                sectionHeader("处理结果")
                Spacer()
                if !outputText.isEmpty {
                    Text("\(outputText.count) 字符")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, Layout.horizontalPadding)
            
            outputViewer
        }
    }
    
    private var outputViewer: some View {
        ScrollView {
            Text(selectedMode == .format ? colorizedJSON(outputText) : AttributedString(outputText))
                .font(.system(.body, design: .monospaced))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
        .frame(maxHeight: isResultFullscreen ? .infinity : nil)
        .padding(.horizontal, Layout.horizontalPadding)
    }
    
    // MARK: - Toast View
    private var toastView: some View {
        Text("✓ 已复制到剪贴板")
            .font(.system(size: 13))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.green.opacity(0.9))
            .foregroundColor(.white)
            .cornerRadius(20)
            .padding(.top, 60)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                withAnimation(.easeInOut(duration: 0.3).delay(1.5)) {
                    showSuccessToast = false
                }
            }
    }
    
    // MARK: - Helper Views
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12))
            .foregroundColor(.secondary)
    }
    
    // MARK: - Actions
    private func processJSON() {
        // 清理输入文本
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedInput.isEmpty else {
            errorMessage = "请输入内容"
            outputText = ""
            return
        }
        
        do {
            outputText = try processor.process(
                trimmedInput,
                mode: selectedMode,
                indentSize: indentSize,
                sortKeys: sortKeys
            )
            errorMessage = nil
            
            // Auto-fullscreen for large outputs
            if outputText.count > 1000 && selectedMode == .format {
                isResultFullscreen = true
            }
        } catch let error as JSONProcessor.ProcessError {
            // 处理自定义错误
            errorMessage = error.errorDescription
            outputText = ""
        } catch let error as NSError {
            // 处理系统错误，提供更友好的错误信息
            if error.domain == NSCocoaErrorDomain {
                switch error.code {
                case 3840:
                    errorMessage = "JSON 格式错误：请检查括号、引号是否匹配"
                case 3841:
                    errorMessage = "JSON 格式错误：意外的结束"
                default:
                    errorMessage = "JSON 解析失败：\(error.localizedDescription)"
                }
            } else {
                errorMessage = "处理失败：\(error.localizedDescription)"
            }
            outputText = ""
        } catch {
            errorMessage = "未知错误：\(error.localizedDescription)"
            outputText = ""
        }
    }
    
    private func clearAll() {
        inputText = ""
        outputText = ""
        errorMessage = nil
        isResultFullscreen = false
    }
    
    private func swapInputOutput() {
        guard !outputText.isEmpty else { return }
        
        // 保存当前的输出文本
        let temp = outputText
        
        // 如果当前是格式化或压缩模式，直接交换
        // 如果是转义/去转义模式，需要特殊处理
        switch selectedMode {
        case .format, .minify:
            // JSON 处理模式，直接交换
            inputText = temp
            outputText = ""
        case .escape, .unescape:
            // 字符串处理模式，交换并切换模式
            inputText = temp
            outputText = ""
            // 自动切换到相反的模式
            selectedMode = (selectedMode == .escape) ? .unescape : .escape
        }
        
        errorMessage = nil
        
        // 如果是全屏状态，退出全屏以便看到输入框
        if isResultFullscreen {
            isResultFullscreen = false
        }
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    
    private func openNewWindow() {
        let newView = JSONFormatterView()
        let hostingController = NSHostingController(rootView: newView)
        let window = NSWindow(contentViewController: hostingController)
        
        window.title = ""
        window.titlebarAppearsTransparent = true
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.setContentSize(NSSize(width: Layout.defaultWidth, height: Layout.defaultHeight))
        window.center()
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // MARK: - Syntax Highlighting
    private func colorizedJSON(_ json: String) -> AttributedString {
        var attributed = AttributedString(json)
        let nsString = json as NSString
        
        // Color scheme
        let colors = (
            key: Color.cyan,
            string: Color.green,
            number: Color.orange,
            keyword: Color.purple,
            punctuation: Color.gray
        )
        
        // Apply colors using efficient regex patterns
        applyPattern(#"\"([^\"\\]|\\.)*\"\s*:"#, to: &attributed, in: nsString, color: colors.key)
        applyPattern(#":\s*\"([^\"\\]|\\.)*\""#, to: &attributed, in: nsString, color: colors.string, skipPrefix: 1)
        applyPattern(#":\s*(-?\d+(\.\d+)?([eE][+-]?\d+)?)"#, to: &attributed, in: nsString, color: colors.number, skipPrefix: 1)
        applyPattern(#"\b(true|false|null)\b"#, to: &attributed, in: nsString, color: colors.keyword)
        
        return attributed
    }
    
    private func applyPattern(_ pattern: String, to attributed: inout AttributedString, in nsString: NSString, color: Color, skipPrefix: Int = 0) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        
        regex.enumerateMatches(in: nsString as String, range: NSRange(location: 0, length: nsString.length)) { match, _, _ in
            guard let matchRange = match?.range else { return }
            var targetRange = matchRange
            
            if skipPrefix > 0 {
                targetRange.location += skipPrefix
                targetRange.length -= skipPrefix
            }
            
            if let range = Range(targetRange, in: attributed) {
                attributed[range].foregroundColor = color
            }
        }
    }
}

// MARK: - Helper Components

// [FIXED] Changed 'struct' to 'private struct' to resolve redeclaration error
private struct ActionButtonJson: View {
    let icon: String
    let tooltip: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}

struct ErrorLabel: View {
    let message: String
    
    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .foregroundColor(.red)
            .font(.system(size: 12))
    }
}

// MARK: - JSON Processor
class JSONProcessor {
    enum ProcessError: LocalizedError {
        case invalidJSON
        case invalidEscapedString
        case processingFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidJSON:
                return "无效的 JSON 格式"
            case .invalidEscapedString:
                return "无效的转义字符串"
            case .processingFailed(let message):
                return "处理失败: \(message)"
            }
        }
    }
    
    func process(_ input: String, mode: JSONMode, indentSize: Int = 2, sortKeys: Bool = true) throws -> String {
        switch mode {
        case .format:
            return try formatJSON(input, indentSize: indentSize, sortKeys: sortKeys)
        case .minify:
            return try minifyJSON(input)
        case .escape:
            return escapeString(input)
        case .unescape:
            return try unescapeString(input)
        }
    }
    
    private func formatJSON(_ input: String, indentSize: Int, sortKeys: Bool) throws -> String {
        guard let data = input.data(using: .utf8) else {
            throw ProcessError.invalidJSON
        }
        
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
            
            var options: JSONSerialization.WritingOptions = [.prettyPrinted]
            if sortKeys {
                options.insert(.sortedKeys)
            }
            if #available(macOS 13.0, *) {
                options.insert(.withoutEscapingSlashes)
            }
            
            let formattedData = try JSONSerialization.data(withJSONObject: jsonObject, options: options)
            guard var formatted = String(data: formattedData, encoding: .utf8) else {
                throw ProcessError.processingFailed("无法转换为字符串")
            }
            
            // Adjust indentation if needed
            if indentSize != 2 {
                let indent = indentSize == 1 ? "\t" : String(repeating: " ", count: indentSize)
                formatted = adjustIndentation(formatted, to: indent)
            }
            
            return formatted
        } catch {
            // 重新抛出更友好的错误信息
            if (error as NSError).domain == NSCocoaErrorDomain {
                throw ProcessError.invalidJSON
            }
            throw error
        }
    }
    
    private func minifyJSON(_ input: String) throws -> String {
        guard let data = input.data(using: .utf8) else {
            throw ProcessError.invalidJSON
        }
        
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
            
            var options: JSONSerialization.WritingOptions = []
            if #available(macOS 13.0, *) {
                options.insert(.withoutEscapingSlashes)
            }
            
            let minifiedData = try JSONSerialization.data(withJSONObject: jsonObject, options: options)
            guard let minified = String(data: minifiedData, encoding: .utf8) else {
                throw ProcessError.processingFailed("无法转换为字符串")
            }
            
            return minified
        } catch {
            // 重新抛出更友好的错误信息
            if (error as NSError).domain == NSCocoaErrorDomain {
                throw ProcessError.invalidJSON
            }
            throw error
        }
    }
    
    private func escapeString(_ input: String) -> String {
        var escaped = input
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
            .replacingOccurrences(of: "\u{8}", with: "\\b")
            .replacingOccurrences(of: "\u{12}", with: "\\f")
        
        // Handle Unicode characters
        var result = ""
        for scalar in escaped.unicodeScalars {
            if scalar.value > 127 {
                result += String(format: "\\u%04x", scalar.value)
            } else {
                result.append(Character(scalar))
            }
        }
        
        return result
    }
    
    private func unescapeString(_ input: String) throws -> String {
        // Try to parse as JSON string first
        if let data = "\"\(input)\"".data(using: .utf8),
           let unescaped = try? JSONSerialization.jsonObject(with: data) as? String {
            return unescaped
        }
        
        // Manual unescape as fallback
        var result = ""
        var iterator = input.makeIterator()
        
        while let char = iterator.next() {
            if char == "\\" {
                guard let next = iterator.next() else {
                    throw ProcessError.invalidEscapedString
                }
                
                switch next {
                case "n": result.append("\n")
                case "r": result.append("\r")
                case "t": result.append("\t")
                case "b": result.append("\u{8}")
                case "f": result.append("\u{12}")
                case "\"": result.append("\"")
                case "\\": result.append("\\")
                case "/": result.append("/")
                case "u":
                    // Handle Unicode escape
                    var hex = ""
                    for _ in 0..<4 {
                        guard let h = iterator.next() else {
                            throw ProcessError.invalidEscapedString
                        }
                        hex.append(h)
                    }
                    guard let code = Int(hex, radix: 16),
                          let scalar = Unicode.Scalar(code) else {
                        throw ProcessError.invalidEscapedString
                    }
                    result.append(Character(scalar))
                default:
                    result.append(next)
                }
            } else {
                result.append(char)
            }
        }
        
        return result
    }
    
    private func adjustIndentation(_ json: String, to indent: String) -> String {
        let lines = json.components(separatedBy: .newlines)
        return lines.map { line in
            guard let firstNonSpace = line.firstIndex(where: { !$0.isWhitespace }) else {
                return line
            }
            let spaces = line.distance(from: line.startIndex, to: firstNonSpace)
            let level = spaces / 2
            return String(repeating: indent, count: level) + line[firstNonSpace...]
        }.joined(separator: "\n")
    }
}
