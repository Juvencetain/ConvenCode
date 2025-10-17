import SwiftUI
internal import UniformTypeIdentifiers

// MARK: - 哈希算法类型
enum FileHashAlgorithm: String, CaseIterable {
    case md5 = "MD5"
    case sha1 = "SHA-1"
    case sha256 = "SHA-256"
    case sha512 = "SHA-512"
    
    var fileHashIconName: String {
        switch self {
        case .md5: return "lock.circle.fill"
        case .sha1: return "checkmark.shield.fill"
        case .sha256: return "key.fill"
        case .sha512: return "lock.shield.fill"
        }
    }
    
    var fileHashColor: Color {
        switch self {
        case .md5: return .orange
        case .sha1: return .blue
        case .sha256: return .green
        case .sha512: return .purple
        }
    }
}

// MARK: - 文件哈希结果模型
struct FileHashResult: Identifiable {
    let id = UUID()
    let fileName: String
    let fileSize: Int64
    let filePath: String
    var hashes: [FileHashAlgorithm: String] = [:]
    let fileHashCreatedDate: Date
    
    var fileHashFormattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}

// MARK: - 文件哈希计算器视图
struct FileHashView: View {
    @StateObject private var fileHashViewModel = FileHashViewModel()
    @State private var fileHashSelectedAlgorithms: Set<FileHashAlgorithm> = [.md5, .sha256]
    @State private var fileHashShowVerification = false
    @State private var fileHashVerificationHash = ""
    @State private var fileHashVerificationAlgorithm: FileHashAlgorithm = .sha256
    @State private var fileHashShowResults = false
    
    var body: some View {
        ZStack {
            // 背景
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 标题栏
                fileHashHeaderSection
                
                Divider().padding(.horizontal, 16)
                
                // 主内容
                ScrollView {
                    VStack(spacing: 16) {
                        // 算法选择区
                        fileHashAlgorithmSection
                        
                        // 文件操作区
                        fileHashFileOperationSection
                        
                        // 哈希验证区
                        if fileHashShowVerification {
                            fileHashVerificationSection
                        }
                        
                        // 结果统计
                        if !fileHashViewModel.fileHashResults.isEmpty {
                            fileHashStatsSection
                        }
                    }
                    .padding(16)
                }
                .padding(.bottom)
            }
        }
        .frame(width: 420, height: 620)
        .sheet(isPresented: $fileHashShowResults) {
            FileHashResultsView(
                results: $fileHashViewModel.fileHashResults,
                selectedAlgorithms: fileHashSelectedAlgorithms,
                onClear: { fileHashViewModel.fileHashClearAll() }
            )
        }
        .focusable(false)
    }
    
    // MARK: - 标题栏
    private var fileHashHeaderSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "number.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.green.gradient)
            
            Text("文件哈希计算器")
                .font(.system(size: 14, weight: .medium))
            
            Spacer()
            
            if fileHashViewModel.fileHashIsProcessing {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 16, height: 16)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - 算法选择区
    private var fileHashAlgorithmSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择哈希算法")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                ForEach(FileHashAlgorithm.allCases, id: \.self) { algorithm in
                    Button(action: {
                        if fileHashSelectedAlgorithms.contains(algorithm) {
                            if fileHashSelectedAlgorithms.count > 1 {
                                fileHashSelectedAlgorithms.remove(algorithm)
                            }
                        } else {
                            fileHashSelectedAlgorithms.insert(algorithm)
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: algorithm.fileHashIconName)
                                .font(.system(size: 14))
                            
                            Text(algorithm.rawValue)
                                .font(.system(size: 13, weight: .medium))
                            
                            Spacer()
                            
                            if fileHashSelectedAlgorithms.contains(algorithm) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(algorithm.fileHashColor)
                            }
                        }
                        .foregroundColor(fileHashSelectedAlgorithms.contains(algorithm) ? .primary : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(fileHashSelectedAlgorithms.contains(algorithm) ?
                                      algorithm.fileHashColor.opacity(0.15) :
                                      Color.white.opacity(0.08))
                        )
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    // MARK: - 文件操作区
    private var fileHashFileOperationSection: some View {
        VStack(spacing: 12) {
            // 添加文件按钮
            Button(action: { fileHashViewModel.fileHashSelectFiles(algorithms: fileHashSelectedAlgorithms) }) {
                HStack {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 16))
                    Text("选择文件")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue)
                )
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
            
            // 底部操作按钮
            if !fileHashViewModel.fileHashResults.isEmpty {
                HStack(spacing: 10) {
                    Button(action: { fileHashShowVerification.toggle() }) {
                        HStack {
                            Image(systemName: fileHashShowVerification ? "checkmark.seal.fill" : "checkmark.seal")
                            Text("验证")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(fileHashShowVerification ? Color.blue.opacity(0.2) : Color.white.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                    
                    Button(action: { fileHashShowResults = true }) {
                        HStack {
                            Image(systemName: "list.bullet.rectangle")
                            Text("查看结果")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                }
            }
        }
    }
    
    // MARK: - 哈希验证区
    private var fileHashVerificationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("哈希验证")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: { fileHashShowVerification = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
            }
            
            // 算法选择
            Picker("算法", selection: $fileHashVerificationAlgorithm) {
                ForEach(FileHashAlgorithm.allCases, id: \.self) { algorithm in
                    Text(algorithm.rawValue).tag(algorithm)
                }
            }
            .pickerStyle(.segmented)
            
            // 输入哈希值
            VStack(alignment: .leading, spacing: 6) {
                Text("输入哈希值")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                TextEditor(text: $fileHashVerificationHash)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(height: 60)
                    .padding(8)
                    .scrollContentBackground(.hidden) // 隐藏系统默认背景
                    .background(Color.clear) // 内容区透明
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.6), lineWidth: 1) // 深灰色边框
                    )

            }
            
            // 验证结果
            if !fileHashVerificationHash.isEmpty {
                fileHashVerificationResults
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    // MARK: - 验证结果
    private var fileHashVerificationResults: some View {
        VStack(spacing: 6) {
            ForEach(fileHashViewModel.fileHashResults) { result in
                if let hash = result.hashes[fileHashVerificationAlgorithm] {
                    let isMatch = hash.lowercased() == fileHashVerificationHash.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    HStack(spacing: 8) {
                        Image(systemName: isMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(isMatch ? .green : .red)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.fileName)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            
                            Text(isMatch ? "哈希匹配" : "哈希不匹配")
                                .font(.system(size: 10))
                                .foregroundColor(isMatch ? .green : .red)
                        }
                        
                        Spacer()
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill((isMatch ? Color.green : Color.red).opacity(0.1))
                    )
                }
            }
        }
    }
    
    // MARK: - 统计信息
    private var fileHashStatsSection: some View {
        VStack(spacing: 8) {
            Divider()
            
            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("\(fileHashViewModel.fileHashResults.count) 个文件")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "number.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("\(fileHashSelectedAlgorithms.count) 个算法")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - 结果列表视图
struct FileHashResultsView: View {
    @Binding var results: [FileHashResult]
    let selectedAlgorithms: Set<FileHashAlgorithm>
    let onClear: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 标题栏
                HStack {
                    Text("计算结果")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Spacer()
                    
                    Button(action: {
                        onClear()
                        dismiss()
                    }) {
                        Text("清空")
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                }
                .padding()
                
                Divider()
                
                // 结果列表
                if results.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.badge.ellipsis")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("暂无计算结果")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(results) { result in
                                fileHashResultRow(result)
                                if result.id != results.last?.id {
                                    Divider().padding(.leading)
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 500, idealWidth: 600, minHeight: 400, idealHeight: 500)
    }
    
    private func fileHashResultRow(_ result: FileHashResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 文件信息
            HStack(spacing: 10) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(result.fileName)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    
                    Text(result.fileHashFormattedSize)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // 哈希值列表
            VStack(spacing: 8) {
                ForEach(Array(selectedAlgorithms.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { algorithm in
                    if let hash = result.hashes[algorithm] {
                        fileHashValueRow(algorithm: algorithm, hash: hash)
                    }
                }
            }
        }
        .padding()
        .contentShape(Rectangle())
    }
    
    @State private var fileHashCopiedHash: String?
    
    private func fileHashValueRow(algorithm: FileHashAlgorithm, hash: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: algorithm.fileHashIconName)
                        .font(.system(size: 10))
                    Text(algorithm.rawValue)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(algorithm.fileHashColor)
                
                Spacer()
                
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(hash, forType: .string)
                    fileHashCopiedHash = hash
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        fileHashCopiedHash = nil
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: fileHashCopiedHash == hash ? "checkmark" : "doc.on.doc")
                        Text(fileHashCopiedHash == hash ? "已复制" : "复制")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(fileHashCopiedHash == hash ? .green : .blue)
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
            }
            
            Text(hash)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .textSelection(.enabled)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.05))
                )
        }
    }
}

#Preview {
    FileHashView()
}
