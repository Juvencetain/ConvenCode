import SwiftUI
import AppKit

// Assume VisualEffectBlur is defined elsewhere and works
struct JSONFormatterView: View {
    // MARK: - State Properties
    @State private var inputText: String = ""
    @State private var formattedText: String = ""
    @State private var errorMessage: String?
    @State private var isResultFullscreen: Bool = false
    
    // MARK: - Constants
    private let defaultWidth: CGFloat = 420
    private let defaultHeight: CGFloat = 560
    private let fullscreenHeight: CGFloat = 800
    private let horizontalPadding: CGFloat = 20
    
    // MARK: - Body
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(0.95)
                .ignoresSafeArea()
                
            VStack(spacing: 0) {
                topBar
                
                // --- Main content stack ---
                VStack(spacing: 12) {
                    if !isResultFullscreen {
                        // **FIX: 让输入区域和下面的输出区域公平分配空间**
                        inputArea
                            .frame(maxHeight: formattedText.isEmpty ? .infinity : .none)
                            .transition(.opacity)
                    }
                        
                    if !formattedText.isEmpty {
                        resultArea
                    }
                    
                    // 在非全屏且有结果时，让结果区域占据剩余空间
                    if isResultFullscreen || (formattedText.isEmpty && !isResultFullscreen) {
                        Spacer(minLength: 0)
                    }
                }
                .padding(.top, 0) // 顶部内边距由 topBar 的 padding 控制
                // **FIX: 增加底部 padding 以保持整体美观**
                .padding(.bottom, 12)
            }
        }
        // ⭐ FIX 1: 动态调整 Frame。
        .frame(width: defaultWidth, height: isResultFullscreen ? fullscreenHeight : defaultHeight)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isResultFullscreen)
    }
    
    // --- Subviews ---
    
    private var topBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "curlybraces.square.fill")
                .font(.system(size: 16))
                .foregroundStyle(.orange.gradient)
            Text("JSON 格式化器")
                .font(.system(size: 14, weight: .medium))
            Spacer()
            if !formattedText.isEmpty {
                Button(action: copyResult) {
                    Image(systemName: "doc.on.doc")
                }.buttonStyle(.plain).help("复制结果")
                
                Button(action: openNewWindow) {
                    Image(systemName: "plus.square")
                }.buttonStyle(.plain).help("再开一个窗口")
                
                Button(action: { isResultFullscreen.toggle() }) {
                    Image(systemName: isResultFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.plain)
                .help(isResultFullscreen ? "缩小" : "放大")
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, 16)
    }
    
    // **FIX: 简化 inputArea，移除硬编码高度，让它更灵活。**
    private var inputArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("请输入 JSON 文本")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            // **FIX: 使用一个 min/max frame 确保它能被压缩或拉伸**
            TextEditor(text: $inputText)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 120) // Minimum visible height
                .frame(maxHeight: .infinity) // Allow it to expand to fill space
                .background(Color.white.opacity(0.15))
                .cornerRadius(10)
                
            HStack(spacing: 10) {
                Button("格式化", action: formatJSON).buttonStyle(.borderedProminent)
                Button("清空", action: clearAll).buttonStyle(.bordered)
                Spacer()
            }
            
            if let error = errorMessage {
                Text("❌ \(error)").foregroundColor(.red).font(.system(size: 12))
            }
        }
        .padding(.horizontal, horizontalPadding)
    }
    
    private var resultArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            // **FIX: 为结果区域添加标题**
            Text("格式化结果")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.horizontal, horizontalPadding)
            
            ScrollView {
                Text(colorizedJSON(formattedText))
                    .font(.system(.body, design: .monospaced))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            // ⭐ FIX 2: 关键的 frame 调整，确保结果区能占据剩余空间
            .frame(maxHeight: isResultFullscreen ? .infinity : .none)
            .padding(.horizontal, horizontalPadding)
        }
    }
    
    // --- Methods (Unchanged) ---
    
    private func formatJSON() {
        guard !inputText.isEmpty else {
            errorMessage = "请输入 JSON 文本"
            formattedText = ""
            return
        }
        errorMessage = nil
        do {
            let data = Data(inputText.utf8)
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
            let formattedData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys])
            formattedText = String(data: formattedData, encoding: .utf8) ?? ""
            // 如果结果很长，自动全屏
            if formattedText.count > 1000 {
                isResultFullscreen = true
            }
        } catch {
            errorMessage = "解析失败：\(error.localizedDescription)"
            formattedText = ""
        }
    }
    
    private func clearAll() {
        inputText = ""
        formattedText = ""
        errorMessage = nil
        isResultFullscreen = false
    }
    
    private func copyResult() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(formattedText, forType: .string)
    }
    
    private func openNewWindow() {
        let jsonView = JSONFormatterView()
        
        let hostingController = NSHostingController(rootView: jsonView)
        let window = NSWindow(contentViewController: hostingController)
        
        // ✅ 与 openIPLookup 完全一致的样式配置
        window.title = ""
        window.titlebarAppearsTransparent = true
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.setContentSize(NSSize(width: 420, height: 560))
        window.center()
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        
        NSApp.activate(ignoringOtherApps: true)
        }
    
    // The colorizedJSON method remains the same
    private func colorizedJSON(_ json: String) -> AttributedString {
        // ... (implementation of colorizedJSON remains the same)
        var attributedString = AttributedString(json)
        
        // Match keys
        if let keyRegex = try? NSRegularExpression(pattern: #"\"(.*?)\"\s*:"#) {
            keyRegex.enumerateMatches(in: json, range: NSRange(json.startIndex..., in: json)) { match, _, _ in
                guard let matchRange = match?.range(at: 1) else { return }
                if let range = Range(matchRange, in: json), let attrRange = Range(range, in: attributedString) {
                    attributedString[attrRange].foregroundColor = .cyan
                }
            }
        }
        
        // Match string values
        if let stringRegex = try? NSRegularExpression(pattern: #":\s*\"(.*?)\""#) {
            stringRegex.enumerateMatches(in: json, range: NSRange(json.startIndex..., in: json)) { match, _, _ in
                guard let matchRange = match?.range(at: 1) else { return }
                if let range = Range(matchRange, in: json), let attrRange = Range(range, in: attributedString) {
                    attributedString[attrRange].foregroundColor = .green
                }
            }
        }
        
        // Match numbers
        if let numberRegex = try? NSRegularExpression(pattern: #":\s*(-?\d+(\.\d+)?([eE][+-]?\d+)?)"#) {
            numberRegex.enumerateMatches(in: json, range: NSRange(json.startIndex..., in: json)) { match, _, _ in
                guard let matchRange = match?.range(at: 1) else { return }
                if let range = Range(matchRange, in: json), let attrRange = Range(range, in: attributedString) {
                    attributedString[attrRange].foregroundColor = .orange
                }
            }
        }
        
        // Match booleans (true/false) and null
        if let keywordRegex = try? NSRegularExpression(pattern: #"\b(true|false|null)\b"#) {
            keywordRegex.enumerateMatches(in: json, range: NSRange(json.startIndex..., in: json)) { match, _, _ in
                guard let matchRange = match?.range else { return }
                if let range = Range(matchRange, in: json), let attrRange = Range(range, in: attributedString) {
                    attributedString[attrRange].foregroundColor = .purple
                }
            }
        }
        
        return attributedString
    }
}
