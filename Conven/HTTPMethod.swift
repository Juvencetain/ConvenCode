import SwiftUI
import AppKit
import Combine

// MARK: - Models
enum HTTPMethod: String, CaseIterable, Codable {
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

struct HTTPHeader: Identifiable, Equatable, Codable {
    let id = UUID()
    var key: String
    var value: String
}

struct HTTPParam: Identifiable, Equatable, Codable {
    let id = UUID()
    var key: String
    var value: String
    var enabled: Bool = true
}

// MARK: - 保存的请求模型
struct SavedRequest: Identifiable, Codable {
    let id: UUID
    var name: String
    var method: HTTPMethod
    var baseURL: String
    var params: [HTTPParam]
    var headers: [HTTPHeader]
    var body: String
    var createdAt: Date
    
    init(name: String, method: HTTPMethod, baseURL: String, params: [HTTPParam], headers: [HTTPHeader], body: String) {
        self.id = UUID()
        self.name = name
        self.method = method
        self.baseURL = baseURL
        self.params = params
        self.headers = headers
        self.body = body
        self.createdAt = Date()
    }
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

// MARK: - 请求存储管理器
class RequestStorage {
    static let shared = RequestStorage()
    private let storageKey = "saved_http_requests"
    
    func save(_ requests: [SavedRequest]) {
        if let encoded = try? JSONEncoder().encode(requests) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    func load() -> [SavedRequest] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let requests = try? JSONDecoder().decode([SavedRequest].self, from: data) else {
            return []
        }
        return requests
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
    
    // 保存的请求
    @Published var savedRequests: [SavedRequest] = []
    @Published var showSaveDialog = false
    @Published var showSavedRequests = false
    @Published var requestName = ""
    
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
    
    init() {
        loadSavedRequests()
    }
    
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
    
    // MARK: - 保存和加载请求
    func saveCurrentRequest() {
        guard !requestName.isEmpty else {
            toastMessage = "请输入请求名称"
            showSuccessToast = true
            return
        }
        
        let request = SavedRequest(
            name: requestName,
            method: method,
            baseURL: baseURL,
            params: params,
            headers: headers,
            body: body
        )
        
        savedRequests.append(request)
        RequestStorage.shared.save(savedRequests)
        
        toastMessage = "已保存: \(requestName)"
        showSuccessToast = true
        showSaveDialog = false
        requestName = ""
    }
    
    func loadSavedRequests() {
        savedRequests = RequestStorage.shared.load()
    }
    
    func loadSavedRequest(_ request: SavedRequest) {
        method = request.method
        baseURL = request.baseURL
        params = request.params
        headers = request.headers
        body = request.body
        showSavedRequests = false
        
        toastMessage = "已加载: \(request.name)"
        showSuccessToast = true
    }
    
    func deleteSavedRequest(_ request: SavedRequest) {
        savedRequests.removeAll { $0.id == request.id }
        RequestStorage.shared.save(savedRequests)
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
                
                for header in headers where !header.key.isEmpty {
                    request.setValue(header.value, forHTTPHeaderField: header.key)
                }
                
                if [.POST, .PUT, .PATCH].contains(method) && !body.isEmpty {
                    request.httpBody = body.data(using: .utf8)
                }
                
                let (data, urlResponse) = try await URLSession.shared.data(for: request)
                
                if !Task.isCancelled {
                    let httpResponse = urlResponse as? HTTPURLResponse
                    let duration = Date().timeIntervalSince(startTime)
                    
                    let bodyString: String
                    if let jsonObject = try? JSONSerialization.jsonObject(with: data),
                       let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
                       let prettyString = String(data: prettyData, encoding: .utf8) {
                        bodyString = prettyString
                    } else {
                        bodyString = String(data: data, encoding: .utf8) ?? "无法解析响应"
                    }
                    
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

// MARK: - 重新设计的主界面
struct HTTPRequestView: View {
    @StateObject private var viewModel = HTTPRequestViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(1)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                topBar
                Divider()
                
                HStack(spacing: 0) {
                    // 左侧：请求配置
                    requestPanel
                    
                    Divider()
                    
                    // 右侧：响应结果
                    responsePanel
                }
            }
        }
        .frame(width: 900, height: 650)
        .focusable(false)
        .overlay(alignment: .top) {
            if viewModel.showSuccessToast {
                toastView
            }
        }
        .sheet(isPresented: $viewModel.showSaveDialog) {
            SaveRequestDialog(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showSavedRequests) {
            SavedRequestsView(viewModel: viewModel)
        }
    }
    
    // MARK: - 顶部栏
    
    private var topBar: some View {
        HStack {
            Image(systemName: "arrow.left.arrow.right.circle")
                .font(.system(size: 16))
                .foregroundStyle(.indigo.gradient)
            
            Text("HTTP 请求工具")
                .font(.system(size: 16, weight: .semibold))
            
            Spacer()
            
            // 快速模板
            Menu {
                ForEach(viewModel.quickTemplates, id: \.name) { template in
                    Button(action: {
                        viewModel.loadTemplate(template)
                    }) {
                        Label(template.name, systemImage: "bolt.fill")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.circle.fill")
                    Text("模板")
                }
                .font(.system(size: 12))
                .foregroundColor(.blue)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
            }
            .menuStyle(.borderlessButton)
            
            // 保存的请求
            Button(action: { viewModel.showSavedRequests = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                    Text("已保存")
                    if !viewModel.savedRequests.isEmpty {
                        Text("(\(viewModel.savedRequests.count))")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .font(.system(size: 12))
                .foregroundColor(.green)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.1))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .httpCursor()
            
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .httpCursor()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
    
    // MARK: - 请求配置面板
    
    private var requestPanel: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // URL 和方法
                urlSection
                
                // 参数
                if !viewModel.params.isEmpty {
                    paramsSection
                }
                
                // 请求头
                headersSection
                
                // 请求体
                if [.POST, .PUT, .PATCH].contains(viewModel.method) {
                    bodySection
                }
                
                // 操作按钮
                actionButtons
                
                Spacer(minLength: 20)
            }
            .padding(24)
        }
        .frame(width: 450)
    }
    
    private var urlSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("请求配置")
            
            VStack(spacing: 12) {
                // 方法选择器和URL输入
                HStack(spacing: 10) {
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
                        HStack(spacing: 6) {
                            Text(viewModel.method.rawValue)
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(viewModel.method.color)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(viewModel.method.color.opacity(0.15))
                        .cornerRadius(8)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 100)
                    
                    TextField("https://api.example.com/endpoint", text: $viewModel.baseURL)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                        .onSubmit {
                            viewModel.sendRequest()
                        }
                }
                
                // 添加参数按钮
                Button(action: viewModel.addParam) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 12))
                        Text("添加查询参数")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .httpCursor()
                
                // 完整URL显示
                if !viewModel.fullURL.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("完整 URL")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button(action: {
                                viewModel.copyToClipboard(viewModel.fullURL, message: "已复制 URL")
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.on.doc")
                                    Text("复制")
                                }
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                            .httpCursor()
                        }
                        
                        Text(viewModel.fullURL)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.blue)
                            .textSelection(.enabled)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.15))
                            .cornerRadius(6)
                    }
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    private var paramsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("查询参数")
            
            VStack(spacing: 8) {
                ForEach(viewModel.params) { param in
                    ModernParamRow(
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
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    private var headersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("请求头")
                
                Spacer()
                
                Button(action: viewModel.addHeader) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 12))
                        Text("添加")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .httpCursor()
            }
            
            VStack(spacing: 8) {
                ForEach(viewModel.headers) { header in
                    ModernHeaderRow(
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
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    private var bodySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("请求体")
                
                Spacer()
                
                Text("JSON")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(4)
            }
            
            TextEditor(text: $viewModel.body)
                .font(.system(size: 12, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(12)
                .frame(height: 140)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: viewModel.sendRequest) {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 13))
                    Text("发送请求")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(viewModel.method.color.gradient)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.baseURL.isEmpty || viewModel.isLoading)
            .keyboardShortcut(.return, modifiers: .command)
            .httpCursor()
            
            Button(action: { viewModel.showSaveDialog = true }) {
                Image(systemName: "square.and.arrow.down.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                    .frame(width: 48)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .help("保存请求")
            .httpCursor()
            
            Button(action: viewModel.clear) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(width: 48)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .help("清空")
            .keyboardShortcut("k", modifiers: .command)
            .httpCursor()
        }
    }
    
    // MARK: - 响应面板
    
    private var responsePanel: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.errorMessage {
                errorView(error)
            } else if let response = viewModel.response {
                responseContent(response)
            } else {
                emptyResponseView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyResponseView: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.down.circle.dotted")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)
            
            VStack(spacing: 8) {
                Text("等待响应")
                    .font(.system(size: 16, weight: .medium))
                
                Text("配置请求后点击发送")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("请求中...")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.orange.gradient)
            
            VStack(spacing: 8) {
                Text("请求失败")
                    .font(.system(size: 16, weight: .medium))
                
                Text(message)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func responseContent(_ response: HTTPResponse) -> some View {
        VStack(spacing: 0) {
            // 状态栏
            responseStatusBar(response)
            
            Divider()
            
            // 标签切换
            Picker("", selection: $viewModel.selectedTab) {
                Text("响应体").tag(0)
                Text("响应头").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            
            Divider()
            
            // 内容
            if viewModel.selectedTab == 0 {
                responseBodyView(response.body)
            } else {
                responseHeadersView(response.headers)
            }
        }
    }
    
    private func responseStatusBar(_ response: HTTPResponse) -> some View {
        HStack(spacing: 20) {
            StatusBadge(
                label: "状态码",
                value: "\(response.statusCode)",
                color: response.statusColor
            )
            
            StatusBadge(
                label: "耗时",
                value: response.formattedDuration,
                color: .blue
            )
            
            StatusBadge(
                label: "大小",
                value: response.formattedSize,
                color: .purple
            )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.05))
    }
    
    private func responseBodyView(_ body: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                
                Button(action: {
                    viewModel.copyToClipboard(body, message: "已复制响应体")
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc.fill")
                        Text("复制")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .httpCursor()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            
            ScrollView {
                Text(body)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
        }
    }
    
    private func responseHeadersView(_ headers: [String: String]) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(headers.sorted(by: { $0.key < $1.key }).enumerated()), id: \.offset) { index, header in
                    HStack(spacing: 12) {
                        Text(header.key)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.blue)
                            .frame(width: 140, alignment: .leading)
                        
                        Text(header.value)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Button(action: {
                            viewModel.copyToClipboard(header.value, message: "已复制")
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .httpCursor()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(index % 2 == 0 ? Color.white.opacity(0.03) : Color.clear)
                }
            }
        }
    }
    
    // MARK: - Toast
    
    private var toastView: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
            Text(viewModel.toastMessage)
                .font(.system(size: 12))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.green.opacity(1))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
        .padding(.top, 70)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3).delay(2)) {
                viewModel.showSuccessToast = false
            }
        }
    }
    
    // MARK: - 辅助方法
    
    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.primary)
    }
}

// MARK: - 现代化参数行

struct ModernParamRow: View {
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
        HStack(spacing: 10) {
            Toggle("", isOn: $localEnabled)
                .toggleStyle(.checkbox)
                .labelsHidden()
                .onChange(of: localEnabled) { onToggle($0) }
            
            TextField("键", text: $localKey)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08))
                .cornerRadius(6)
                .onChange(of: localKey) { onKeyChange($0) }
            
            Text("=")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
            
            TextField("值", text: $localValue)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08))
                .cornerRadius(6)
                .onChange(of: localValue) { onValueChange($0) }
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.red.opacity(0.8))
            }
            .buttonStyle(.plain)
            .httpCursor()
        }
    }
}

// MARK: - 现代化请求头行

struct ModernHeaderRow: View {
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
        HStack(spacing: 10) {
            TextField("Key", text: $localKey)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08))
                .cornerRadius(6)
                .onChange(of: localKey) { onKeyChange($0) }
            
            Text(":")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
            
            TextField("Value", text: $localValue)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08))
                .cornerRadius(6)
                .onChange(of: localValue) { onValueChange($0) }
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.red.opacity(0.8))
            }
            .buttonStyle(.plain)
            .httpCursor()
        }
    }
}

// MARK: - 状态徽章

struct StatusBadge: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 通用组件（保存对话框和列表视图保持不变，使用原有代码）

extension View {
    func httpCursor() -> some View {
        self.onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

// MARK: - 保存请求对话框
struct SaveRequestDialog: View {
    @ObservedObject var viewModel: HTTPRequestViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(1)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("保存请求")
                    .font(.system(size: 16, weight: .semibold))
                
                TextField("请输入请求名称", text: $viewModel.requestName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(10)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                
                HStack(spacing: 12) {
                    Button("取消") {
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    
                    Button("保存") {
                        viewModel.saveCurrentRequest()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.requestName.isEmpty)
                }
            }
            .padding(30)
        }
        .frame(width: 320, height: 180)
    }
}

// MARK: - 保存的请求列表
struct SavedRequestsView: View {
    @ObservedObject var viewModel: HTTPRequestViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(1)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 标题栏
                HStack {
                    Image(systemName: "folder")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue.gradient)
                    
                    Text("保存的请求")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Spacer()
                    
                    Text("\(viewModel.savedRequests.count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.secondary.opacity(0.15)))
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Divider()
                
                // 请求列表
                if viewModel.savedRequests.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 48))
                            .foregroundStyle(.tertiary)
                        
                        Text("还没有保存的请求")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text("发送请求后点击保存按钮")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.savedRequests) { request in
                                SavedRequestCard(
                                    request: request,
                                    onLoad: {
                                        viewModel.loadSavedRequest(request)
                                    },
                                    onDelete: {
                                        viewModel.deleteSavedRequest(request)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
        }
        .frame(width: 420, height: 560)
    }
}

// MARK: - 保存的请求卡片
struct SavedRequestCard: View {
    let request: SavedRequest
    let onLoad: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                // 方法标签
                Text(request.method.rawValue)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(request.method.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(request.method.color.opacity(0.15))
                    .cornerRadius(4)
                
                // 请求名称
                VStack(alignment: .leading, spacing: 2) {
                    Text(request.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(request.baseURL)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            
            // 元数据
            HStack(spacing: 12) {
                if !request.params.isEmpty {
                    Label("\(request.params.count) 参数", systemImage: "link")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                if !request.headers.isEmpty {
                    Label("\(request.headers.count) 请求头", systemImage: "list.bullet")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(formatDate(request.createdAt))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            
            // 操作按钮
            if isHovered {
                HStack(spacing: 8) {
                    Button(action: onLoad) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 10))
                            Text("加载")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue.opacity(0.12))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                    
                    Spacer()
                    
                    Button(action: onDelete) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                            Text("删除")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                }
                .transition(.opacity.animation(.easeOut(duration: 0.25)))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? Color.white.opacity(0.12) : Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isHovered ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.3), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
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

#Preview {
    HTTPRequestView()
}
