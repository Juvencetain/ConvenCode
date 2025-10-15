import SwiftUI
import Foundation
import Combine

// MARK: - Regex Example Model
struct RegexExample: Identifiable {
    let id = UUID()
    let name: String
    let pattern: String
}

// MARK: - Match Result Model
struct RegexMatch: Identifiable, Hashable {
    let id = UUID()
    let fullMatch: String
    let range: NSRange
    let groups: [String]
}

// MARK: - ViewModel
@MainActor
class RegexViewModel: ObservableObject {
    @Published var pattern: String = ""
    @Published var testString: String = ""
    @Published var matches: [RegexMatch] = []
    @Published var errorMessage: String?

    @Published var isCaseInsensitive = true
    @Published var isMultiline = true
    
    private var debounceTimer: Timer?

    // [新增] 常用正则表达式列表
    let examples: [RegexExample] = [
        .init(name: "匹配 Email", pattern: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#),
        .init(name: "匹配 URL", pattern: #"https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)"#),
        .init(name: "匹配 IP 地址", pattern: #"\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b"#),
        .init(name: "匹配手机号 (中国)", pattern: #"1[3-9]\d{9}"#),
        .init(name: "匹配身份证号 (中国)", pattern: #"\d{17}[\dXx]"#),
        .init(name: "匹配日期 (YYYY-MM-DD)", pattern: #"\d{4}-\d{2}-\d{2}"#),
        .init(name: "匹配时间 (HH:MM:SS)", pattern: #"(?:[01]\d|2[0-3]):(?:[0-5]\d):(?:[0-5]\d)"#),
        .init(name: "匹配 HTML 标签", pattern: #"<([a-z][a-z0-9]*)\b[^>]*>(.*?)<\/\1>"#),
        .init(name: "匹配十六进制颜色", pattern: #"#?([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})"#),
        .init(name: "匹配整数", pattern: #"[-+]?\d+"#),
        .init(name: "匹配正整数", pattern: #"\d+"#),
        .init(name: "匹配浮点数", pattern: #"[-+]?\d*\.\d+"#),
        .init(name: "匹配中文字符", pattern: #"[\u4e00-\u9fa5]+"#),
        .init(name: "匹配双字节字符", pattern: #"[^\x00-\xff]+"#),
        .init(name: "匹配空白行", pattern: #"^\s*$"#),
        .init(name: "匹配 GUID/UUID", pattern: #"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"#),
        .init(name: "匹配密码强度", pattern: #"^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[a-zA-Z\d]{8,}$"#),
        .init(name: "匹配域名", pattern: #"([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}"#),
        .init(name: "匹配文件路径 (Unix)", pattern: #"(\/|~|[.]{1,2})(\/[a-zA-Z0-9._-]+)+"#),
        .init(name: "提取图片链接", pattern: #"<img src=["']([^"']+)["']"#)
    ]

    func onInputChange() {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.performMatch()
        }
    }

    func performMatch() {
        guard !pattern.isEmpty else {
            self.matches = []
            self.errorMessage = nil
            return
        }

        var options: NSRegularExpression.Options = []
        if isCaseInsensitive { options.insert(.caseInsensitive) }
        if isMultiline { options.insert(.dotMatchesLineSeparators) }

        do {
            let regex = try NSRegularExpression(pattern: pattern, options: options)
            let nsRange = NSRange(testString.startIndex..<testString.endIndex, in: testString)
            let results = regex.matches(in: testString, options: [], range: nsRange)

            self.matches = results.map { result -> RegexMatch in
                let fullMatchString = String(testString[Range(result.range, in: testString)!])
                
                var groups: [String] = []
                for i in 1..<result.numberOfRanges {
                    if let range = Range(result.range(at: i), in: testString) {
                        groups.append(String(testString[range]))
                    } else {
                        groups.append("") // Handle optional groups that did not match
                    }
                }
                
                return RegexMatch(fullMatch: fullMatchString, range: result.range, groups: groups)
            }
            self.errorMessage = nil
        } catch {
            self.matches = []
            self.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Main View
struct RegexView: View {
    @StateObject private var viewModel = RegexViewModel()

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                Divider().padding(.horizontal, 20)

                HSplitView {
                    // 左侧：常用表达式列表
                    examplesList
                        .frame(minWidth: 200, idealWidth: 220, maxWidth: 300)

                    // 右侧：测试区域
                    testerSection
                        .frame(minWidth: 400)
                }
                .padding(20)
            }
        }.focusable(false)
        .frame(width: 800, height: 600)
        .onChange(of: viewModel.pattern) { _ in viewModel.onInputChange() }
        .onChange(of: viewModel.testString) { _ in viewModel.onInputChange() }
        .onChange(of: viewModel.isCaseInsensitive) { _ in viewModel.performMatch() }
        .onChange(of: viewModel.isMultiline) { _ in viewModel.performMatch() }
    }

    private var headerBar: some View {
        HStack {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(.orange.gradient)
            Text("正则表达式测试器")
                .font(.system(size: 14, weight: .medium))
            Spacer()
        }
        .padding(20)
    }

    private var examplesList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("常用表达式")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.bottom, 10)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(viewModel.examples) { example in
                        Button(action: {
                            viewModel.pattern = example.pattern
                        }) {
                            Text(example.name)
                                .font(.system(size: 13))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(viewModel.pattern == example.pattern ? Color.accentColor.opacity(0.2) : Color.clear)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.trailing, 10)
    }

    private var testerSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            patternSection
            testStringSection
            resultsSection
        }
        .padding(.leading, 10)
    }

    private var patternSection: some View {
        VStack(alignment: .leading) {
            Text("正则表达式")
                .font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                .padding(.bottom, 4)

            HStack {
                TextField("在此输入正则表达式...", text: $viewModel.pattern)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 14, design: .monospaced))
                
                Spacer()

                Toggle(isOn: $viewModel.isCaseInsensitive) {
                    Text("忽略大小写")
                }.toggleStyle(.checkbox)
                
                Toggle(isOn: $viewModel.isMultiline) {
                    Text("多行模式")
                }.toggleStyle(.checkbox)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }
        }
    }

    private var testStringSection: some View {
        VStack(alignment: .leading) {
            Text("测试文本")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.bottom, 4)
            
            TextEditor(text: $viewModel.testString)
                .font(.system(size: 14, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                .lineSpacing(5)
                .frame(maxHeight: 200)
        }
    }
    
    private var resultsSection: some View {
        VStack(alignment: .leading) {
            Text("匹配结果 (\(viewModel.matches.count))")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.bottom, 4)

            if viewModel.matches.isEmpty {
                VStack {
                    Spacer()
                    Text(viewModel.pattern.isEmpty ? "请输入正则表达式开始测试" : "无匹配结果")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.matches) { match in
                            MatchCardView(match: match)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Match Card View
struct MatchCardView: View {
    let match: RegexMatch

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Match #\(match.id.uuidString.prefix(4))")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.accentColor)
                
                Text("Range: {\(match.range.location), \(match.range.length)}")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            Text(match.fullMatch)
                .padding(8)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(4)
                .textSelection(.enabled)
            
            if !match.groups.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("捕获组:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    ForEach(0..<match.groups.count, id: \.self) { index in
                        HStack(alignment: .top) {
                            Text("  \(index + 1):")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                            
                            Text(match.groups[index])
                                .padding(4)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(4)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(.leading, 8)
            }
        }
        .font(.system(size: 12, design: .monospaced))
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}
