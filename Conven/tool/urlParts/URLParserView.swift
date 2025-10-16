//
//  URLParserView.swift
//  Conven
//
//  Created by 土豆星球 on 2025/10/15.
//


import SwiftUI
import Combine

// MARK: - URLParserView
struct URLParserView: View {
    
    @StateObject private var viewModel = URLParserViewModel()
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerSection
                Divider().padding(.horizontal, 16)
                
                VStack(spacing: 20) {
                    inputSection
                    if let parts = viewModel.urlParts {
                        resultSection(parts: parts)
                    } else if let errorMessage = viewModel.errorMessage {
                        ErrorView(message: errorMessage)
                    }
                    Spacer()
                }
                .padding(20)
            }
        }
        .frame(width: 420, height: 560)
    }
    
    private var headerSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "link.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.purple.gradient)
            
            Text("URL 解析器")
                .font(.system(size: 14, weight: .medium))
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    private var inputSection: some View {
        VStack(spacing: 10) {
            TextField("输入一个完整的 URL", text: $viewModel.urlString)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Button("解析") {
                viewModel.parseURL()
            }
            .buttonStyle(ModernButtonStyle(style: .execute))
            .disabled(viewModel.urlString.isEmpty)
        }
    }
    
    private func resultSection(parts: URLParts) -> some View {
        VStack(spacing: 10) {
            ResultDisplayRow(label: "协议", value: parts.scheme)
            ResultDisplayRow(label: "主机", value: parts.host)
            ResultDisplayRow(label: "路径", value: parts.path)
            
            if !parts.queryItems.isEmpty {
                DisclosureGroup("查询参数") {
                    ForEach(parts.queryItems, id: \.name) { item in
                        HStack {
                            Text(item.name).bold()
                            Spacer()
                            Text(item.value ?? "")
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - ViewModel for URLParser
class URLParserViewModel: ObservableObject {
    @Published var urlString: String = ""
    @Published var urlParts: URLParts?
    @Published var errorMessage: String?
    
    private let parser = URLParser()
    
    func parseURL() {
        let result = parser.parse(urlString: urlString)
        switch result {
        case .success(let parts):
            self.urlParts = parts
            self.errorMessage = nil
        case .failure(let error):
            self.urlParts = nil
            self.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Helper Views
struct ResultDisplayRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.bold)
        }
    }
}

struct ErrorView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .foregroundColor(.red)
            .padding()
            .background(Color.red.opacity(0.2))
            .cornerRadius(10)
    }
}

#Preview {
    URLParserView()
}
