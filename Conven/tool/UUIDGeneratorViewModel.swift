//
//  UUIDGeneratorViewModel.swift
//  Conven
//
//  Created by 土豆星球 on 2025/10/15.
//


import SwiftUI
import Combine

// MARK: - ViewModel
@MainActor
class UUIDGeneratorViewModel: ObservableObject {
    @Published var generatedUUIDs: [String] = []
    @Published var countToGenerate: Int = 5
    @Published var isUppercase: Bool = false
    @Published var includeHyphens: Bool = true
    
    @Published var showToast = false
    @Published var toastMessage = ""

    func generate() {
        var newUUIDs: [String] = []
        for _ in 0..<countToGenerate {
            var uuidString = UUID().uuidString
            if isUppercase {
                uuidString = uuidString.uppercased()
            }
            if !includeHyphens {
                uuidString = uuidString.replacingOccurrences(of: "-", with: "")
            }
            newUUIDs.append(uuidString)
        }
        // 将新生成的 UUID 插入到列表顶部
        generatedUUIDs.insert(contentsOf: newUUIDs, at: 0)
    }

    func clear() {
        generatedUUIDs.removeAll()
    }

    func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        
        toastMessage = "已复制!"
        withAnimation {
            showToast = true
        }
    }
    
    func copyAll() {
        let allUUIDs = generatedUUIDs.joined(separator: "\n")
        copyToClipboard(allUUIDs)
        toastMessage = "已复制全部 \(generatedUUIDs.count) 条 UUID!"
    }
}

// MARK: - 主视图
struct UUIDGeneratorView: View {
    @StateObject private var viewModel = UUIDGeneratorViewModel()

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                Divider().padding(.horizontal, 20)

                configurationSection
                Divider().padding(.horizontal, 20)

                resultsSection
            }
        }
        .frame(width: 420, height: 560)
        .overlay(alignment: .top) {
            if viewModel.showToast {
                toastView
            }
        }
        .focusable(false)
    }

    private var headerBar: some View {
        HStack {
            Image(systemName: "number.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.purple.gradient)
            Text("UUID/GUID 生成器")
                .font(.system(size: 14, weight: .medium))
            Spacer()
        }
        .padding(20)
    }

    private var configurationSection: some View {
        VStack(spacing: 15) {
            // 生成数量
            HStack {
                Text("生成数量")
                    .font(.system(size: 13))
                Spacer()
                Stepper("\(viewModel.countToGenerate)", value: $viewModel.countToGenerate, in: 1...100)
                    .font(.system(size: 13))
            }

            // 格式选项
            HStack {
                Toggle("大写 (UPPERCASE)", isOn: $viewModel.isUppercase)
                    .toggleStyle(.checkbox)
                
                Spacer()
                
                Toggle("包含连字符 (-)", isOn: $viewModel.includeHyphens)
                    .toggleStyle(.checkbox)
            }
            .font(.system(size: 13))

            // 操作按钮
            HStack(spacing: 10) {
                Button(action: viewModel.generate) {
                    Label("生成", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ModernButtonStyle(style: .execute))
                .keyboardShortcut(.return, modifiers: .command)

                Button(action: viewModel.clear) {
                    Label("清空", systemImage: "trash")
                }
                .buttonStyle(ModernButtonStyle(style: .danger))
                .disabled(viewModel.generatedUUIDs.isEmpty)
            }
        }
        .padding(20)
    }
    
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("生成结果 (\(viewModel.generatedUUIDs.count))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                if !viewModel.generatedUUIDs.isEmpty {
                    Button(action: viewModel.copyAll) {
                        Label("复制全部", systemImage: "doc.on.doc")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }
            }
            .padding(EdgeInsets(top: 15, leading: 20, bottom: 10, trailing: 20))

            if viewModel.generatedUUIDs.isEmpty {
                VStack {
                    Spacer()
                    Text("点击“生成”按钮创建 UUID")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.generatedUUIDs, id: \.self) { uuid in
                            UUIDRow(uuid: uuid, onCopy: {
                                viewModel.copyToClipboard(uuid)
                            })
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
    }
    
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { viewModel.showToast = false }
                }
            }
    }
}

// MARK: - UUID Row View
struct UUIDRow: View {
    let uuid: String
    let onCopy: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack {
            Text(uuid)
                .font(.system(size: 13, design: .monospaced))
                .textSelection(.enabled)
            
            Spacer()

            if isHovered {
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(10)
        .background(Color.white.opacity(isHovered ? 0.1 : 0.05))
        .cornerRadius(8)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}
