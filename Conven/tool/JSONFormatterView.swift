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
    @State private var selectedMode: JSONMode = .format
    @State private var showSuccessToast = false
    @State private var indentSize = 2
    @State private var sortKeys = true
    @State private var showSettings = false
    @State private var wrapText = true  // 是否自动换行
    
    // MARK: - Layout Constants
    private enum Layout {
        static let width: CGFloat = 1200  // 固定大宽度
        static let height: CGFloat = 800  // 固定高度
        static let padding: CGFloat = 24
        static let spacing: CGFloat = 16
        static let radius: CGFloat = 12
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerBar
                Divider()
                    .padding(.horizontal, Layout.padding)
                    .padding(.vertical, 8)
                contentArea
            }
        }
        .frame(width: Layout.width, height: Layout.height)
        .overlay(alignment: .top) {
            if showSuccessToast {
                toastView
            }
        }
    }
    
    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "curlybraces.square.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.orange.gradient)
                VStack(alignment: .leading, spacing: 2) {
                    Text("JSON 工具箱")
                        .font(.system(size: 16, weight: .semibold))
                    Text("格式化 · 压缩 · 转义")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 10) {
                if !outputText.isEmpty {
                    ToolbarButton(icon: "doc.on.doc", label: "复制", tooltip: "复制结果到剪贴板") {
                        copyToClipboard(outputText)
                        showSuccessToast = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showSuccessToast = false
                        }
                    }
                    
                    ToolbarButton(icon: "arrow.2.squarepath", label: "交换", tooltip: "交换输入输出内容") {
                        swapInputOutput()
                    }
                }
                
                ToolbarButton(icon: "gearshape", label: "设置", tooltip: "显示设置选项", isActive: showSettings) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showSettings.toggle()
                    }
                }
                
                ToolbarButton(icon: "plus.square", label: "新窗口", tooltip: "打开新的工具窗口") {
                    openNewWindow()
                }
            }
        }
        .padding(.horizontal, Layout.padding)
        .padding(.vertical, 18)
    }
    
    // MARK: - Content Area
    private var contentArea: some View {
        HStack(spacing: Layout.spacing) {
            // 左侧：输入区域
            inputSection
                .frame(maxWidth: .infinity)
            
            // 右侧：输出区域（如果有内容）
            if !outputText.isEmpty {
                outputSection
                    .frame(maxWidth: .infinity)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(Layout.padding)
    }
    
    // MARK: - Input Section
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("输入内容")
                        .font(.system(size: 13, weight: .semibold))
                    Text(inputText.isEmpty ? "粘贴或输入 JSON 数据" : "\(inputText.count) 字符")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            inputEditor
            
            controlPanel
            
            if let error = errorMessage {
                ErrorBanner(message: error)
            }
        }
    }
    
    private var inputEditor: some View {
        ZStack(alignment: .topLeading) {
            if inputText.isEmpty {
                Text("粘贴或输入 JSON 数据...")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.5))
                    .padding(12)
                    .allowsHitTesting(false)
            }
            
            TextEditor(text: $inputText)
                .font(.system(size: 13, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(maxHeight: .infinity)
                .onChange(of: inputText) { _ in
                    errorMessage = nil
                }
        }
        .frame(minHeight: 200)
        .background(
            RoundedRectangle(cornerRadius: Layout.radius)
                .fill(Color.primary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Layout.radius)
                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
        )
    }
    
    private var controlPanel: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                modeSelectorButton
                Spacer()
                
                Button {
                    processJSON()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                        Text("执行")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .frame(minWidth: 80)
                }
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut(.return, modifiers: .command)
                
                Button {
                    clearAll()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text("清空")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .frame(minWidth: 80)
                }
                .buttonStyle(SecondaryButtonStyle())
                .keyboardShortcut("k", modifiers: .command)
            }
            
            if showSettings && selectedMode == .format {
                settingsPanel
                    .transition(.opacity)
            }
        }
    }
    
    private var modeSelectorButton: some View {
        Menu {
            ForEach(JSONMode.allCases, id: \.self) { mode in
                Button {
                    selectedMode = mode
                    if mode != .format {
                        showSettings = false
                    }
                } label: {
                    HStack {
                        Image(systemName: mode.icon)
                        Text(mode.rawValue)
                        if selectedMode == mode {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: selectedMode.icon)
                    .font(.system(size: 14))
                Text(selectedMode.rawValue)
                    .font(.system(size: 13, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .menuStyle(.borderlessButton)
        .help(selectedMode.tooltip)
    }
    
    private var settingsPanel: some View {
        HStack(spacing: 20) {
            HStack(spacing: 8) {
                Text("缩进:")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Picker("", selection: $indentSize) {
                    Text("2 空格").tag(2)
                    Text("4 空格").tag(4)
                    Text("Tab").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            
            Spacer()
            
            Toggle(isOn: $sortKeys) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 11))
                    Text("按键排序")
                        .font(.system(size: 12))
                }
            }
            .toggleStyle(.checkbox)
            .help("按字母顺序排序对象键")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.05))
        )
    }
    
    // MARK: - Output Section
    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("处理结果")
                        .font(.system(size: 13, weight: .semibold))
                    Text("\(outputText.count) 字符")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    SmallActionButton(icon: "doc.on.doc", tooltip: "复制结果") {
                        copyToClipboard(outputText)
                        showSuccessToast = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showSuccessToast = false
                        }
                    }
                    
                    SmallActionButton(
                        icon: wrapText ? "arrow.turn.down.left" : "arrow.right.to.line",
                        tooltip: wrapText ? "禁用自动换行" : "启用自动换行"
                    ) {
                        wrapText.toggle()
                    }
                    
                    SmallActionButton(icon: "arrow.clockwise", tooltip: "重新处理") {
                        processJSON()
                    }
                }
            }
            
            outputViewer
        }
    }
    
    private var outputViewer: some View {
        ScrollView(wrapText ? .vertical : [.horizontal, .vertical]) {
            Text(selectedMode == .format ? colorizedJSON(outputText) : AttributedString(outputText))
                .font(.system(size: 13, design: .monospaced))
                .padding(16)
                .frame(maxWidth: wrapText ? .infinity : nil, alignment: .topLeading)
                .textSelection(.enabled)
                .fixedSize(horizontal: !wrapText, vertical: true)
        }
        .background(
            RoundedRectangle(cornerRadius: Layout.radius)
                .fill(Color.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Layout.radius)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Toast View
    private var toastView: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
            Text("已复制到剪贴板")
                .font(.system(size: 13, weight: .medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.green.opacity(0.9))
        )
        .foregroundColor(.white)
        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
        .padding(.top, 80)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // MARK: - Actions
    private func processJSON() {
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedInput.isEmpty else {
            errorMessage = "请输入内容"
            outputText = ""
            return
        }
        
        do {
            switch selectedMode {
            case .format:
                outputText = try formatJSON(trimmedInput, indentSize: indentSize, sortKeys: sortKeys)
            case .minify:
                outputText = try minifyJSON(trimmedInput)
            case .escape:
                outputText = escapeString(trimmedInput)
            case .unescape:
                outputText = try unescapeString(trimmedInput)
            }
            
            errorMessage = nil
        } catch {
            if let nsError = error as NSError? {
                if nsError.domain == NSCocoaErrorDomain {
                    switch nsError.code {
                    case 3840:
                        errorMessage = "JSON 格式错误：请检查括号、引号是否匹配"
                    case 3841:
                        errorMessage = "JSON 格式错误：意外的结束"
                    default:
                        errorMessage = "JSON 解析失败：\(nsError.localizedDescription)"
                    }
                } else {
                    errorMessage = "处理失败：\(nsError.localizedDescription)"
                }
            } else {
                errorMessage = "未知错误：\(error.localizedDescription)"
            }
            outputText = ""
        }
    }
    
    private func clearAll() {
        inputText = ""
        outputText = ""
        errorMessage = nil
        showSettings = false
    }
    
    private func swapInputOutput() {
        guard !outputText.isEmpty else { return }
        
        let temp = outputText
        
        switch selectedMode {
        case .format, .minify:
            inputText = temp
            outputText = ""
        case .escape, .unescape:
            inputText = temp
            outputText = ""
            selectedMode = (selectedMode == .escape) ? .unescape : .escape
        }
        
        errorMessage = nil
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
        window.setContentSize(NSSize(width: Layout.width, height: Layout.height))
        window.center()
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // MARK: - JSON Processing Methods
    private func formatJSON(_ input: String, indentSize: Int, sortKeys: Bool) throws -> String {
        guard let data = input.data(using: .utf8) else {
            throw NSError(domain: "JSONFormatter", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的 JSON 格式"])
        }
        
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
            throw NSError(domain: "JSONFormatter", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法转换为字符串"])
        }
        
        if indentSize != 2 {
            let indent = indentSize == 1 ? "\t" : String(repeating: " ", count: indentSize)
            formatted = adjustIndentation(formatted, to: indent)
        }
        
        return formatted
    }
    
    private func minifyJSON(_ input: String) throws -> String {
        guard let data = input.data(using: .utf8) else {
            throw NSError(domain: "JSONFormatter", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的 JSON 格式"])
        }
        
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
        
        var options: JSONSerialization.WritingOptions = []
        if #available(macOS 13.0, *) {
            options.insert(.withoutEscapingSlashes)
        }
        
        let minifiedData = try JSONSerialization.data(withJSONObject: jsonObject, options: options)
        guard let minified = String(data: minifiedData, encoding: .utf8) else {
            throw NSError(domain: "JSONFormatter", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法转换为字符串"])
        }
        
        return minified
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
        if let data = "\"\(input)\"".data(using: .utf8),
           let unescaped = try? JSONSerialization.jsonObject(with: data) as? String {
            return unescaped
        }
        
        var result = ""
        var iterator = input.makeIterator()
        
        while let char = iterator.next() {
            if char == "\\" {
                guard let next = iterator.next() else {
                    throw NSError(domain: "JSONFormatter", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的转义字符串"])
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
                    var hex = ""
                    for _ in 0..<4 {
                        guard let h = iterator.next() else {
                            throw NSError(domain: "JSONFormatter", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的转义字符串"])
                        }
                        hex.append(h)
                    }
                    guard let code = Int(hex, radix: 16),
                          let scalar = Unicode.Scalar(code) else {
                        throw NSError(domain: "JSONFormatter", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的转义字符串"])
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
    
    // MARK: - Syntax Highlighting
    private func colorizedJSON(_ json: String) -> AttributedString {
        var attributed = AttributedString(json)
        let nsString = json as NSString
        
        let colors = (
            key: Color.cyan,
            string: Color.green,
            number: Color.orange,
            keyword: Color.purple
        )
        
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

struct ToolbarButton: View {
    let icon: String
    let label: String
    let tooltip: String
    var isActive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(label)
                    .font(.system(size: 9))
            }
            .frame(width: 60, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? Color.accentColor.opacity(0.2) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}

struct SmallActionButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}

struct ErrorBanner: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
            Text(message)
                .font(.system(size: 12))
            Spacer()
        }
        .foregroundColor(.white)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.red.opacity(0.8))
        )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color.accentColor.opacity(configuration.isPressed ? 0.7 : 1.0))
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color.primary.opacity(configuration.isPressed ? 0.15 : 0.1))
            .foregroundColor(.primary)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
    }
}
