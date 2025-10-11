import SwiftUI
import AppKit

// MARK: - 主数据处理视图
struct DataProcessorView: View {
    // 通用状态，用于在 Tab 之间共享输入/输出
    @State private var inputText: String = ""
    @State private var outputText: String = ""
    @State private var selectedTab = 0
    
    // 假设您在 JSONFormatterView 中使用了 VisualEffectBlur
    // 请确保您的项目中已经定义了 VisualEffectBlur
    // 否则，请注释掉 ZStack 及其内容
    
    var body: some View {
        ZStack {
            // 背景效果（保持与 JSONFormatterView 一致）
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部的 Tab 切换
                Picker("功能", selection: $selectedTab) {
                    Text("Base64").tag(0)
                    Text("URL").tag(1)
                    Text("时间戳").tag(2)
                    Text("MD5").tag(3)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // 核心功能区域
                TabView(selection: $selectedTab) {
                    Base64ConverterView(inputText: $inputText, outputText: $outputText)
                        .tag(0)
                    URLConverterView(inputText: $inputText, outputText: $outputText)
                        .tag(1)
                    TimestampConverterView()
                        .tag(2)
                    MD5HasherView(inputText: $inputText, outputText: $outputText)
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never)) // 隐藏 TabView 自己的导航栏
                .padding(.top, 10)
                
                Spacer()
            }
        }
        // 保持与 JSONFormatterView 相似的默认大小
        .frame(width: 420, height: 560) 
    }
}

// MARK: - 共享文本输入/输出区域视图
struct ProcessorAreaView: View {
    @Binding var inputText: String
    @Binding var outputText: String
    
    var body: some View {
        VStack(spacing: 10) {
            TextEditor(text: $inputText)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120, maxHeight: .infinity)
                .background(Color.white.opacity(0.15))
                .cornerRadius(10)
            
            HStack {
                Text("结果:")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
                Button("复制结果") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(outputText, forType: .string)
                }
                .disabled(outputText.isEmpty)
                .buttonStyle(.bordered)
            }
            
            TextEditor(text: $outputText)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120, maxHeight: .infinity)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
                .allowsHitTesting(false) // 结果只读
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 15)
    }
}

// MARK: - 1. Base64 转换实现
struct Base64ConverterView: View {
    @Binding var inputText: String
    @Binding var outputText: String
    
    private func convertToBase64(encode: Bool) {
        if encode {
            if let data = inputText.data(using: .utf8) {
                outputText = data.base64EncodedString()
            } else {
                outputText = "编码失败：确保输入是有效的 UTF-8 文本"
            }
        } else {
            if let data = Data(base64Encoded: inputText),
               let string = String(data: data, encoding: .utf8) {
                outputText = string
            } else {
                outputText = "解码失败：Base64 字符串无效"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 15) {
            HStack(spacing: 10) {
                Button("编码 -> Base64") { convertToBase64(encode: true) }.buttonStyle(.borderedProminent)
                Button("解码 <- 文本") { convertToBase64(encode: false) }.buttonStyle(.bordered)
            }
            ProcessorAreaView(inputText: $inputText, outputText: $outputText)
        }
    }
}

// MARK: - 2. URL 转换实现
struct URLConverterView: View {
    @Binding var inputText: String
    @Binding var outputText: String
    
    private func convertURL(encode: Bool) {
        if encode {
            // 编码：使用 .urlQueryAllowed 确保 URL 参数能被正确编码
            outputText = inputText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "URL 编码失败"
        } else {
            // 解码
            outputText = inputText.removingPercentEncoding ?? "URL 解码失败"
        }
    }
    
    var body: some View {
        VStack(spacing: 15) {
            HStack(spacing: 10) {
                Button("编码 -> URL") { convertURL(encode: true) }.buttonStyle(.borderedProminent)
                Button("解码 <- 文本") { convertURL(encode: false) }.buttonStyle(.bordered)
            }
            ProcessorAreaView(inputText: $inputText, outputText: $outputText)
        }
    }
}

// MARK: - 3. 时间戳转换实现
struct TimestampConverterView: View {
    @State private var inputTimestamp: String = ""
    @State private var outputDate: String = ""
    @State private var selectedUnit: TimeUnit = .seconds
    
    enum TimeUnit: String, CaseIterable, Identifiable {
        case seconds = "秒 (s)"
        case milliseconds = "毫秒 (ms)"
        var id: Self { self }
    }
    
    private func convert() {
        guard let ts = Double(inputTimestamp.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            outputDate = "输入格式错误：请输入数字"
            return
        }
        
        let timeInterval: TimeInterval = (selectedUnit == .milliseconds) ? (ts / 1000.0) : ts
        
        let date = Date(timeIntervalSince1970: timeInterval)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone.current // 使用当前时区
        outputDate = formatter.string(from: date)
    }
    
    var body: some View {
        VStack(spacing: 15) {
            HStack(spacing: 10) {
                // 当前时间戳
                Button("获取当前时间戳") {
                    let ts = Date().timeIntervalSince1970
                    inputTimestamp = selectedUnit == .milliseconds ? String(Int(ts * 1000)) : String(Int(ts))
                    convert()
                }.buttonStyle(.borderedProminent)

                // 单位选择
                Picker("单位", selection: $selectedUnit) {
                    ForEach(TimeUnit.allCases) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .fixedSize()
            }
            .padding(.horizontal, 20)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("输入时间戳:")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                
                HStack {
                    TextField("请输入时间戳", text: $inputTimestamp)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    Button("转换", action: convert)
                        .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 20)
                
                Text("转换结果 (当前时区):")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                
                Text(outputDate.isEmpty ? "点击转换后显示日期和时间" : outputDate)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 40)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
            }
            Spacer()
        }
    }
}

// MARK: - 4. MD5 编码实现 (使用占位符，因为 MD5 需要外部库)
struct MD5HasherView: View {
    @Binding var inputText: String
    @Binding var outputText: String
    
    // ⚠️ 占位符函数：实际使用需要引入 CryptoKit (iOS/macOS 10.15+) 或 CommonCrypto
    private func md5Hash(_ string: String) -> String {
        return "MD5 HASH: " + string.hashValue.description + " (此为占位值)"
    }
    
    private func hashMD5() {
        if inputText.isEmpty {
            outputText = "请输入文本"
        } else {
            outputText = md5Hash(inputText)
        }
    }
    
    var body: some View {
        VStack(spacing: 15) {
            Text("🚨 注意：MD5 编码需要额外的依赖库 (如 CryptoKit)。当前结果为占位值。")
                .font(.caption)
                .foregroundColor(.orange)
                .padding(.horizontal, 20)

            Button("计算 MD5 编码") { hashMD5() }.buttonStyle(.borderedProminent)
            
            ProcessorAreaView(inputText: $inputText, outputText: $outputText)
        }
    }
}