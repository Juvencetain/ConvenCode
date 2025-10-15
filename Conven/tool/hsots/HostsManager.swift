import Foundation
import SwiftUI
import Combine

// MARK: - 主机条目模型
struct HostEntry: Identifiable, Hashable, Equatable {
    let id = UUID()
    var ip: String
    var domain: String
    var comment: String
    var isEnabled: Bool
}

// MARK: - Hosts 文件管理器
class HostsManager: ObservableObject {
    @Published var entries: [HostEntry] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var hasChanges = false

    private let hostsPath = "/etc/hosts"
    private var originalContentHash: Int?

    init() {
        loadHosts()
    }
    
    func loadHosts() {
        isLoading = true
        error = nil
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let content = try String(contentsOfFile: self.hostsPath, encoding: .utf8)
                let parsedEntries = self.parse(content: content)
                DispatchQueue.main.async {
                    self.originalContentHash = self.generateHostsContent(from: parsedEntries).hashValue
                    self.entries = parsedEntries
                    self.isLoading = false
                    self.hasChanges = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.error = "加载 hosts 文件失败: \(error.localizedDescription)。"
                    self.isLoading = false
                }
            }
        }
    }

    /// 使用 AppleScript 保存 Hosts 文件 (支持 Touch ID / 系统弹窗)
    func saveHosts() {
        isLoading = true
        error = nil
        let newContent = generateHostsContent(from: self.entries)
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("hosts_\(UUID().uuidString)")
        
        do {
            try newContent.write(to: tempURL, atomically: true, encoding: .utf8)
        } catch {
            self.error = "创建临时文件失败: \(error.localizedDescription)"
            self.isLoading = false
            return
        }
        
        let script = "mv '\(tempURL.path)' '\(hostsPath)'"
        let fullScript = "do shell script \"\(script)\" with administrator privileges"
        
        var errorDict: NSDictionary?
        if let appleScript = NSAppleScript(source: fullScript) {
            DispatchQueue.global(qos: .userInitiated).async {
                defer { try? FileManager.default.removeItem(at: tempURL) }
                
                if appleScript.executeAndReturnError(&errorDict) != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.loadHosts() }
                } else {
                    DispatchQueue.main.async {
                        let errorMessage = errorDict?["NSAppleScriptErrorBriefMessage"] as? String ?? "用户取消或发生未知授权错误。"
                        self.error = "保存失败: \(errorMessage)"
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    func checkForChanges() {
        let newContentHash = generateHostsContent(from: self.entries).hashValue
        hasChanges = (newContentHash != self.originalContentHash)
    }

    // MARK: - 私有辅助方法
    
    private func parse(content: String) -> [HostEntry] {
        var parsed: [HostEntry] = []
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.isEmpty || (trimmedLine.starts(with: "#") && !isPotentialHostEntry(line: trimmedLine)) {
                continue
            }

            var isEnabled = true
            var lineToParse = trimmedLine
            
            if trimmedLine.starts(with: "#") {
                isEnabled = false
                lineToParse = String(trimmedLine.dropFirst()).trimmingCharacters(in: .whitespaces)
            }
            
            var components = lineToParse.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard components.count >= 2 else { continue }
            
            let ip = components.removeFirst()
            let domain = components.removeFirst()
            
            guard isValidIPAddress(ip) else { continue }
            
            let remaining = components.joined(separator: " ")
            var comment = ""
            if let commentRange = remaining.range(of: "#") {
                comment = String(remaining[commentRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
            
            if !["localhost", "broadcasthost"].contains(domain) {
                parsed.append(HostEntry(ip: ip, domain: domain, comment: comment, isEnabled: isEnabled))
            }
        }
        return parsed
    }
    
    private func isPotentialHostEntry(line: String) -> Bool {
        let components = line.dropFirst().trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces)
        if components.count >= 2 {
            return isValidIPAddress(components[0])
        }
        return false
    }

    private func isValidIPAddress(_ ip: String) -> Bool {
        if ip == "::1" { return true }
        let parts = ip.split(separator: ".")
        if parts.count == 4 && parts.allSatisfy({ Int($0) != nil }) {
            return true
        }
        return false
    }

    private func generateHostsContent(from entries: [HostEntry]) -> String {
        var content = """
        # Host Database
        #
        # localhost is used to configure the loopback interface
        # when the system is booting. Do not change this entry.
        ##
        127.0.0.1       localhost
        255.255.255.255 broadcasthost
        ::1             localhost
        
        """
        
        for entry in entries {
            let prefix = entry.isEnabled ? "" : "# "
            var line = "\(prefix)\(entry.ip)\t\(entry.domain)"
            if !entry.comment.isEmpty {
                line += "\t# \(entry.comment)"
            }
            content += "\n\(line)"
        }
        return content
    }
}
