import SwiftUI

// MARK: - Text Processor View
struct TextProcessorView: View {
    @StateObject private var textProcessorVM = TextProcessorViewModel()
    @State private var textProcessorSelectedTab: TextProcessorTab = .statistics
    @State private var textProcessorWindowExpanded = false
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                textProcessorHeaderSection
                Divider().padding(.horizontal, 16)
                
                textProcessorTabBar
                
                ScrollView {
                    VStack(spacing: 16) {
                        textProcessorContentView
                    }
                    .padding(20)
                }
            }
        }
        .focusable(false)
        .frame(
            minWidth: 800,
            idealWidth: textProcessorWindowExpanded ? 1200 : 800,
            maxWidth: .infinity,
            minHeight: 600,
            idealHeight: textProcessorWindowExpanded ? 800 : 600,
            maxHeight: .infinity
        )
    }
    
    // MARK: - Header Section
    private var textProcessorHeaderSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "text.quote")
                .font(.system(size: 16))
                .foregroundStyle(.green.gradient)
            
            Text("文本处理工具")
                .font(.system(size: 14, weight: .medium))
            
            Spacer()
            
            // 窗口控制按钮
            if textProcessorSelectedTab == .diff {
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        textProcessorWindowExpanded.toggle()
                        textProcessorVM.textProcessorWindowExpanded = textProcessorWindowExpanded
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: textProcessorWindowExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 11))
                        Text(textProcessorWindowExpanded ? "缩小" : "放大")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help(textProcessorWindowExpanded ? "缩小窗口" : "放大窗口")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Tab Bar
    private var textProcessorTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TextProcessorTab.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            textProcessorSelectedTab = tab
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 12))
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(textProcessorSelectedTab == tab ? Color.green.opacity(0.2) : Color.white.opacity(0.05))
                        )
                        .foregroundColor(textProcessorSelectedTab == tab ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Content View
    @ViewBuilder
    private var textProcessorContentView: some View {
        switch textProcessorSelectedTab {
        case .statistics:
            TextProcessorStatisticsView(viewModel: textProcessorVM)
        case .diff:
            TextProcessorDiffView(viewModel: textProcessorVM)
        case .caseConversion:
            TextProcessorCaseView(viewModel: textProcessorVM)
        case .sortDedupe:
            TextProcessorSortView(viewModel: textProcessorVM)
        case .findReplace:
            TextProcessorFindReplaceView(viewModel: textProcessorVM)
        case .charInfo:
            TextProcessorCharInfoView(viewModel: textProcessorVM)
        }
    }
}

// MARK: - Statistics View
struct TextProcessorStatisticsView: View {
    @ObservedObject var viewModel: TextProcessorViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("字数统计")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            
            ZStack(alignment: .topLeading) {
                // 透明背景边框
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.clear)
                    )
                
                TextEditor(text: $viewModel.textProcessorStatsInput)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(8)
            }
            .frame(height: 250)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                TextProcessorStatCard(
                    icon: "textformat.abc",
                    label: "字符数",
                    value: "\(viewModel.textProcessorCharCount)",
                    color: .blue
                )
                TextProcessorStatCard(
                    icon: "text.word.spacing",
                    label: "词数",
                    value: "\(viewModel.textProcessorWordCount)",
                    color: .purple
                )
                TextProcessorStatCard(
                    icon: "text.alignleft",
                    label: "行数",
                    value: "\(viewModel.textProcessorLineCount)",
                    color: .orange
                )
                TextProcessorStatCard(
                    icon: "text.justify",
                    label: "段落数",
                    value: "\(viewModel.textProcessorParagraphCount)",
                    color: .green
                )
            }
            
            Button(action: { viewModel.textProcessorStatsInput = "" }) {
                HStack {
                    Image(systemName: "trash")
                    Text("清空")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.2))
                .foregroundColor(.red)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Diff View (IDEA-style Inline)
struct TextProcessorDiffView: View {
    @ObservedObject var viewModel: TextProcessorViewModel
    @State private var textProcessorScrollOffset: CGFloat = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("文本差异对比")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if viewModel.textProcessorDiffEnabled {
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(red: 0.4, green: 0.15, blue: 0.15, opacity: 0.5))
                                .frame(width: 12, height: 8)
                            Text("删除")
                                .font(.system(size: 10))
                        }
                        
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(red: 0.15, green: 0.35, blue: 0.2, opacity: 0.5))
                                .frame(width: 12, height: 8)
                            Text("新增")
                                .font(.system(size: 10))
                        }
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            // IDEA 风格的并排输入框与差异显示
            HStack(spacing: 12) {
                // 左侧：原文本
                VStack(alignment: .leading, spacing: 8) {
                    Text("原文本")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                        
                        if viewModel.textProcessorDiffEnabled && !viewModel.textProcessorDiffPairs.isEmpty {
                            // 差异高亮显示模式 - 同步滚动
                            ScrollViewReader { proxy in
                                ScrollView {
                                    VStack(spacing: 0) {
                                        ForEach(Array(viewModel.textProcessorDiffPairs.enumerated()), id: \.offset) { index, pair in
                                            TextProcessorInlineDiffLineView(
                                                content: pair.leftContent,
                                                type: pair.leftType,
                                                isEmpty: pair.leftContent.isEmpty
                                            )
                                            .id("left-\(index)")
                                        }
                                    }
                                    .background(
                                        GeometryReader { geo in
                                            Color.clear.preference(
                                                key: TextProcessorScrollPreferenceKey.self,
                                                value: geo.frame(in: .named("leftScroll")).minY
                                            )
                                        }
                                    )
                                }
                                .coordinateSpace(name: "leftScroll")
                                .onPreferenceChange(TextProcessorScrollPreferenceKey.self) { value in
                                    textProcessorScrollOffset = value
                                }
                            }
                        } else {
                            // 普通编辑模式
                            TextEditor(text: $viewModel.textProcessorDiffText1)
                                .font(.system(size: 11, design: .monospaced))
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                                .padding(8)
                                .onChange(of: viewModel.textProcessorDiffText1) { _ in
                                    viewModel.textProcessorDisableDiff()
                                }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                
                // 右侧：对比文本
                VStack(alignment: .leading, spacing: 8) {
                    Text("对比文本")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                        
                        if viewModel.textProcessorDiffEnabled && !viewModel.textProcessorDiffPairs.isEmpty {
                            // 差异高亮显示模式 - 同步滚动
                            SyncedScrollView(offset: $textProcessorScrollOffset) {
                                VStack(spacing: 0) {
                                    ForEach(Array(viewModel.textProcessorDiffPairs.enumerated()), id: \.offset) { index, pair in
                                        TextProcessorInlineDiffLineView(
                                            content: pair.rightContent,
                                            type: pair.rightType,
                                            isEmpty: pair.rightContent.isEmpty
                                        )
                                        .id("right-\(index)")
                                    }
                                }
                            }
                        } else {
                            // 普通编辑模式
                            TextEditor(text: $viewModel.textProcessorDiffText2)
                                .font(.system(size: 11, design: .monospaced))
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                                .padding(8)
                                .onChange(of: viewModel.textProcessorDiffText2) { _ in
                                    viewModel.textProcessorDisableDiff()
                                }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: viewModel.textProcessorWindowExpanded ? 650 : 450)
            .animation(.spring(response: 0.3), value: viewModel.textProcessorWindowExpanded)
            
            Button(action: {
                if viewModel.textProcessorDiffEnabled {
                    viewModel.textProcessorDisableDiff()
                } else {
                    viewModel.textProcessorCompareDiff()
                }
            }) {
                HStack {
                    Image(systemName: viewModel.textProcessorDiffEnabled ? "xmark.circle" : "arrow.left.arrow.right")
                    Text(viewModel.textProcessorDiffEnabled ? "退出对比" : "对比差异")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(viewModel.textProcessorDiffEnabled ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                .foregroundColor(viewModel.textProcessorDiffEnabled ? .red : .blue)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Scroll Preference Key
struct TextProcessorScrollPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Synced ScrollView
struct SyncedScrollView<Content: View>: View {
    @Binding var offset: CGFloat
    let content: Content
    
    init(offset: Binding<CGFloat>, @ViewBuilder content: () -> Content) {
        self._offset = offset
        self.content = content()
    }
    
    var body: some View {
        ScrollView {
            content
                .offset(y: offset)
        }
    }
}

// MARK: - Inline Diff Line View
struct TextProcessorInlineDiffLineView: View {
    let content: String
    let type: TextProcessorDiffLineType
    let isEmpty: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            Text(isEmpty ? " " : content)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 3)
                .padding(.horizontal, 8)
                .lineLimit(1)
        }
        .frame(height: 18)
        .background(backgroundColor)
    }
    
    private var backgroundColor: Color {
        if isEmpty {
            return Color.clear
        }
        switch type {
        case .unchanged:
            return Color.clear
        case .deleted:
            return Color(red: 0.4, green: 0.15, blue: 0.15, opacity: 0.5)
        case .added:
            return Color(red: 0.15, green: 0.35, blue: 0.2, opacity: 0.5)
        }
    }
    
    private var textColor: Color {
        if isEmpty {
            return Color.clear
        }
        switch type {
        case .unchanged:
            return Color.primary.opacity(0.8)
        case .deleted:
            return Color(red: 1.0, green: 0.6, blue: 0.6)
        case .added:
            return Color(red: 0.6, green: 1.0, blue: 0.7)
        }
    }
}

// MARK: - IDEA Style Diff Line View
struct TextProcessorIDEADiffLineView: View {
    let lineNumber: String
    let content: String
    let type: TextProcessorDiffLineType
    let isLeft: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            Text(content.isEmpty ? " " : content)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 3)
                .padding(.horizontal, 8)
                .lineLimit(1)
        }
        .frame(height: 20)
        .background(backgroundColor)
    }
    
    private var backgroundColor: Color {
        switch type {
        case .unchanged:
            return Color.clear
        case .deleted:
            return Color(red: 0.4, green: 0.15, blue: 0.15, opacity: 0.5)
        case .added:
            return Color(red: 0.15, green: 0.35, blue: 0.2, opacity: 0.5)
        }
    }
    
    private var textColor: Color {
        switch type {
        case .unchanged:
            return Color.primary.opacity(0.8)
        case .deleted:
            return Color(red: 1.0, green: 0.6, blue: 0.6)
        case .added:
            return Color(red: 0.6, green: 1.0, blue: 0.7)
        }
    }
}

// MARK: - Line Number View
struct TextProcessorLineNumberView: View {
    let leftNumber: String
    let rightNumber: String
    let hasChange: Bool
    
    var body: some View {
        HStack(spacing: 3) {
            Text(leftNumber)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(hasChange ? Color(red: 1.0, green: 0.6, blue: 0.6) : .secondary)
                .frame(width: 28, alignment: .trailing)
            
            Rectangle()
                .fill(hasChange ? Color.blue.opacity(0.4) : Color.white.opacity(0.1))
                .frame(width: 2)
            
            Text(rightNumber)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(hasChange ? Color(red: 0.6, green: 1.0, blue: 0.7) : .secondary)
                .frame(width: 28, alignment: .leading)
        }
        .frame(height: 18)
        .padding(.horizontal, 2)
    }
}

// MARK: - Case Conversion View
struct TextProcessorCaseView: View {
    @ObservedObject var viewModel: TextProcessorViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("大小写转换")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                
                TextEditor(text: $viewModel.textProcessorCaseInput)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(8)
            }
            .frame(height: 150)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                TextProcessorActionButton(
                    icon: "textformat.size.larger",
                    label: "全大写",
                    color: .blue
                ) {
                    viewModel.textProcessorConvertCase(.uppercase)
                }
                
                TextProcessorActionButton(
                    icon: "textformat.size.smaller",
                    label: "全小写",
                    color: .purple
                ) {
                    viewModel.textProcessorConvertCase(.lowercase)
                }
                
                TextProcessorActionButton(
                    icon: "textformat.size",
                    label: "首字母大写",
                    color: .orange
                ) {
                    viewModel.textProcessorConvertCase(.capitalized)
                }
                
                TextProcessorActionButton(
                    icon: "arrow.up.left.and.arrow.down.right",
                    label: "驼峰式",
                    color: .green
                ) {
                    viewModel.textProcessorConvertCase(.camelCase)
                }
                
                TextProcessorActionButton(
                    icon: "underline",
                    label: "下划线式",
                    color: .cyan
                ) {
                    viewModel.textProcessorConvertCase(.snakeCase)
                }
                
                TextProcessorActionButton(
                    icon: "minus.circle",
                    label: "连字符式",
                    color: .indigo
                ) {
                    viewModel.textProcessorConvertCase(.kebabCase)
                }
            }
            
            if !viewModel.textProcessorCaseOutput.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("转换结果")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(viewModel.textProcessorCaseOutput, forType: .string)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc")
                                Text("复制")
                            }
                            .font(.system(size: 10))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    ScrollView {
                        Text(viewModel.textProcessorCaseOutput)
                            .font(.system(size: 13))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(12)
                    }
                    .frame(height: 120)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
                }
            }
        }
    }
}

// MARK: - Sort & Dedupe View
struct TextProcessorSortView: View {
    @ObservedObject var viewModel: TextProcessorViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("文本排序与去重")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                
                TextEditor(text: $viewModel.textProcessorSortInput)
                    .font(.system(size: 13, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(8)
            }
            .frame(height: 180)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                TextProcessorActionButton(
                    icon: "arrow.up.arrow.down",
                    label: "按字母排序",
                    color: .blue
                ) {
                    viewModel.textProcessorSortLines(ascending: true)
                }
                
                TextProcessorActionButton(
                    icon: "arrow.down.arrow.up",
                    label: "倒序排序",
                    color: .purple
                ) {
                    viewModel.textProcessorSortLines(ascending: false)
                }
                
                TextProcessorActionButton(
                    icon: "trash.slash",
                    label: "去除重复行",
                    color: .orange
                ) {
                    viewModel.textProcessorRemoveDuplicates()
                }
                
                TextProcessorActionButton(
                    icon: "arrow.clockwise",
                    label: "反转行序",
                    color: .green
                ) {
                    viewModel.textProcessorReverseLines()
                }
            }
            
            if !viewModel.textProcessorSortOutput.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("处理结果")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(viewModel.textProcessorSortOutput, forType: .string)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc")
                                Text("复制")
                            }
                            .font(.system(size: 10))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    ScrollView {
                        Text(viewModel.textProcessorSortOutput)
                            .font(.system(size: 13, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(12)
                    }
                    .frame(height: 150)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
                }
            }
        }
    }
}

// MARK: - Find & Replace View
struct TextProcessorFindReplaceView: View {
    @ObservedObject var viewModel: TextProcessorViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("查找与替换")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                
                TextEditor(text: $viewModel.textProcessorFindReplaceInput)
                    .font(.system(size: 13, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(8)
            }
            .frame(height: 150)
            
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("查找")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        TextField("输入查找内容", text: $viewModel.textProcessorFindText)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("替换为")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        TextField("输入替换内容", text: $viewModel.textProcessorReplaceText)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    }
                }
                
                HStack {
                    Toggle("使用正则表达式", isOn: $viewModel.textProcessorUseRegex)
                        .font(.system(size: 12))
                    
                    Spacer()
                    
                    Toggle("区分大小写", isOn: $viewModel.textProcessorCaseSensitive)
                        .font(.system(size: 12))
                }
                
                HStack(spacing: 10) {
                    Button(action: { viewModel.textProcessorFindMatches() }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("查找 (\(viewModel.textProcessorMatchCount))")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { viewModel.textProcessorReplaceAll() }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("全部替换")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if !viewModel.textProcessorFindReplaceOutput.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("替换结果")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    ScrollView {
                        Text(viewModel.textProcessorFindReplaceOutput)
                            .font(.system(size: 13, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(12)
                    }
                    .frame(height: 120)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
                }
            }
        }
    }
}

// MARK: - Character Info View
struct TextProcessorCharInfoView: View {
    @ObservedObject var viewModel: TextProcessorViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("字符信息查询")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("输入字符")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                TextField("输入一个字符", text: $viewModel.textProcessorCharInput)
                    .font(.system(size: 24, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .onChange(of: viewModel.textProcessorCharInput) { _ in
                        viewModel.textProcessorAnalyzeCharacter()
                    }
            }
            
            if let info = viewModel.textProcessorCharInfo {
                VStack(spacing: 12) {
                    TextProcessorInfoRow(label: "字符", value: info.character)
                    TextProcessorInfoRow(label: "Unicode", value: info.unicode)
                    TextProcessorInfoRow(label: "Unicode 十进制", value: info.unicodeDecimal)
                    TextProcessorInfoRow(label: "HTML 实体", value: info.htmlEntity)
                    TextProcessorInfoRow(label: "HTML 十进制", value: info.htmlDecimal)
                    TextProcessorInfoRow(label: "URL 编码", value: info.urlEncoded)
                    TextProcessorInfoRow(label: "UTF-8", value: info.utf8)
                    
                    if !info.description.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("描述")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text(info.description)
                                .font(.system(size: 12))
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
            }
        }
    }
}

// MARK: - Helper Views
struct TextProcessorStatCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(color.gradient)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct TextProcessorActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct TextProcessorInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
        }
    }
}

#Preview {
    TextProcessorView()
}
