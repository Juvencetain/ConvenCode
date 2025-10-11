import SwiftUI
import AppKit
import CryptoKit

// MARK: - 通用按钮样式优化
struct ModernButtonStyle: ButtonStyle {
    var style: ButtonStyleType = .normal
    
    enum ButtonStyleType {
        case normal, accent, execute, danger
    }
    
    func makeBody(configuration: Configuration) -> some View {
        let colors = getColors(for: style, pressed: configuration.isPressed)
        
        return configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.vertical, 7)
            .padding(.horizontal, 14)
            .background(colors.background)
            .foregroundColor(colors.foreground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(colors.border, lineWidth: style == .execute ? 0 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
            .cursor(.pointingHand)
    }
    
    private func getColors(for style: ButtonStyleType, pressed: Bool) -> (background: Color, foreground: Color, border: Color) {
        switch style {
        case .normal:
            return (
                Color.white.opacity(pressed ? 0.15 : 0.1),
                Color.primary,
                Color.primary.opacity(pressed ? 0.4 : 0.25)
            )
        case .accent:
            return (
                Color.accentColor.opacity(0.2),
                Color.accentColor,
                Color.accentColor.opacity(pressed ? 0.6 : 0.4)
            )
        case .execute:
            return (
                Color.accentColor,
                Color.white,
                Color.clear
            )
        case .danger:
            return (
                Color.red.opacity(0.15),
                Color.red.opacity(0.85),
                Color.red.opacity(pressed ? 0.4 : 0.25)
            )
        }
    }
}

// MARK: - SHA256 扩展
extension String {
    func sha256() -> String {
        guard let data = self.data(using: .utf8) else { return "Hashing Error" }
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - 现代化文本编辑区域
struct ModernTextArea: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let isEditable: Bool
    let minHeight: CGFloat
    
    init(title: String, text: Binding<String>, placeholder: String = "", isEditable: Bool = true, minHeight: CGFloat = 120) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.isEditable = isEditable
        self.minHeight = minHeight
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
                if !isEditable && !text.isEmpty {
                    Spacer()
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10))
                            Text("复制")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isEditable ? Color.white.opacity(0.15) : Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                
                if text.isEmpty && isEditable {
                    Text(placeholder)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.5))
                        .padding(12)
                        .allowsHitTesting(false)
                }
                
                TextEditor(text: $text)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .allowsHitTesting(isEditable)
                    .textSelection(.enabled)
            }
            .frame(minHeight: minHeight, maxHeight: .infinity)
        }
    }
}

// MARK: - 统一的处理器视图
struct UnifiedProcessorView: View {
    @Binding var inputText: String
    @Binding var outputText: String
    @Binding var isEncoding: Bool
    let mode: ProcessMode
    let executeAction: () -> Void
    
    enum ProcessMode {
        case base64, url
        
        var title: (encode: String, decode: String) {
            switch self {
            case .base64: return ("文本 → Base64", "Base64 → 文本")
            case .url: return ("文本 → URL", "URL → 文本")
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 模式切换按钮
            HStack(spacing: 10) {
                Button(mode.title.encode) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isEncoding = true
                        outputText = ""
                    }
                }
                .buttonStyle(ModernButtonStyle(style: isEncoding ? .accent : .normal))
                
                Button(mode.title.decode) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isEncoding = false
                        outputText = ""
                    }
                }
                .buttonStyle(ModernButtonStyle(style: !isEncoding ? .accent : .normal))
            }
            
            // 输入区域
            ModernTextArea(
                title: "输入内容",
                text: $inputText,
                placeholder: isEncoding ? "输入要编码的文本..." : "输入要解码的内容..."
            )
            
            // 操作按钮组
            HStack(spacing: 8) {
                Button(action: executeAction) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                        Text("执行转换")
                    }
                }
                .buttonStyle(ModernButtonStyle(style: .execute))
                .disabled(inputText.isEmpty)
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        swap(&inputText, &outputText)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 11))
                        Text("互换")
                    }
                }
                .buttonStyle(ModernButtonStyle())
                .disabled(outputText.isEmpty)
                
                Spacer()
                
                Button(action: {
                    inputText = ""
                    outputText = ""
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(ModernButtonStyle(style: .danger))
                .disabled(inputText.isEmpty && outputText.isEmpty)
            }
            
            // 输出区域
            ModernTextArea(
                title: "转换结果",
                text: $outputText,
                placeholder: "结果将在这里显示...",
                isEditable: false
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Base64 转换视图
struct Base64ConverterView: View {
    @Binding var inputText: String
    @Binding var outputText: String
    @Binding var isEncoding: Bool
    
    func convert() {
        if isEncoding {
            guard let data = inputText.data(using: .utf8) else {
                outputText = "编码失败：输入文本无效"
                return
            }
            outputText = data.base64EncodedString()
        } else {
            guard let data = Data(base64Encoded: inputText),
                  let string = String(data: data, encoding: .utf8) else {
                outputText = "解码失败：Base64 格式无效"
                return
            }
            outputText = string
        }
    }
    
    var body: some View {
        UnifiedProcessorView(
            inputText: $inputText,
            outputText: $outputText,
            isEncoding: $isEncoding,
            mode: .base64,
            executeAction: convert
        )
    }
}

// MARK: - URL 转换视图
struct URLConverterView: View {
    @Binding var inputText: String
    @Binding var outputText: String
    @Binding var isEncoding: Bool
    
    func convert() {
        if isEncoding {
            outputText = inputText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "URL 编码失败"
        } else {
            outputText = inputText.removingPercentEncoding ?? "URL 解码失败"
        }
    }
    
    var body: some View {
        UnifiedProcessorView(
            inputText: $inputText,
            outputText: $outputText,
            isEncoding: $isEncoding,
            mode: .url,
            executeAction: convert
        )
    }
}

// MARK: - 时间戳转换视图
struct TimestampConverterView: View {
    @State private var inputData: String = ""
    @State private var outputData: String = ""
    @State private var selectedUnit: TimeUnit = .seconds
    @State private var lastConvertedTimestamp: String = "" // 记录上次转换的时间戳
    
    enum TimeUnit: String, CaseIterable, Identifiable {
        case seconds = "秒 (s)"
        case milliseconds = "毫秒 (ms)"
        var id: Self { self }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 工具栏
            HStack(spacing: 10) {
                Button(action: getCurrentTimestamp) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 11))
                        Text("当前时间戳")
                    }
                }
                .buttonStyle(ModernButtonStyle(style: .accent))
                
                Picker("单位", selection: $selectedUnit) {
                    ForEach(TimeUnit.allCases) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                .onChange(of: selectedUnit) { newUnit in
                    handleUnitChange(newUnit)
                }
            }
            
            // 输入区域
            ModernTextArea(
                title: "输入数据",
                text: $inputData,
                placeholder: "输入时间戳或日期 (YYYY-MM-DD HH:MM:SS)...",
                minHeight: 100
            )
            
            // 转换按钮
            HStack(spacing: 8) {
                Button(action: autoConvert) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left.arrow.right.circle.fill")
                            .font(.system(size: 11))
                        Text("智能转换")
                    }
                }
                .buttonStyle(ModernButtonStyle(style: .execute))
                .disabled(inputData.isEmpty)
                
                Button(action: timestampToDate) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                        Text("→ 日期")
                            .font(.system(size: 11))
                    }
                }
                .buttonStyle(ModernButtonStyle())
                .disabled(inputData.isEmpty)
                
                Button(action: dateToTimestamp) {
                    HStack(spacing: 6) {
                        Image(systemName: "number")
                            .font(.system(size: 10))
                        Text("→ 时间戳")
                            .font(.system(size: 11))
                    }
                }
                .buttonStyle(ModernButtonStyle())
                .disabled(inputData.isEmpty)
                
                Spacer()
                
                Button(action: {
                    inputData = ""
                    outputData = ""
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(ModernButtonStyle(style: .danger))
                .disabled(inputData.isEmpty && outputData.isEmpty)
            }
            
            // 输出区域
            ModernTextArea(
                title: "转换结果",
                text: $outputData,
                placeholder: "转换结果将在这里显示...",
                isEditable: false,
                minHeight: 100
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    private func timestampToDate() {
        let trimmed = inputData.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let ts = Double(trimmed), !trimmed.isEmpty else {
            outputData = "格式错误：请输入有效的数字时间戳"
            return
        }
        
        let timeInterval: TimeInterval = (selectedUnit == .milliseconds) ? (ts / 1000.0) : ts
        let date = Date(timeIntervalSince1970: timeInterval)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone.current
        outputData = "\(formatter.string(from: date)) (本地时区)"
    }
    
    private func dateToTimestamp() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone.current
        
        guard let date = formatter.date(from: inputData.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            outputData = "格式错误：请使用 YYYY-MM-DD HH:MM:SS 格式"
            return
        }
        
        let ts = date.timeIntervalSince1970
        let formattedTs = selectedUnit == .milliseconds ? String(Int(ts * 1000)) : String(Int(ts))
        outputData = formattedTs
    }
    
    private func handleUnitChange(_ newUnit: TimeUnit) {
        // 如果输入框有时间戳数据，自动转换单位
        let trimmed = inputData.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let currentValue = Double(trimmed),
              !trimmed.contains("-"),
              !trimmed.contains(":"),
              !trimmed.isEmpty else {
            return
        }
        
        // 转换时间戳单位
        if newUnit == .milliseconds {
            // 秒 → 毫秒
            inputData = String(Int(currentValue * 1000))
        } else {
            // 毫秒 → 秒
            inputData = String(Int(currentValue / 1000))
        }
        
        // 如果之前有输出结果，自动重新转换
        if !outputData.isEmpty {
            autoConvert()
        }
    }
    
    private func autoConvert() {
        let trimmed = inputData.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 判断是否为纯数字（时间戳）
        if let _ = Double(trimmed), !trimmed.contains("-") && !trimmed.contains(":") {
            lastConvertedTimestamp = trimmed
            timestampToDate()
        } else {
            // 否则当作日期处理
            dateToTimestamp()
        }
    }
    
    private func getCurrentTimestamp() {
        let ts = Date().timeIntervalSince1970
        inputData = selectedUnit == .milliseconds ? String(Int(ts * 1000)) : String(Int(ts))
        autoConvert()
    }
}

// MARK: - 哈希转换视图
struct HashConverterView: View {
    @Binding var inputText: String
    @Binding var outputText: String
    
    func hash() {
        guard !inputText.isEmpty else {
            outputText = "请输入要计算哈希的文本"
            return
        }
        outputText = inputText.sha256()
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 提示信息
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.green.gradient)
                
                Text("使用 SHA-256 算法计算哈希值")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 16) {
                // 输入区域
                ModernTextArea(
                    title: "输入文本",
                    text: $inputText,
                    placeholder: "输入要计算哈希的文本..."
                )
                
                // 操作按钮
                HStack(spacing: 8) {
                    Button(action: hash) {
                        HStack(spacing: 6) {
                            Image(systemName: "number.square.fill")
                                .font(.system(size: 11))
                            Text("计算哈希")
                        }
                    }
                    .buttonStyle(ModernButtonStyle(style: .execute))
                    .disabled(inputText.isEmpty)
                    
                    Spacer()
                    
                    Button(action: {
                        inputText = ""
                        outputText = ""
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(ModernButtonStyle(style: .danger))
                    .disabled(inputText.isEmpty && outputText.isEmpty)
                }
                
                // 输出区域
                ModernTextArea(
                    title: "SHA-256 哈希值",
                    text: $outputText,
                    placeholder: "哈希结果将在这里显示...",
                    isEditable: false
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - 主数据处理视图
struct DataProcessorView: View {
    @State private var inputText: String = ""
    @State private var outputText: String = ""
    @State private var selectedTool: DataTool = .base64
    @State private var isBase64Encoding: Bool = true
    @State private var isURLEncoding: Bool = true
    
    enum DataTool: String, CaseIterable, Identifiable {
        case base64 = "Base64"
        case url = "URL"
        case timestamp = "时间戳"
        case hash = "SHA-256"
        
        var id: Self { self }
        
        var icon: String {
            switch self {
            case .base64: return "textformat.123"
            case .url: return "link"
            case .timestamp: return "clock"
            case .hash: return "number.square"
            }
        }
    }
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 标题栏
                HStack(spacing: 12) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue.gradient)
                    
                    Text("数据处理工具")
                        .font(.system(size: 14, weight: .medium))
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                // 工具选择器
                Picker("功能", selection: $selectedTool) {
                    ForEach(DataTool.allCases) { tool in
                        Label(tool.rawValue, systemImage: tool.icon)
                            .tag(tool)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                
                Divider()
                    .padding(.horizontal, 16)
                
                // 内容区域
                ScrollView(showsIndicators: false) {
                    Group {
                        switch selectedTool {
                        case .base64:
                            Base64ConverterView(
                                inputText: $inputText,
                                outputText: $outputText,
                                isEncoding: $isBase64Encoding
                            )
                        case .url:
                            URLConverterView(
                                inputText: $inputText,
                                outputText: $outputText,
                                isEncoding: $isURLEncoding
                            )
                        case .timestamp:
                            TimestampConverterView()
                        case .hash:
                            HashConverterView(
                                inputText: $inputText,
                                outputText: $outputText
                            )
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
        }
        .frame(width: 420, height: 560)
        .onChange(of: selectedTool) { _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if selectedTool != .timestamp {
                    inputText = ""
                    outputText = ""
                }
            }
        }
    }
}

#Preview {
    DataProcessorView()
}
