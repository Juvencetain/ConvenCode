import SwiftUI
import PDFKit

// MARK: - PDF 转图片主视图
struct PDFToImageView: View {
    @StateObject private var pdfToImageVM = PDFToImageViewModel()
     
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
           
            VStack(spacing: 0) {
                pdfToImageHeaderSection
                Divider().padding(.horizontal, 16)
                 
                if !pdfToImageVM.pdfToImageDocuments.isEmpty {
                    ScrollView {
                        VStack(spacing: 20) {
                            // 文件列表（多文件时显示）
                            if pdfToImageVM.pdfToImageDocuments.count > 1 {
                                pdfToImageFileListSection // <-- This section is modified
                            }
                           
                            pdfToImagePreviewSection
                            pdfToImageSettingsSection
                        }
                        .padding(20)
                    }
                } else {
                    pdfToImageEmptyState
                }
                 
                Divider()
                pdfToImageBottomBar
            }
        }
        .focusable(false)
        .frame(width: 800, height: 600)
        .alert(pdfToImageVM.pdfToImageAlertMessage, isPresented: $pdfToImageVM.pdfToImageShowAlert) {
            Button("确定", role: .cancel) { }
        }
    }
     
    // MARK: - 头部区域
    private var pdfToImageHeaderSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.richtext.fill")
                .font(.system(size: 16))
                .foregroundStyle(.red.gradient)
           
            Text("PDF 转图片")
                .font(.system(size: 14, weight: .medium))
           
            Spacer()
           
            if !pdfToImageVM.pdfToImageDocuments.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                     
                    Text(pdfToImageVM.pdfToImageFileName)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.05))
                .cornerRadius(6)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
     
    // MARK: - 空状态
    private var pdfToImageEmptyState: some View {
        VStack(spacing: 20) {
            Spacer()
           
            Image(systemName: "doc.fill.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(.secondary.opacity(0.5))
           
            Text("选择 PDF 文件开始转换")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
           
            Button(action: pdfToImageVM.pdfToImageSelectFile) {
                HStack(spacing: 8) {
                    Image(systemName: "folder")
                    Text("选择文件")
                }
                .font(.system(size: 13))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.blue.gradient)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
           
            Spacer()
        }
    }
     
    // MARK: - 文件列表区域 (MODIFIED)
    private var pdfToImageFileListSection: some View {
        VStack(spacing: 12) {
            // Header part (unchanged)
            HStack {
                Text("已选择的文件 (\(pdfToImageVM.pdfToImageDocuments.count))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                 
                Spacer()
                 
                Button(action: pdfToImageVM.pdfToImageSelectFile) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10))
                        Text("添加")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
            }
             
            // --- START OF MODIFICATION ---
             
            // Use ScrollViewReader to programmatically scroll
            ScrollViewReader { proxy in
                HStack(spacing: 8) {
                    // Left scroll button
                    Button(action: {
                        let newIndex = max(0, pdfToImageVM.pdfToImageSelectedDocIndex - 1)
                        pdfToImageVM.pdfToImageSelectDocument(at: newIndex)
                        withAnimation {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                    .pointingHandCursor()
                    .disabled(pdfToImageVM.pdfToImageSelectedDocIndex == 0) // Disable at start
                     
                    // Original ScrollView
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(pdfToImageVM.pdfToImageDocuments.enumerated()), id: \.offset) { index, docInfo in
                                PDFToImageFileCard(
                                    fileName: docInfo.url.lastPathComponent,
                                    pageCount: docInfo.document.pageCount,
                                    isSelected: index == pdfToImageVM.pdfToImageSelectedDocIndex,
                                    onTap: {
                                        pdfToImageVM.pdfToImageSelectDocument(at: index)
                                        // Also scroll to the item when tapped
                                        withAnimation {
                                            proxy.scrollTo(index, anchor: .center)
                                        }
                                    },
                                    onRemove: {
                                        pdfToImageVM.pdfToImageRemoveFile(at: index)
                                    }
                                )
                                .id(index) // Add ID for the proxy to target
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(height: 80)
                     
                    // Right scroll button
                    Button(action: {
                        let newIndex = min(pdfToImageVM.pdfToImageDocuments.count - 1, pdfToImageVM.pdfToImageSelectedDocIndex + 1)
                        pdfToImageVM.pdfToImageSelectDocument(at: newIndex)
                        withAnimation {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                    .pointingHandCursor()
                    .disabled(pdfToImageVM.pdfToImageSelectedDocIndex >= pdfToImageVM.pdfToImageDocuments.count - 1) // Disable at end
                }
            }
            // --- END OF MODIFICATION ---
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
     
    // MARK: - 预览区域
    private var pdfToImagePreviewSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("预览")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                 
                Spacer()
                 
                // 页面导航
                HStack(spacing: 8) {
                    Button(action: pdfToImageVM.pdfToImageGoToFirstPage) {
                        Image(systemName: "chevron.left.2")
                            .font(.system(size: 11))
                    }
                    .disabled(pdfToImageVM.pdfToImageCurrentPage == 0)
                     
                    Button(action: pdfToImageVM.pdfToImageGoToPreviousPage) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11))
                    }
                    .disabled(pdfToImageVM.pdfToImageCurrentPage == 0)
                     
                    Text("\(pdfToImageVM.pdfToImageCurrentPage + 1) / \(pdfToImageVM.pdfToImageTotalPages)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(minWidth: 60)
                     
                    Button(action: pdfToImageVM.pdfToImageGoToNextPage) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11))
                    }
                    .disabled(pdfToImageVM.pdfToImageCurrentPage >= pdfToImageVM.pdfToImageTotalPages - 1)
                     
                    Button(action: pdfToImageVM.pdfToImageGoToLastPage) {
                        Image(systemName: "chevron.right.2")
                            .font(.system(size: 11))
                    }
                    .disabled(pdfToImageVM.pdfToImageCurrentPage >= pdfToImageVM.pdfToImageTotalPages - 1)
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
                .pointingHandCursor()
            }
             
            // PDF 预览
            if let page = pdfToImageVM.pdfToImageCurrentPageObject {
                PDFToImagePagePreview(page: page)
                    .frame(height: 300)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
     
    // MARK: - 设置区域
    private var pdfToImageSettingsSection: some View {
        VStack(spacing: 16) {
            // 格式选择
            PDFToImageSettingRow(label: "输出格式", icon: "photo") {
                Picker("", selection: $pdfToImageVM.pdfToImageSelectedFormat) {
                    ForEach(PDFToImageViewModel.PDFToImageFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
             
            // JPEG 质量（仅在选择 JPEG 时显示）
            if pdfToImageVM.pdfToImageSelectedFormat == .jpeg {
                PDFToImageSettingRow(label: "JPEG 质量", icon: "slider.horizontal.3") {
                    HStack(spacing: 12) {
                        Slider(value: $pdfToImageVM.pdfToImageJPEGQuality, in: 0.1...1.0)
                            .frame(width: 150)
                         
                        Text("\(Int(pdfToImageVM.pdfToImageJPEGQuality * 100))%")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 40)
                    }
                }
            }
             
            // 质量选择
            PDFToImageSettingRow(label: "转换质量", icon: "sparkles") {
                Picker("", selection: $pdfToImageVM.pdfToImageSelectedQuality) {
                    ForEach(PDFToImageViewModel.PDFToImageQuality.allCases, id: \.self) { quality in
                        Text(quality.rawValue).tag(quality)
                    }
                }
                .frame(width: 200)
            }
             
            Divider()
             
            // 页面范围
            PDFToImageSettingRow(label: "页面范围", icon: "doc.text") {
                Picker("", selection: $pdfToImageVM.pdfToImagePageRangeOption) {
                    ForEach(PDFToImageViewModel.PDFToImagePageRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .frame(width: 200)
            }
             
            // 自定义范围
            if pdfToImageVM.pdfToImagePageRangeOption == .custom {
                PDFToImageSettingRow(label: "自定义范围", icon: "number") {
                    HStack(spacing: 8) {
                        TextField("起始页", text: $pdfToImageVM.pdfToImageCustomStartPage)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                         
                        Text("-")
                            .foregroundColor(.secondary)
                         
                        TextField("结束页", text: $pdfToImageVM.pdfToImageCustomEndPage)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
     
    // MARK: - 底部操作栏
    private var pdfToImageBottomBar: some View {
        HStack(spacing: 12) {
            Button(action: pdfToImageVM.pdfToImageSelectFile) {
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.system(size: 12))
                    Text("选择文件")
                        .font(.system(size: 12))
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
           
            Spacer()
           
            if pdfToImageVM.pdfToImageIsConverting {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: pdfToImageVM.pdfToImageProgress)
                            .frame(width: 200)
                         
                        if !pdfToImageVM.pdfToImageCurrentFileProgress.isEmpty {
                            Text(pdfToImageVM.pdfToImageCurrentFileProgress)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                     
                    Text("\(Int(pdfToImageVM.pdfToImageProgress * 100))%")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
            } else {
                Button(action: pdfToImageVM.pdfToImageStartConversion) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 12))
                        Text("开始转换")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        !pdfToImageVM.pdfToImageDocuments.isEmpty ?
                        Color.blue.gradient : Color.gray.gradient
                    )
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(pdfToImageVM.pdfToImageDocuments.isEmpty)
                .pointingHandCursor()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - 文件卡片组件
struct PDFToImageFileCard: View {
    let fileName: String
    let pageCount: Int
    let isSelected: Bool
    let onTap: () -> Void
    let onRemove: () -> Void
     
    @State private var isHovered = false
     
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 16))
                        .foregroundColor(isSelected ? .blue : .secondary)
                     
                    Spacer()
                     
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .opacity(isHovered ? 1 : 0)
                    .pointingHandCursor()
                }
                 
                Text(fileName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                 
                Text("\(pageCount) 页")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .frame(width: 140, height: 70)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.15) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .pointingHandCursor()
    }
}

// MARK: - 设置行组件
struct PDFToImageSettingRow<Content: View>: View {
    let label: String
    let icon: String
    @ViewBuilder let content: Content
     
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                    .frame(width: 16)
                 
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
            }
            .frame(width: 120, alignment: .leading)
           
            Spacer()
           
            content
        }
    }
}

// MARK: - PDF 页面预览组件
struct PDFToImagePagePreview: View {
    let page: PDFPage
     
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white
                 
                if let image = pdfToImageRenderPreviewImage(for: page, maxSize: geometry.size) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            }
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
    }
     
    private func pdfToImageRenderPreviewImage(for page: PDFPage, maxSize: CGSize) -> NSImage? {
        let bounds = page.bounds(for: .mediaBox)
         
        // 计算缩放比例以适应预览区域
        let widthScale = maxSize.width / bounds.width
        let heightScale = maxSize.height / bounds.height
        let scale = min(widthScale, heightScale, 2.0) // 限制最大缩放为 2x
         
        let size = CGSize(
            width: bounds.width * scale,
            height: bounds.height * scale
        )
         
        let image = NSImage(size: size)
        image.lockFocus()
         
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return nil
        }
         
        // 白色背景
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
         
        context.saveGState()
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)
        context.restoreGState()
         
        image.unlockFocus()
         
        return image
    }
}

// MARK: - Preview
#Preview {
    PDFToImageView()
}
