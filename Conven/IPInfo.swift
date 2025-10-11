import SwiftUI
import AppKit
import Combine

// IP 信息模型
struct IPInfo: Codable {
    let ip: String?
    let city: String?
    let region: String?
    let country: String?
    let timezone: String?
    let org: String?
    
    var query: String? { ip }
    var regionName: String? { region }
    var isp: String? { org }
}

class IPLookupViewModel: ObservableObject {
    @Published var ipAddress: String = ""
    @Published var ipInfo: IPInfo?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var localIP: String = "获取中..."
    
    init() {
        getLocalIP()
    }
    
    // 获取本地 IP
    func getLocalIP() {
        Task {
            // 使用多个备用 API
            let apis = [
                "https://api.ipify.org?format=text",
                "https://icanhazip.com",
                "https://ifconfig.me/ip"
            ]
            
            for api in apis {
                if let ip = await tryGetIP(from: api) {
                    await MainActor.run {
                        self.localIP = ip
                    }
                    return
                }
            }
            
            await MainActor.run {
                self.localIP = "获取失败"
            }
        }
    }
    
    private func tryGetIP(from urlString: String) async -> String? {
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            request.cachePolicy = .reloadIgnoringLocalCacheData
            
            let (data, _) = try await URLSession.shared.data(for: request)
            if let ip = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                return ip
            }
        } catch {
            print("从 \(urlString) 获取 IP 失败: \(error)")
        }
        
        return nil
    }
    
    // 查询 IP 信息
    func lookupIP() {
        guard !ipAddress.isEmpty else {
            errorMessage = "请输入 IP 地址"
            return
        }
        
        isLoading = true
        errorMessage = nil
        ipInfo = nil
        
        Task {
            // 尝试多个 API
            if let info = await tryIPAPI() {
                await MainActor.run {
                    self.ipInfo = info
                    self.isLoading = false
                }
                return
            }
            
            await MainActor.run {
                self.errorMessage = "查询失败：请检查网络连接"
                self.isLoading = false
            }
        }
    }
    
    private func tryIPAPI() async -> IPInfo? {
        let urlString = "https://ipapi.co/\(ipAddress)/json/"
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Status: \(httpResponse.statusCode)")
            }
            
            let decoder = JSONDecoder()
            let info = try decoder.decode(IPInfo.self, from: data)
            return info
        } catch {
            print("ipapi.co 查询失败: \(error)")
            return nil
        }
    }
    
    // 查询当前 IP
    func lookupCurrentIP() {
        ipAddress = localIP
        lookupIP()
    }
}

struct IPLookupView: View {
    @StateObject private var viewModel = IPLookupViewModel()
    @State private var hoveredRow: String?
    
    var body: some View {
        ZStack {
            // 毛玻璃背景
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(0.85)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 标题栏
                HStack(spacing: 12) {
                    Image(systemName: "network")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue.gradient)
                    
                    Text("IP 地址查询")
                        .font(.system(size: 14, weight: .medium))
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                // 内容区域
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // 当前 IP 卡片
                        currentIPCard
                        
                        // 查询输入框
                        querySection
                        
                        // 查询结果
                        if viewModel.isLoading {
                            loadingView
                        } else if let error = viewModel.errorMessage {
                            errorView(error)
                        } else if let info = viewModel.ipInfo {
                            resultView(info)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .frame(width: 420, height: 560)
    }
    
    // 当前 IP 卡片
    private var currentIPCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "wifi")
                    .foregroundStyle(.blue.gradient)
                Text("当前公网 IP")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
            }
            
            HStack {
                Text(viewModel.localIP)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.blue.gradient)
                    .textSelection(.enabled)
                
                Spacer()
                
                Button(action: {
                    copyToClipboard(viewModel.localIP)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                
                Button(action: viewModel.lookupCurrentIP) {
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12))
                        Text("查询")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.gradient)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
    
    // 查询区域
    private var querySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("查询其他 IP")
                .font(.system(size: 13, weight: .medium))
            
            HStack(spacing: 10) {
                TextField("输入 IP 地址", text: $viewModel.ipAddress)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.3))
                    )
                    .onSubmit {
                        viewModel.lookupIP()
                    }
                
                Button(action: viewModel.lookupIP) {
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12))
                        Text("查询")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.gradient)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // 加载视图
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
    
    // 错误视图
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // 结果视图
    private func resultView(_ info: IPInfo) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("查询结果")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
            }
            
            VStack(spacing: 1) {
                if let ip = info.query {
                    InfoRow(icon: "network", label: "IP 地址", value: ip, isHovered: hoveredRow == "ip") {
                        copyToClipboard(ip)
                    } onHover: { hovering in
                        hoveredRow = hovering ? "ip" : nil
                    }
                }
                
                if let country = info.country {
                    InfoRow(icon: "flag", label: "国家/地区", value: country, isHovered: hoveredRow == "country") {
                        copyToClipboard(country)
                    } onHover: { hovering in
                        hoveredRow = hovering ? "country" : nil
                    }
                }
                
                if let region = info.regionName {
                    InfoRow(icon: "map", label: "省份/州", value: region, isHovered: hoveredRow == "region") {
                        copyToClipboard(region)
                    } onHover: { hovering in
                        hoveredRow = hovering ? "region" : nil
                    }
                }
                
                if let city = info.city {
                    InfoRow(icon: "building.2", label: "城市", value: city, isHovered: hoveredRow == "city") {
                        copyToClipboard(city)
                    } onHover: { hovering in
                        hoveredRow = hovering ? "city" : nil
                    }
                }
                
                if let timezone = info.timezone {
                    InfoRow(icon: "clock", label: "时区", value: timezone, isHovered: hoveredRow == "timezone") {
                        copyToClipboard(timezone)
                    } onHover: { hovering in
                        hoveredRow = hovering ? "timezone" : nil
                    }
                }
                
                if let isp = info.isp {
                    InfoRow(icon: "antenna.radiowaves.left.and.right", label: "ISP", value: isp, isHovered: hoveredRow == "isp") {
                        copyToClipboard(isp)
                    } onHover: { hovering in
                        hoveredRow = hovering ? "isp" : nil
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.2))
            )
        }
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        print("✅ 已复制: \(text)")
    }
}

// 信息行组件
struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    let isHovered: Bool
    let onCopy: () -> Void
    let onHover: (Bool) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.blue.gradient)
                .frame(width: 20)
            
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)
            
            Text(value)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if isHovered {
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Rectangle()
                .fill(isHovered ? Color.white.opacity(0.3) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            onHover(hovering)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .cursor(.pointingHand)
    }
}

#Preview {
    IPLookupView()
}
