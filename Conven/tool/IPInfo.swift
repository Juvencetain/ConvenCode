import SwiftUI
import AppKit
import Combine

// MARK: - Models
struct IPInfo: Codable {
    let ip: String?
    let city: String?
    let region: String?
    let country: String?
    let timezone: String?
    let org: String?
    let postal: String?
    let latitude: Double?
    let longitude: Double?
    let asn: String?
    
    // API compatibility mappings
    var query: String? { ip }
    var regionName: String? { region }
    var isp: String? { org }
    var countryCode: String?
    
    var displayItems: [(icon: String, label: String, value: String)] {
        var items: [(String, String, String)] = []
        
        if let ip = query {
            items.append(("network", "IP 地址", ip))
        }
        if let country = country {
            items.append(("flag", "国家/地区", country))
        }
        if let region = regionName {
            items.append(("map", "省份/州", region))
        }
        if let city = city {
            items.append(("building.2", "城市", city))
        }
        if let timezone = timezone {
            items.append(("clock", "时区", timezone))
        }
        if let isp = isp {
            items.append(("antenna.radiowaves.left.and.right", "运营商", isp))
        }
        if let postal = postal {
            items.append(("envelope", "邮编", postal))
        }
        if let lat = latitude, let lon = longitude {
            items.append(("location", "坐标", String(format: "%.4f, %.4f", lat, lon)))
        }
        
        return items
    }
}

// MARK: - Network Service
actor IPLookupService {
    static let shared = IPLookupService()
    
    private let session: URLSession
    private let decoder = JSONDecoder()
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
    }
    
    // Get local IP with fallback APIs
    func getLocalIP() async -> String {
        let apis = [
            "https://api.ipify.org?format=text",
            "https://icanhazip.com",
            "https://ifconfig.me/ip",
            "https://checkip.amazonaws.com"
        ]
        
        for api in apis {
            if let ip = await fetchText(from: api) {
                return ip
            }
        }
        
        return "获取失败"
    }
    
    // Lookup IP information
    func lookupIP(_ ip: String) async throws -> IPInfo {
        // Validate IP format
        guard isValidIP(ip) else {
            throw LookupError.invalidIP
        }
        
        // Try multiple APIs with fallback
        let apis = [
            "https://ipapi.co/\(ip)/json/",
            "https://ipwho.is/\(ip)",
            "http://ip-api.com/json/\(ip)"
        ]
        
        for api in apis {
            if let info = await fetchIPInfo(from: api) {
                return info
            }
        }
        
        throw LookupError.networkError
    }
    
    private func fetchText(from urlString: String) async -> String? {
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await session.data(from: url)
            return String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("Failed to fetch from \(urlString): \(error)")
            return nil
        }
    }
    
    private func fetchIPInfo(from urlString: String) async -> IPInfo? {
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (data, _) = try await session.data(for: request)
            return try decoder.decode(IPInfo.self, from: data)
        } catch {
            print("Failed to decode from \(urlString): \(error)")
            return nil
        }
    }
    
    private func isValidIP(_ ip: String) -> Bool {
        let parts = ip.split(separator: ".")
        guard parts.count == 4 else { return false }
        
        return parts.allSatisfy { part in
            guard let num = Int(part) else { return false }
            return num >= 0 && num <= 255
        }
    }
    
    enum LookupError: LocalizedError {
        case invalidIP
        case networkError
        
        var errorDescription: String? {
            switch self {
            case .invalidIP:
                return "无效的 IP 地址格式"
            case .networkError:
                return "网络连接失败，请稍后重试"
            }
        }
    }
}

// MARK: - View Model
@MainActor
class IPLookupViewModel: ObservableObject {
    @Published var ipAddress = ""
    @Published var ipInfo: IPInfo?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var localIP = "获取中..."
    @Published var showSuccessToast = false
    @Published var toastMessage = ""
    
    private let service = IPLookupService.shared
    private var lookupTask: Task<Void, Never>?
    
    init() {
        Task {
            await fetchLocalIP()
        }
    }
    
    func fetchLocalIP() async {
        localIP = await service.getLocalIP()
    }
    
    func lookupIP() {
        // Cancel previous task if exists
        lookupTask?.cancel()
        
        let trimmedIP = ipAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedIP.isEmpty else {
            errorMessage = "请输入 IP 地址"
            return
        }
        
        isLoading = true
        errorMessage = nil
        ipInfo = nil
        
        lookupTask = Task {
            do {
                let info = try await service.lookupIP(trimmedIP)
                
                if !Task.isCancelled {
                    self.ipInfo = info
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
    
    func lookupCurrentIP() {
        ipAddress = localIP
        lookupIP()
    }
    
    func refreshLocalIP() {
        localIP = "获取中..."
        Task {
            await fetchLocalIP()
        }
    }
    
    func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        
        toastMessage = "已复制: \(text)"
        showSuccessToast = true
    }
    
    func clear() {
        ipAddress = ""
        ipInfo = nil
        errorMessage = nil
    }
}

// MARK: - Main View
struct IPLookupView: View {
    @StateObject private var viewModel = IPLookupViewModel()
    @State private var hoveredRow: String?
    @FocusState private var isInputFocused: Bool
    
    // MARK: - Layout Constants
    private enum Layout {
        static let defaultWidth: CGFloat = 420
        static let defaultHeight: CGFloat = 560
        static let horizontalPadding: CGFloat = 20
        static let verticalSpacing: CGFloat = 12
        static let cornerRadius: CGFloat = 10
    }
    
    var body: some View {
        ZStack {
            backgroundView
            
            VStack(spacing: 0) {
                headerBar
                contentArea
            }
        }
        .frame(width: Layout.defaultWidth, height: Layout.defaultHeight)
        .overlay(alignment: .top) {
            if viewModel.showSuccessToast {
                toastView
            }
        }.focusable(false)
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
            headerActions
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.vertical, 16)
    }
    
    private var headerTitle: some View {
        HStack(spacing: 8) {
            Image(systemName: "network")
                .font(.system(size: 16))
                .foregroundStyle(.blue.gradient)
            Text("IP 地址查询")
                .font(.system(size: 14, weight: .medium))
        }
    }
    
    private var headerActions: some View {
        HStack(spacing: 8) {
            if viewModel.ipInfo != nil {
                IPActionButton(icon: "arrow.clockwise", tooltip: "刷新") {
                    viewModel.clear()
                    viewModel.refreshLocalIP()
                }
                
                IPActionButton(icon: "plus.square", tooltip: "新建窗口") {
                    openNewWindow()
                }
            }
        }
    }
    
    // MARK: - Content Area
    private var contentArea: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Layout.verticalSpacing) {
                currentIPSection
                querySection
                
                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.errorMessage {
                    errorView(error)
                } else if let info = viewModel.ipInfo {
                    resultSection(info)
                }
                
                Spacer(minLength: 20)
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.bottom, 12)
        }
    }
    
    // MARK: - Current IP Section
    private var currentIPSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("当前公网 IP")
            
            HStack(spacing: 12) {
                Text(viewModel.localIP)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.blue.gradient)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 8) {
                    Button(action: {
                        viewModel.copyToClipboard(viewModel.localIP)
                    }) {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                    .help("复制 IP")
                    
                    Button(action: viewModel.refreshLocalIP) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .help("刷新")
                    
                    Button("查询详情", action: viewModel.lookupCurrentIP)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.15))
            .cornerRadius(Layout.cornerRadius)
        }
    }
    
    // MARK: - Query Section
    private var querySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("查询其他 IP")
            
            HStack(spacing: 8) {
                TextField("输入 IP 地址（如：8.8.8.8）", text: $viewModel.ipAddress)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .focused($isInputFocused)
                    .padding(8)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(Layout.cornerRadius)
                    .onSubmit {
                        viewModel.lookupIP()
                    }
                
                Button("查询", action: viewModel.lookupIP)
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.ipAddress.isEmpty)
                    .keyboardShortcut(.return, modifiers: .command)
                
                Button("清空", action: viewModel.clear)
                    .buttonStyle(.bordered)
                    .keyboardShortcut("k", modifiers: .command)
            }
        }
    }
    
    // MARK: - Result Section
    private func resultSection(_ info: IPInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionHeader("查询结果")
                Spacer()
                Text("\(info.displayItems.count) 项信息")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 0) {
                ForEach(Array(info.displayItems.enumerated()), id: \.offset) { index, item in
                    InfoRow(
                        icon: item.icon,
                        label: item.label,
                        value: item.value,
                        isHovered: hoveredRow == item.label,
                        isLast: index == info.displayItems.count - 1,
                        onCopy: {
                            viewModel.copyToClipboard(item.value)
                        },
                        onHover: { hovering in
                            withAnimation(.easeInOut(duration: 0.15)) {
                                hoveredRow = hovering ? item.label : nil
                            }
                        }
                    )
                }
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(Layout.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Layout.cornerRadius)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            Text("查询中...")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Error View
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 32))
                .foregroundStyle(.orange.gradient)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Toast View
    private var toastView: some View {
        Text("✓ \(viewModel.toastMessage)")
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
                    viewModel.showSuccessToast = false
                }
            }
    }
    
    // MARK: - Helpers
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12))
            .foregroundColor(.secondary)
    }
    
    private func openNewWindow() {
        let newView = IPLookupView()
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
}

// MARK: - Info Row Component
struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    let isHovered: Bool
    let isLast: Bool
    let onCopy: () -> Void
    let onHover: (Bool) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(.blue.gradient)
                .frame(width: 20)
            
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if isHovered {
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            isHovered ? Color.white.opacity(0.08) : Color.clear
        )
        .contentShape(Rectangle())
        .onHover(perform: onHover)
        .overlay(alignment: .bottom) {
            if !isLast {
                Divider()
                    .background(Color.white.opacity(0.05))
            }
        }
    }
}

// MARK: - Helper Components
struct IPActionButton: View {
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

// MARK: - Preview
#Preview {
    IPLookupView()
}
