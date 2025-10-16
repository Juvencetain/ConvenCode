import SwiftUI

// MARK: - PDFExtractorView
struct PDFExtractorView: View {
    @StateObject private var viewModel = PDFExtractorViewModel()

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerSection
                Divider().padding(.horizontal, 16)
                
                if viewModel.isProcessing {
                    processingView
                } else {
                    mainContentView
                }
            }
        }
        .frame(width: 600, height: 650)
        .fileImporter(
            isPresented: $viewModel.showFileImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: true
        ) { result in
            viewModel.handleFileImport(result: result)
        }
    }

    // MARK: - Subviews
    private var headerSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(.orange.gradient)
            Text("PDF 数据解析")
                .font(.system(size: 14, weight: .medium))
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var mainContentView: some View {
        VStack(spacing: 20) {
            // 文件列表和操作
            fileManagementSection
            
            // 导出按钮
            exportSection
        }
        .padding(20)
    }

    private var fileManagementSection: some View {
        VStack {
            HStack {
                Button(action: { viewModel.showFileImporter = true }) {
                    Label("添加PDF文件", systemImage: "plus.circle.fill")
                }
                .buttonStyle(ModernButtonStyle(style: .accent))
                
                Spacer()
                
                if !viewModel.fileURLs.isEmpty {
                    Button(action: viewModel.clearFiles) {
                        Label("清空列表", systemImage: "trash")
                    }
                    .buttonStyle(ModernButtonStyle(style: .danger))
                }
            }
            
            if viewModel.fileURLs.isEmpty {
                emptyStateView
            } else {
                fileListView
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.fill")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
            Text("请添加一个或多个PDF文件")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color.black.opacity(0.1))
        .cornerRadius(12)
    }

    private var fileListView: some View {
        List {
            ForEach(viewModel.fileURLs, id: \.self) { url in
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.red)
                    Text(url.lastPathComponent)
                        .lineLimit(1)
                }
            }
            .onDelete(perform: viewModel.removeFile)
        }
        .listStyle(InsetListStyle())
        .frame(minHeight: 200, maxHeight: .infinity)
    }

    private var exportSection: some View {
        VStack(spacing: 15) {
            Text("点击下方按钮开始处理文件，并导出为 Excel 可读的 CSV 文件。")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: {
                Task {
                    await viewModel.processAndExport()
                }
            }) {
                Label("处理并导出为 CSV", systemImage: "square.and.arrow.down.fill")
                    .font(.headline)
            }
            .buttonStyle(ModernButtonStyle(style: .execute))
            .disabled(viewModel.fileURLs.isEmpty)
        }
    }
    
    private var processingView: some View {
        VStack(spacing: 20) {
            ProgressView(value: viewModel.progress) {
                Text("正在处理: \(viewModel.progressText)...")
            } currentValueLabel: {
                Text(String(format: "%.0f%%", viewModel.progress * 100))
            }
            .progressViewStyle(LinearProgressViewStyle())
            
            Text("正在从PDF文件中提取文本，请稍候...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


// MARK: - ViewModel for PDFExtractor
@MainActor
class PDFExtractorViewModel: ObservableObject {
    @Published var fileURLs: [URL] = []
    @Published var showFileImporter = false
    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    @Published var progressText: String = ""

    private let logic = PDFExtractorLogic()

    func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            // 避免重复添加
            for url in urls {
                if !fileURLs.contains(url) {
                    fileURLs.append(url)
                }
            }
        case .failure(let error):
            print("文件导入失败: \(error.localizedDescription)")
        }
    }
    
    func removeFile(at offsets: IndexSet) {
        fileURLs.remove(atOffsets: offsets)
    }
    
    func clearFiles() {
        fileURLs.removeAll()
    }
    
    func processAndExport() async {
        guard !fileURLs.isEmpty else { return }
        
        isProcessing = true
        progress = 0.0
        progressText = "准备开始"
        
        let results = await logic.processPDFs(urls: fileURLs)
        
        progressText = "转换数据为CSV"
        let csvString = logic.convertToCSV(results: results)
        progress = 1.0
        
        // 保存文件
        saveCSV(csvString)
        
        isProcessing = false
        fileURLs.removeAll() // 处理完成后清空列表
    }
    
    private func saveCSV(_ content: String) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.commaSeparatedText]
        savePanel.nameFieldStringValue = "Exported_PDF_Data_\(Date().timeIntervalSince1970).csv"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                // 添加BOM头以确保Excel正确识别UTF-8编码
                let bom = "\u{FEFF}"
                try (bom + content).write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("保存CSV文件失败: \(error.localizedDescription)")
            }
        }
    }
}


#Preview {
    PDFExtractorView()
}