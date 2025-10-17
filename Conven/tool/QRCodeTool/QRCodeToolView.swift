import SwiftUI
internal import UniformTypeIdentifiers

struct QRCodeToolView: View {
    @StateObject private var viewModel = QRCodeToolViewModel()
    @State private var qrCodeToolSelectedTab = 0

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.orange.gradient)
                    Text("二维码工具")
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                Divider()

                // Tab Switcher
                Picker("模式", selection: $qrCodeToolSelectedTab) {
                    Text("生成二维码").tag(0)
                    Text("识别二维码").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

                // Content based on tab
                if qrCodeToolSelectedTab == 0 {
                    QRCodeToolGeneratorView(viewModel: viewModel)
                } else {
                    QRCodeToolReaderView(viewModel: viewModel)
                }
            }
            
            // --- FIXED: Using the new generic ToolStatusView ---
            if let status = viewModel.qrCodeToolStatusMessage {
                ToolStatusView(message: status.text, isError: status.isError)
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }
}

// MARK: - Generator View

struct QRCodeToolGeneratorView: View {
    @ObservedObject var viewModel: QRCodeToolViewModel
    
    var body: some View {
        HSplitView {
            // Left: Input and Settings
            VStack(alignment: .leading, spacing: 16) {
                Text("输入内容")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                
                TextEditor(text: $viewModel.qrCodeToolInputText)
                    .font(.system(size: 13, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .background(Color.black.opacity(0.15))
                    .cornerRadius(8)
                    .onChange(of: viewModel.qrCodeToolInputText) { _ in
                        viewModel.qrCodeToolScheduleGeneration()
                    }
                
                Text("容错率")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                Picker("容错率", selection: $viewModel.qrCodeToolCorrectionLevel) {
                    ForEach(QRCodeToolCorrectionLevel.allCases) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.qrCodeToolCorrectionLevel) { _ in
                    viewModel.qrCodeToolScheduleGeneration()
                }
                
                Spacer()
            }
            .padding(20)
            .frame(minWidth: 300)
            
            // Right: QR Code Preview
            ZStack {
                if let image = viewModel.qrCodeToolGeneratedImage {
                    VStack(spacing: 20) {
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.none)
                            .aspectRatio(contentMode: .fit)
                            .padding()
                        
                        Button(action: {
                            viewModel.qrCodeToolSaveGeneratedImage()
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("保存图片")
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(20)
                } else {
                    Text("请输入内容以生成二维码")
                        .foregroundColor(.secondary)
                }
                
                if viewModel.qrCodeToolIsProcessing {
                    ProgressView().scaleEffect(1.5)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.1))
        }
        .onAppear {
            viewModel.qrCodeToolScheduleGeneration()
        }
    }
}

// MARK: - Reader View

struct QRCodeToolReaderView: View {
    @ObservedObject var viewModel: QRCodeToolViewModel
    
    var body: some View {
        ZStack {
            if let image = viewModel.qrCodeToolSelectedImageForReading {
                VStack(spacing: 16) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(8)
                        .shadow(radius: 5)
                        .padding()
                    
                    if let text = viewModel.qrCodeToolDetectedText {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("识别结果:")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button(action: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(text, forType: .string)
                                }) {
                                    Image(systemName: "doc.on.doc")
                                }
                                .buttonStyle(.plain)
                            }
                            ScrollView {
                                Text(text)
                                    .font(.system(size: 13, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(10)
                            .background(Color.black.opacity(0.15))
                            .cornerRadius(6)
                            .frame(minHeight: 60)
                        }
                        .padding(.horizontal)
                    }
                    
                    Button(action: {
                        viewModel.qrCodeToolSelectImageForReading()
                    }) {
                        Text("选择另一张图片")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom)
                }
                .padding()
            } else {
                // --- FIXED: Using the new generic ToolPlaceholderView ---
                ToolPlaceholderView(onSelect: viewModel.qrCodeToolSelectImageForReading)
            }
            
            if viewModel.qrCodeToolIsProcessing {
                ProgressView().scaleEffect(1.5)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            if let provider = providers.first {
                provider.loadDataRepresentation(forTypeIdentifier: "public.file-url") { data, error in
                    if let data = data, let path = String(data: data, encoding: .utf8), let url = URL(string: path) {
                        viewModel.qrCodeToolProcessImage(from: url)
                    }
                }
            }
            return true
        }
    }
}

// MARK: - Generic Reusable Helper Views

/// A generic view to display status messages (success or error).
struct ToolStatusView: View {
    let message: String
    let isError: Bool
    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                .foregroundColor(isError ? .red : .green)
            Text(message)
                .font(.system(size: 12))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow))
        .cornerRadius(20)
        .shadow(radius: 5)
        .offset(y: isVisible ? -20 : 50)
        .opacity(isVisible ? 1 : 0)
        .animation(.spring(), value: isVisible)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.isVisible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.isVisible = false
            }
        }
    }
}

/// A generic placeholder view for file selection via button or drag-and-drop.
struct ToolPlaceholderView: View {
    let onSelect: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("拖放文件到此处，或")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Button(action: onSelect) {
                Text("选择文件")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
    }
}


#Preview {
    QRCodeToolView()
}

