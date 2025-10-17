import SwiftUI
import CryptoKit
import CommonCrypto
import Combine
internal import UniformTypeIdentifiers

// MARK: - 文件哈希计算视图模型
@MainActor
class FileHashViewModel: ObservableObject {
    @Published var fileHashResults: [FileHashResult] = []
    @Published var fileHashIsProcessing = false
    @Published var fileHashErrorMessage: String?
    
    // MARK: - 选择文件
    func fileHashSelectFiles(algorithms: Set<FileHashAlgorithm>) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK {
            fileHashProcessFiles(urls: panel.urls, algorithms: algorithms)
        }
    }
    
    // MARK: - 处理拖放
    func fileHashHandleDrop(providers: [NSItemProvider], algorithms: Set<FileHashAlgorithm>) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                if let url = url {
                    urls.append(url)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            self.fileHashProcessFiles(urls: urls, algorithms: algorithms)
        }
        
        return true
    }
    
    // MARK: - 处理文件
    private func fileHashProcessFiles(urls: [URL], algorithms: Set<FileHashAlgorithm>) {
        guard !urls.isEmpty else { return }
        
        fileHashIsProcessing = true
        fileHashErrorMessage = nil
        
        Task {
            for url in urls {
                await fileHashCalculateHash(for: url, algorithms: algorithms)
            }
            fileHashIsProcessing = false
        }
    }
    
    // MARK: - 计算哈希值
    private func fileHashCalculateHash(for url: URL, algorithms: Set<FileHashAlgorithm>) async {
        guard url.startAccessingSecurityScopedResource() else {
            fileHashErrorMessage = "无法访问文件: \(url.lastPathComponent)"
            return
        }
        
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0
            let fileName = url.lastPathComponent
            let filePath = url.path
            
            var hashes: [FileHashAlgorithm: String] = [:]
            
            // 读取文件数据
            let fileData = try Data(contentsOf: url)
            
            // 计算各种哈希值
            for algorithm in algorithms {
                let hash = await fileHashComputeHash(data: fileData, algorithm: algorithm)
                hashes[algorithm] = hash
            }
            
            let result = FileHashResult(
                fileName: fileName,
                fileSize: fileSize,
                filePath: filePath,
                hashes: hashes,
                fileHashCreatedDate: Date()
            )
            
            fileHashResults.append(result)
            
        } catch {
            fileHashErrorMessage = "处理文件失败: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 计算特定算法的哈希
    private func fileHashComputeHash(data: Data, algorithm: FileHashAlgorithm) async -> String {
        return await Task.detached {
            switch algorithm {
            case .md5:
                return await self.fileHashCalculateMD5(data: data)
            case .sha1:
                return await self.fileHashCalculateSHA1(data: data)
            case .sha256:
                return await self.fileHashCalculateSHA256(data: data)
            case .sha512:
                return await self.fileHashCalculateSHA512(data: data)
            }
        }.value
    }
    
    // MARK: - MD5 计算
    private func fileHashCalculateMD5(data: Data) -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBytes { bytes in
            _ = CC_MD5(bytes.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - SHA-1 计算
    private func fileHashCalculateSHA1(data: Data) -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes { bytes in
            _ = CC_SHA1(bytes.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - SHA-256 计算 (使用 CryptoKit)
    private func fileHashCalculateSHA256(data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - SHA-512 计算 (使用 CryptoKit)
    private func fileHashCalculateSHA512(data: Data) -> String {
        let hash = SHA512.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - 导出结果
    func fileHashExportResults() {
        guard !fileHashResults.isEmpty else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.text]
        panel.nameFieldStringValue = "hash_results.txt"
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let content = fileHashFormatResults()
                try content.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                fileHashErrorMessage = "导出失败: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - 格式化结果
    private func fileHashFormatResults() -> String {
        var lines: [String] = []
        lines.append("文件哈希计算结果")
        lines.append("生成时间: \(fileHashCurrentDateString())")
        lines.append(String(repeating: "=", count: 80))
        lines.append("")
        
        for (index, result) in fileHashResults.enumerated() {
            lines.append("[\(index + 1)] \(result.fileName)")
            lines.append("文件大小: \(result.fileHashFormattedSize)")
            lines.append("文件路径: \(result.filePath)")
            lines.append("")
            
            for algorithm in FileHashAlgorithm.allCases {
                if let hash = result.hashes[algorithm] {
                    lines.append("\(algorithm.rawValue): \(hash)")
                }
            }
            
            lines.append("")
            lines.append(String(repeating: "-", count: 80))
            lines.append("")
        }
        
        return lines.joined(separator: "\n")
    }
    
    // MARK: - 获取当前日期字符串
    private func fileHashCurrentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }
    
    // MARK: - 批量比对
    func fileHashCompareHashes(targetHash: String, algorithm: FileHashAlgorithm) -> [FileHashResult] {
        let normalizedTarget = targetHash.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        return fileHashResults.filter { result in
            if let hash = result.hashes[algorithm] {
                return hash.lowercased() == normalizedTarget
            }
            return false
        }
    }
    
    // MARK: - 清空结果
    func fileHashClearAll() {
        fileHashResults.removeAll()
        fileHashErrorMessage = nil
    }
    
    // MARK: - 删除单个结果
    func fileHashRemoveResult(_ result: FileHashResult) {
        fileHashResults.removeAll { $0.id == result.id }
    }
    
    // MARK: - 重新计算
    func fileHashRecalculate(result: FileHashResult, algorithms: Set<FileHashAlgorithm>) {
        guard let url = URL(string: "file://\(result.filePath)") else { return }
        
        fileHashIsProcessing = true
        
        Task {
            // 先移除旧结果
            fileHashResults.removeAll { $0.id == result.id }
            
            // 重新计算
            await fileHashCalculateHash(for: url, algorithms: algorithms)
            
            fileHashIsProcessing = false
        }
    }
    
    // MARK: - 复制所有哈希值
    func fileHashCopyAllHashes(result: FileHashResult) {
        var lines: [String] = []
        lines.append(result.fileName)
        
        for algorithm in FileHashAlgorithm.allCases {
            if let hash = result.hashes[algorithm] {
                lines.append("\(algorithm.rawValue): \(hash)")
            }
        }
        
        let content = lines.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }
}

// MARK: - CommonCrypto 桥接
// 确保项目中正确导入 CommonCrypto
// 如果遇到编译问题,需要在 Bridging Header 中添加:
// #import <CommonCrypto/CommonCrypto.h>

// MARK: - 文件哈希工具类
class FileHashCalculator {
    // MARK: - 大文件分块计算 (优化内存使用)
    static func fileHashCalculateLargeFile(url: URL, algorithm: FileHashAlgorithm, chunkSize: Int = 8192) async throws -> String {
        guard let fileHandle = try? FileHandle(forReadingFrom: url) else {
            throw FileHashError.cannotOpenFile
        }
        
        defer { try? fileHandle.close() }
        
        switch algorithm {
        case .md5:
            return try await fileHashCalculateMD5Chunked(fileHandle: fileHandle, chunkSize: chunkSize)
        case .sha1:
            return try await fileHashCalculateSHA1Chunked(fileHandle: fileHandle, chunkSize: chunkSize)
        case .sha256:
            return try await fileHashCalculateSHA256Chunked(fileHandle: fileHandle, chunkSize: chunkSize)
        case .sha512:
            return try await fileHashCalculateSHA512Chunked(fileHandle: fileHandle, chunkSize: chunkSize)
        }
    }
    
    // MARK: - MD5 分块计算
    private static func fileHashCalculateMD5Chunked(fileHandle: FileHandle, chunkSize: Int) async throws -> String {
        var context = CC_MD5_CTX()
        CC_MD5_Init(&context)
        
        try fileHandle.seek(toOffset: 0)
        
        while autoreleasepool(invoking: {
            let data = fileHandle.readData(ofLength: chunkSize)
            if data.isEmpty { return false }
            
            data.withUnsafeBytes { bytes in
                _ = CC_MD5_Update(&context, bytes.baseAddress, CC_LONG(data.count))
            }
            return true
        }) {}
        
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        CC_MD5_Final(&digest, &context)
        
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - SHA1 分块计算
    private static func fileHashCalculateSHA1Chunked(fileHandle: FileHandle, chunkSize: Int) async throws -> String {
        var context = CC_SHA1_CTX()
        CC_SHA1_Init(&context)
        
        try fileHandle.seek(toOffset: 0)
        
        while autoreleasepool(invoking: {
            let data = fileHandle.readData(ofLength: chunkSize)
            if data.isEmpty { return false }
            
            data.withUnsafeBytes { bytes in
                _ = CC_SHA1_Update(&context, bytes.baseAddress, CC_LONG(data.count))
            }
            return true
        }) {}
        
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        CC_SHA1_Final(&digest, &context)
        
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - SHA256 分块计算
    private static func fileHashCalculateSHA256Chunked(fileHandle: FileHandle, chunkSize: Int) async throws -> String {
        var context = CC_SHA256_CTX()
        CC_SHA256_Init(&context)
        
        try fileHandle.seek(toOffset: 0)
        
        while autoreleasepool(invoking: {
            let data = fileHandle.readData(ofLength: chunkSize)
            if data.isEmpty { return false }
            
            data.withUnsafeBytes { bytes in
                _ = CC_SHA256_Update(&context, bytes.baseAddress, CC_LONG(data.count))
            }
            return true
        }) {}
        
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256_Final(&digest, &context)
        
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - SHA512 分块计算
    private static func fileHashCalculateSHA512Chunked(fileHandle: FileHandle, chunkSize: Int) async throws -> String {
        var context = CC_SHA512_CTX()
        CC_SHA512_Init(&context)
        
        try fileHandle.seek(toOffset: 0)
        
        while autoreleasepool(invoking: {
            let data = fileHandle.readData(ofLength: chunkSize)
            if data.isEmpty { return false }
            
            data.withUnsafeBytes { bytes in
                _ = CC_SHA512_Update(&context, bytes.baseAddress, CC_LONG(data.count))
            }
            return true
        }) {}
        
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA512_DIGEST_LENGTH))
        CC_SHA512_Final(&digest, &context)
        
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - 文件哈希错误类型
enum FileHashError: LocalizedError {
    case cannotOpenFile
    case readError
    case invalidAlgorithm
    
    var errorDescription: String? {
        switch self {
        case .cannotOpenFile:
            return "无法打开文件"
        case .readError:
            return "读取文件时出错"
        case .invalidAlgorithm:
            return "不支持的哈希算法"
        }
    }
}
