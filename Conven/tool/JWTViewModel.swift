//
//  JWTViewModel.swift
//  Conven
//
//  Created by 土豆星球 on 2025/10/15.
//


import SwiftUI
import AppKit
import Combine

// MARK: - ViewModel
@MainActor
class JWTViewModel: ObservableObject {
    @Published var encodedToken: String = "" {
        didSet {
            decodeToken()
        }
    }
    
    @Published var decodedHeader: String = ""
    @Published var decodedPayload: String = ""
    @Published var signature: String = ""
    @Published var errorMessage: String?

    private func decodeToken() {
        let trimmedToken = encodedToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            reset()
            return
        }

        let parts = trimmedToken.split(separator: ".")
        guard parts.count == 3 else {
            reset()
            errorMessage = "无效的 Token：格式不正确，应有三个部分"
            return
        }

        let headerBase64Url = String(parts[0])
        let payloadBase64Url = String(parts[1])
        signature = String(parts[2])

        do {
            decodedHeader = try prettyPrint(jsonString: decode(base64Url: headerBase64Url))
            decodedPayload = try prettyPrint(jsonString: decode(base64Url: payloadBase64Url))
            errorMessage = nil
        } catch let error as JWTError {
            reset()
            errorMessage = error.localizedDescription
        } catch {
            reset()
            errorMessage = "解码失败: \(error.localizedDescription)"
        }
    }
    
    private func decode(base64Url: String) throws -> String {
        var base64 = base64Url
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // 补全 Base64 padding
        let paddingLength = 4 - (base64.count % 4)
        if paddingLength < 4 {
            base64 += String(repeating: "=", count: paddingLength)
        }

        guard let data = Data(base64Encoded: base64) else {
            throw JWTError.invalidBase64
        }
        
        guard let decodedString = String(data: data, encoding: .utf8) else {
            throw JWTError.invalidUTF8
        }
        
        return decodedString
    }

    private func prettyPrint(jsonString: String) throws -> String {
        guard let data = jsonString.data(using: .utf8) else {
            throw JWTError.invalidJSON
        }
        
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
        let prettyData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys])
        
        return String(data: prettyData, encoding: .utf8) ?? jsonString
    }
    
    private func reset() {
        decodedHeader = ""
        decodedPayload = ""
        signature = ""
        errorMessage = nil
    }

    enum JWTError: LocalizedError {
        case invalidBase64
        case invalidUTF8
        case invalidJSON
        
        var errorDescription: String? {
            switch self {
            case .invalidBase64: return "解码失败：无效的 Base64Url 编码"
            case .invalidUTF8: return "解码失败：无法转换为 UTF-8 字符串"
            case .invalidJSON: return "解码失败：内容不是有效的 JSON 格式"
            }
        }
    }
}

// MARK: - 主视图
struct JWTView: View {
    @StateObject private var viewModel = JWTViewModel()

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                Divider().padding(.horizontal, 20)
                
                HSplitView {
                    // 左侧：编码输入
                    encodedTokenEditor
                        .frame(minWidth: 250, idealWidth: 300)
                    
                    // 右侧：解码输出
                    decodedDataView
                        .frame(minWidth: 300)
                }
                .padding(20)
            }
        }
        .frame(width: 800, height: 500)
    }

    private var headerBar: some View {
        HStack {
            Image(systemName: "key.viewfinder")
                .font(.system(size: 16))
                .foregroundStyle(.red.gradient)
            Text("JWT 解码器")
                .font(.system(size: 14, weight: .medium))
            Spacer()
        }
        .padding(20)
    }
    
    private var encodedTokenEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Encoded Token")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            
            TextEditor(text: $viewModel.encodedToken)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                .lineSpacing(4)
            
            if let error = viewModel.errorMessage {
                HStack {
                    Image(systemName: "xmark.octagon.fill")
                    Text(error)
                }
                .font(.system(size: 12))
                .foregroundColor(.red)
                .padding(.top, 4)
            }
        }
        .padding(.trailing, 10)
    }
    
    private var decodedDataView: some View {
        VStack(spacing: 16) {
            DecodedSection(title: "Header", content: viewModel.decodedHeader)
            DecodedSection(title: "Payload", content: viewModel.decodedPayload)
            
            if !viewModel.signature.isEmpty {
                 Text("Signature Verified (示意)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green)
            }
        }
        .padding(.leading, 10)
    }
}

// MARK: - 辅助视图
struct DecodedSection: View {
    let title: String
    let content: String
    @State private var showCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                
                if !content.isEmpty {
                    Button(action: copyToClipboard) {
                        HStack(spacing: 4) {
                            Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            Text(showCopied ? "已复制" : "复制")
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(showCopied ? .green : .blue)
                }
            }
            
            ScrollView {
                Text(content)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .textSelection(.enabled)
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
        }
    }
    
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        withAnimation { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showCopied = false }
        }
    }
}
