import SwiftUI
import AppKit
import Combine

// MARK: - Models
enum HTTPMethod: String, CaseIterable {
    case GET, POST, PUT, DELETE, PATCH
    
    var color: Color {
        switch self {
        case .GET: return .blue
        case .POST: return .green
        case .PUT: return .orange
        case .DELETE: return .red
        case .PATCH: return .purple
        }
    }
}

struct HTTPHeader: Identifiable, Equatable {
    let id = UUID()
    var key: String
    var value: String
}

struct HTTPParam: Identifiable, Equatable {
    let id = UUID()
    var key: String
    var value: String
    var enabled: Bool = true
}

struct HTTPResponse {
    let statusCode: Int
    let headers: [String: String]
    let body: String
    let duration: TimeInterval
    let size: Int
    
    var statusColor: Color {
        switch statusCode {
        case 200..<300: return .green
        case 300..<400: return .orange
        case 400..<500: return .red
        case 500..<600: return .purple
        default: return .gray
        }
    }
    
    var formattedSize: String {
        let bytes = Double(size)
        if bytes < 1024 {
            return "\(Int(bytes)) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.2f KB", bytes / 1024)
        } else {
            return String(format: "%.2f MB", bytes / (1024 * 1024))
        }
    }
    
    var formattedDuration: String {
        if duration < 1 {
            return String(format: "%.0f ms", duration * 1000)
        } else {
            return String(format: "%.2f s", duration)
        }
    }
}

// MARK: - View Model
@MainActor
class HTTPRequestViewModel: ObservableObject {
    @Published var method: HTTPMethod = .GET
    @Published var baseURL: String = ""
    @Published var params: [HTTPParam] = []
    @Published var headers: [HTTPHeader] = [
        HTTPHeader(key: "Content-Type", value: "application/json")
    ]
    @Published var body: String = ""
    @Published var response: HTTPResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showSuccessToast = false
    @Published var toastMessage = ""
    @Published var selectedTab = 0
    
    private var requestTask: Task<Void, Never>?
    
    var fullURL: String {
        var url = baseURL
        let enabledParams = params.filter { $0.enabled && !$0.key.isEmpty }
        
        if !enabledParams.isEmpty {
            let queryString = enabledParams
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: "&")
            url += "?\(queryString)"
        }
        
        return url
    }
    
    // Quick templates
    let quickTemplates: [(name: String, url: String, method: HTTPMethod, params: [HTTPParam])] = [
        ("测试 GET", "https://httpbin.org/get", .GET, []),
        ("测试 POST", "https://httpbin.org/post", .POST, []),
        ("获取 IP", "https://api.ipify.org", .GET, [HTTPParam(key: "format", value: "json")]),
        ("随机用户", "https://randomuser.me/api", .GET, [])
    ]
    
    func addParam() {
        params.append(HTTPParam(key: "", value: "", enabled: true))
    }
    
    func removeParam(at index: Int) {
        guard index >= 0 && index < params.count else { return }
        params.remove(at: index)
    }
    
    func addHeader() {
        headers.append(HTTPHeader(key: "", value: ""))
    }
    
    func removeHeader(at index: Int) {
        guard index >= 0 && index < headers.count else { return }
        headers.remove(at: index)
    }
    
    func loadTemplate(_ template: (name: String, url: String, method: HTTPMethod, params: [HTTPParam])) {
        baseURL = template.url
        method = template.method
        params = template.params
        if method == .POST {
            body = "{\n  \"key\": \"value\"\n}"
        } else {
            body = ""
        }
    }
    
    func sendRequest() {
        requestTask?.cancel()
        
        let trimmedURL = fullURL.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedURL.isEmpty else {
            errorMessage = "请输入 URL"
            return
        }
        
        guard let requestURL = URL(string: trimmedURL) else {
            errorMessage = "无效的 URL 格式"
            return
        }
        
        isLoading = true
        errorMessage = nil
        response = nil
        
        requestTask = Task {
            let startTime = Date()
            
            do {
                var request = URLRequest(url: requestURL)
                request.httpMethod = method.rawValue
                request.timeoutInterval = 30
                
                // Add headers
                for header in headers where !header.key.isEmpty {
                    request.setValue(header.value, forHTTPHeaderField: header.key)
                }
                
                // Add body for POST/PUT/PATCH
                if [.POST, .PUT, .PATCH].contains(method) && !body.isEmpty {
                    request.httpBody = body.data(using: .utf8)
                }
                
                let (data, urlResponse) = try await URLSession.shared.data(for: request)
                
                if !Task.isCancelled {
                    let httpResponse = urlResponse as? HTTPURLResponse
                    let duration = Date().timeIntervalSince(startTime)
                    
                    // Parse response body
                    let bodyString: String
                    if let jsonObject = try? JSONSerialization.jsonObject(with: data),
                       let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
                       let prettyString = String(data: prettyData, encoding: .utf8) {
                        bodyString = prettyString
                    } else {
                        bodyString = String(data: data, encoding: .utf8) ?? "无法解析响应"
                    }
                    
                    // Extract headers
                    var responseHeaders: [String: String] = [:]
                    if let httpResponse = httpResponse {
                        for (key, value) in httpResponse.allHeaderFields {
                            if let key = key as? String, let value = value as? String {
                                responseHeaders[key] = value
                            }
                        }
                    }
                    
                    self.response = HTTPResponse(
                        statusCode: httpResponse?.statusCode ?? 0,
                        headers: responseHeaders,
                        body: bodyString,
                        duration: duration,
                        size: data.count
                    )
                    self.isLoading = false
                }
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    func copyToClipboard(_ text: String, message: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        
        toastMessage = message
        showSuccessToast = true
    }
    
    func clear() {
        baseURL = ""
        params = []
        body = ""
        response = nil
        errorMessage = nil
        method = .GET
        headers = [HTTPHeader(key: "Content-Type", value: "application/json")]
    }
}

// MARK: - Main View
struct HTTPRequestView: View {
    @StateObject private var viewModel = HTTPRequestViewModel()
    @Environment(\.dismiss) var dismiss
    
    private enum Layout {
        static let width: CGFloat = 420
        static let height: CGFloat = 560
        static let padding: CGFloat = 20
        static let cornerRadius: CGFloat = 10
    }
    
    var body: some View {
        ZStack {
            backgroundView
            
            VStack(spacing: 0) {
                headerBar
                Divider()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        requestSection
                        
                        if !viewModel.params.isEmpty {
                            paramsSection
                        }
                        
                        headersSection
                        
                        if [.POST, .PUT, .PATCH].contains(viewModel.method) {
                            bodySection
                        }
                        
                        actionButtons
                        
                        if viewModel.isLoading {
                            loadingView
                        } else if let error = viewModel.errorMessage {
                            errorView(error)
                        } else if let response = viewModel.response {
                            responseSection(response)
                        }
                        
                        Spacer(minLength: 20)
                    }
                    .padding(Layout.padding)
                }
            }
        }
        .frame(width: Layout.width, height: Layout.height)
        .overlay(alignment: .top) {
            if viewModel.showSuccessToast {
                toastView
            }
        }
    }
    
    // MARK: - Background
    private var backgroundView: some View {
        VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
            .opacity(0.95)
            .ignoresSafeArea()
    }
    
    // MARK: - Header
    private var headerBar: some View {
        HStack {
            Image(systemName: "arrow.left.arrow.right.circle")
                .font(.system(size: 16))
                .foregroundStyle(.blue.gradient)
            
            Text("HTTP 请求")
                .font(.system(size: 16, weight: .semibold))
            
            Spacer()
            
            Menu {
                ForEach(viewModel.quickTemplates, id: \.name) { template in
                    Button(action: {
                        viewModel.loadTemplate(template)
                    }) {
                        Label(template.name, systemImage: "bolt.fill")
                    }
                }
            } label: {
                Image(systemName: "bolt.circle")
                    .font(.system(size: 16))
            }
            .menuStyle(.borderlessButton)
            .help("快速模板")
            
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
        }
        .padding(.horizontal, Layout.padding)
        .padding(.vertical, 16)
    }
    
    // MARK: - Request Section
    private var requestSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("请求配置")
            
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    // Method selector
                    Menu {
                        ForEach(HTTPMethod.allCases, id: \.self) { method in
                            Button(action: {
                                viewModel.method = method
                            }) {
                                HStack {
                                    Text(method.rawValue)
                                    if viewModel.method == method {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.method.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(viewModel.method.color)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(viewModel.method.color.opacity(0.15))
                        .cornerRadius(6)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 80)
                    
                    // URL input
                    TextField("https://api.example.com", text: $viewModel.baseURL)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(6)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                        .onSubmit {
                            viewModel.sendRequest()
                        }
                }
                
                // Add param button
                Button(action: viewModel.addParam) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 11))
                        Text("添加参数")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                // Full URL preview
                if !viewModel.fullURL.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("完整 URL")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text(viewModel.fullURL)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.blue)
                                .lineLimit(2)
                                .textSelection(.enabled)
                            
                            Spacer()
                            
                            Button(action: {
                                viewModel.copyToClipboard(viewModel.fullURL, message: "已复制 URL")
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 10))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(6)
                        .background(Color.black.opacity(0.15))
                        .cornerRadius(6)
                    }
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(Layout.cornerRadius)
        }
    }
    
    // MARK: - Params Section
    private var paramsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("查询参数")
            
            VStack(spacing: 6) {
                ForEach(viewModel.params) { param in
                    ParamRow(
                        param: param,
                        onToggle: { enabled in
                            if let index = viewModel.params.firstIndex(where: { $0.id == param.id }) {
                                viewModel.params[index].enabled = enabled
                            }
                        },
                        onKeyChange: { newKey in
                            if let index = viewModel.params.firstIndex(where: { $0.id == param.id }) {
                                viewModel.params[index].key = newKey
                            }
                        },
                        onValueChange: { newValue in
                            if let index = viewModel.params.firstIndex(where: { $0.id == param.id }) {
                                viewModel.params[index].value = newValue
                            }
                        },
                        onRemove: {
                            if let index = viewModel.params.firstIndex(where: { $0.id == param.id }) {
                                viewModel.removeParam(at: index)
                            }
                        }
                    )
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(Layout.cornerRadius)
        }
    }
    
    // MARK: - Headers Section
    private var headersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionHeader("请求头")
                Spacer()
                Button(action: viewModel.addHeader) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.blue.gradient)
                }
                .buttonStyle(.plain)
                .help("添加请求头")
            }
            
            VStack(spacing: 6) {
                ForEach(viewModel.headers) { header in
                    HeaderRow(
                        header: header,
                        onKeyChange: { newKey in
                            if let index = viewModel.headers.firstIndex(where: { $0.id == header.id }) {
                                viewModel.headers[index].key = newKey
                            }
                        },
                        onValueChange: { newValue in
                            if let index = viewModel.headers.firstIndex(where: { $0.id == header.id }) {
                                viewModel.headers[index].value = newValue
                            }
                        },
                        onRemove: {
                            if let index = viewModel.headers.firstIndex(where: { $0.id == header.id }) {
                                viewModel.removeHeader(at: index)
                            }
                        }
                    )
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(Layout.cornerRadius)
        }
    }
    
    // MARK: - Body Section
    private var bodySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionHeader("请求体")
                Spacer()
                Text("JSON")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)
            }
            
            TextEditor(text: $viewModel.body)
                .font(.system(size: 11, design: .monospaced))
                .frame(height: 100)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color.white.opacity(0.05))
                .cornerRadius(Layout.cornerRadius)
        }
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button(action: viewModel.sendRequest) {
                HStack(spacing: 6) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 11))
                    Text("发送")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(viewModel.method.color.gradient)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.baseURL.isEmpty || viewModel.isLoading)
            .keyboardShortcut(.return, modifiers: .command)
            
            Button(action: viewModel.clear) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(width: 40)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("k", modifiers: .command)
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.7)
            Text("发送中...")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
    
    // MARK: - Error View
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(.orange.gradient)
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
    
    // MARK: - Response Section
    private func responseSection(_ response: HTTPResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Response info
            HStack {
                sectionHeader("响应结果")
                Spacer()
                
                HStack(spacing: 12) {
                    InfoBadge(label: "状态", value: "\(response.statusCode)", color: response.statusColor)
                    InfoBadge(label: "时长", value: response.formattedDuration, color: .blue)
                    InfoBadge(label: "大小", value: response.formattedSize, color: .purple)
                }
            }
            
            // Tab selector
            Picker("", selection: $viewModel.selectedTab) {
                Text("响应体").tag(0)
                Text("响应头").tag(1)
            }
            .pickerStyle(.segmented)
            
            // Content
            if viewModel.selectedTab == 0 {
                responseBodyView(response.body)
            } else {
                responseHeadersView(response.headers)
            }
        }
    }
    
    private func responseBodyView(_ body: String) -> some View {
        VStack(alignment: .trailing, spacing: 6) {
            Button(action: {
                viewModel.copyToClipboard(body, message: "已复制响应体")
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.doc")
                    Text("复制")
                }
                .font(.system(size: 10))
                .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            
            ScrollView {
                Text(body)
                    .font(.system(size: 10, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(height: 150)
            .background(Color.black.opacity(0.2))
            .cornerRadius(Layout.cornerRadius)
        }
    }
    
    private func responseHeadersView(_ headers: [String: String]) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(headers.sorted(by: { $0.key < $1.key }).enumerated()), id: \.offset) { index, header in
                    HStack(spacing: 8) {
                        Text(header.key)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.blue)
                            .frame(width: 100, alignment: .leading)
                        
                        Text(header.value)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Button(action: {
                            viewModel.copyToClipboard(header.value, message: "已复制")
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 9))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(index % 2 == 0 ? Color.white.opacity(0.05) : Color.clear)
                }
            }
        }
        .frame(height: 150)
        .background(Color.black.opacity(0.1))
        .cornerRadius(Layout.cornerRadius)
    }
    
    // MARK: - Toast
    private var toastView: some View {
        Text("✓ \(viewModel.toastMessage)")
            .font(.system(size: 12))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.green.opacity(0.9))
            .foregroundColor(.white)
            .cornerRadius(16)
            .padding(.top, 60)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                withAnimation(.easeInOut(duration: 0.3).delay(1.5)) {
                    viewModel.showSuccessToast = false
                }
            }
    }
    
    // MARK: - Helpers
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.secondary)
    }
}

// MARK: - Components
struct ParamRow: View {
    let param: HTTPParam
    let onToggle: (Bool) -> Void
    let onKeyChange: (String) -> Void
    let onValueChange: (String) -> Void
    let onRemove: () -> Void
    
    @State private var localEnabled: Bool
    @State private var localKey: String
    @State private var localValue: String
    
    init(param: HTTPParam, onToggle: @escaping (Bool) -> Void, onKeyChange: @escaping (String) -> Void, onValueChange: @escaping (String) -> Void, onRemove: @escaping () -> Void) {
        self.param = param
        self.onToggle = onToggle
        self.onKeyChange = onKeyChange
        self.onValueChange = onValueChange
        self.onRemove = onRemove
        
        _localEnabled = State(initialValue: param.enabled)
        _localKey = State(initialValue: param.key)
        _localValue = State(initialValue: param.value)
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Toggle("", isOn: $localEnabled)
                .toggleStyle(.checkbox)
                .labelsHidden()
                .onChange(of: localEnabled) { newValue in
                    onToggle(newValue)
                }
            
            TextField("key", text: $localKey)
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .padding(5)
                .background(Color.white.opacity(0.1))
                .cornerRadius(4)
                .onChange(of: localKey) { newValue in
                    onKeyChange(newValue)
                }
            
            Text("=")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            TextField("value", text: $localValue)
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .padding(5)
                .background(Color.white.opacity(0.1))
                .cornerRadius(4)
                .onChange(of: localValue) { newValue in
                    onValueChange(newValue)
                }
            
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.red.gradient)
            }
            .buttonStyle(.plain)
        }
    }
}

struct HeaderRow: View {
    let header: HTTPHeader
    let onKeyChange: (String) -> Void
    let onValueChange: (String) -> Void
    let onRemove: () -> Void
    
    @State private var localKey: String
    @State private var localValue: String
    
    init(header: HTTPHeader, onKeyChange: @escaping (String) -> Void, onValueChange: @escaping (String) -> Void, onRemove: @escaping () -> Void) {
        self.header = header
        self.onKeyChange = onKeyChange
        self.onValueChange = onValueChange
        self.onRemove = onRemove
        
        _localKey = State(initialValue: header.key)
        _localValue = State(initialValue: header.value)
    }
    
    var body: some View {
        HStack(spacing: 6) {
            TextField("Key", text: $localKey)
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .padding(5)
                .background(Color.white.opacity(0.1))
                .cornerRadius(4)
                .onChange(of: localKey) { newValue in
                    onKeyChange(newValue)
                }
            
            Text(":")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            TextField("Value", text: $localValue)
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .padding(5)
                .background(Color.white.opacity(0.1))
                .cornerRadius(4)
                .onChange(of: localValue) { newValue in
                    onValueChange(newValue)
                }
            
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.red.gradient)
            }
            .buttonStyle(.plain)
        }
    }
}

struct InfoBadge: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview
#Preview {
    HTTPRequestView()
}
