//import SwiftUI
//
//@available(macOS 12.0, *)
//struct TranslatorView: View {
//    // MARK: - State
//    @State private var inputText = ""
//    @State private var translatedText = ""
//    @State private var sourceLang = "en"
//    @State private var targetLang = "zh-Hans"
//    @State private var isTranslating = false
//    @State private var showToast = false
//    @State private var errorMessage: String?
//    
//    // 支持的语言列表
//    private let supportedLanguages: [(code: String, name: String)] = [
//        ("en", "英语"),
//        ("zh-Hans", "中文（简体）"),
//        ("ja", "日语"),
//        ("ko", "韩语"),
//        ("fr", "法语"),
//        ("de", "德语"),
//        ("es", "西班牙语"),
//        ("ru", "俄语")
//    ]
//
//    var body: some View {
//        ZStack {
//            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
//                .ignoresSafeArea()
//
//            VStack(spacing: 16) {
//                header
//                languageSelector
//                inputArea
//                actionButtons
//                outputArea
//                
//                if let errorMessage = errorMessage {
//                    Text(errorMessage)
//                        .font(.caption)
//                        .foregroundColor(.red)
//                        .padding(.top, 5)
//                }
//            }
//            .padding(20)
//        }
//        .frame(width: 420, height: 560)
//        .overlay(alignment: .top) {
//            if showToast {
//                toastView
//            }
//        }
//    }
//
//    // MARK: - Header
//    private var header: some View {
//        HStack {
//            Image(systemName: "character.bubble.fill")
//                .font(.system(size: 16))
//                .foregroundStyle(.pink.gradient)
//            Text("翻译工具")
//                .font(.system(size: 14, weight: .medium))
//            Spacer()
//        }
//    }
//
//    // MARK: - Language Selector
//    private var languageSelector: some View {
//        HStack {
//            LanguageMenu(selectedLang: $sourceLang, languages: supportedLanguages)
//
//            Button(action: swapLanguages) {
//                Image(systemName: "arrow.left.arrow.right")
//                    .font(.system(size: 14))
//            }
//            .buttonStyle(ModernButtonStyle())
//
//            LanguageMenu(selectedLang: $targetLang, languages: supportedLanguages)
//        }
//    }
//
//    // MARK: - Input
//    private var inputArea: some View {
//        ModernTextArea(
//            title: "输入 (\(languageDisplayName(for: sourceLang)))",
//            text: $inputText,
//            placeholder: "输入需要翻译的文本..."
//        )
//    }
//
//    // MARK: - Output
//    private var outputArea: some View {
//        ModernTextArea(
//            title: "翻译结果 (\(languageDisplayName(for: targetLang)))",
//            text: $translatedText,
//            placeholder: isTranslating ? "正在翻译中..." : "翻译结果将在这里显示...",
//            isEditable: false
//        )
//    }
//
//    // MARK: - Buttons
//    private var actionButtons: some View {
//        HStack {
//            Button(action: performTranslation) {
//                Label("翻译", systemImage: "play.fill")
//            }
//            .buttonStyle(ModernButtonStyle(style: .execute))
//            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTranslating)
//
//            Button(action: {
//                if !translatedText.isEmpty {
//                    NSPasteboard.general.clearContents()
//                    NSPasteboard.general.setString(translatedText, forType: .string)
//                    showToastMessage()
//                }
//            }) {
//                Label("复制", systemImage: "doc.on.doc")
//            }
//            .buttonStyle(ModernButtonStyle())
//            .disabled(translatedText.isEmpty)
//
//            Button(action: {
//                inputText = ""
//                translatedText = ""
//                errorMessage = nil
//            }) {
//                Image(systemName: "trash")
//            }
//            .buttonStyle(ModernButtonStyle(style: .danger))
//        }
//    }
//
//    // MARK: - Toast
//    private var toastView: some View {
//        Text("✓ 已复制到剪贴板")
//            .font(.system(size: 13))
//            .padding(.horizontal, 12)
//            .padding(.vertical, 8)
//            .background(Color.green.opacity(0.9))
//            .foregroundColor(.white)
//            .cornerRadius(20)
//            .padding(.top, 60)
//            .transition(.move(edge: .top).combined(with: .opacity))
//            .onAppear {
//                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//                    withAnimation { showToast = false }
//                }
//            }
//    }
//
//    // MARK: - Logic
//    private func swapLanguages() {
//        (sourceLang, targetLang) = (targetLang, sourceLang)
//        (inputText, translatedText) = (translatedText, inputText)
//    }
//
//    private func languageDisplayName(for code: String) -> String {
//        supportedLanguages.first { $0.code == code }?.name ?? code
//    }
//
//    private func showToastMessage() {
//        withAnimation { showToast = true }
//    }
//
//    private func performTranslation() {
//        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
//        guard !text.isEmpty else { return }
//
//        isTranslating = true
//        translatedText = ""
//        errorMessage = nil
//
//        // 使用模拟翻译API
//        Task {
//            do {
//                // 模拟网络延迟
//                try await Task.sleep(nanoseconds: 1_000_000_000)
//                
//                // 模拟翻译结果
//                let translation = try await simulateTranslation(
//                    text: text,
//                    source: sourceLang,
//                    target: targetLang
//                )
//                
//                await MainActor.run {
//                    translatedText = translation
//                    isTranslating = false
//                }
//            } catch {
//                await MainActor.run {
//                    errorMessage = "翻译失败: \(error.localizedDescription)"
//                    isTranslating = false
//                }
//            }
//        }
//    }
//    
//    private func simulateTranslation(text: String, source: String, target: String) async throws -> String {
//        // 模拟不同语言组合的翻译结果
//        switch (source, target) {
//        case ("en", "zh-Hans"):
//            return "这是英文到中文的翻译结果: \(text)"
//        case ("zh-Hans", "en"):
//            return "This is Chinese to English translation: \(text)"
//        case ("en", "ja"):
//            return "これは英語から日本語への翻訳です: \(text)"
//        case ("ja", "en"):
//            return "This is Japanese to English translation: \(text)"
//        case ("en", "ko"):
//            return "이것은 영어에서 한국어로의 번역입니다: \(text)"
//        case ("ko", "en"):
//            return "This is Korean to English translation: \(text)"
//        case ("en", "fr"):
//            return "Ceci est une traduction de l'anglais vers le français: \(text)"
//        case ("fr", "en"):
//            return "This is French to English translation: \(text)"
//        case ("en", "de"):
//            return "Dies ist eine Übersetzung vom Englischen ins Deutsche: \(text)"
//        case ("de", "en"):
//            return "This is German to English translation: \(text)"
//        case ("en", "es"):
//            return "Esta es una traducción del inglés al español: \(text)"
//        case ("es", "en"):
//            return "This is Spanish to English translation: \(text)"
//        case ("en", "ru"):
//            return "Это перевод с английского на русский: \(text)"
//        case ("ru", "en"):
//            return "This is Russian to English translation: \(text)"
//        default:
//            return "模拟翻译结果: \(text)"
//        }
//    }
//}
//
//// MARK: - Language Menu
//@available(macOS 12.0, *)
//struct LanguageMenu: View {
//    @Binding var selectedLang: String
//    let languages: [(code: String, name: String)]
//    
//    var body: some View {
//        Menu {
//            ForEach(languages, id: \.code) { lang in
//                Button(lang.name) { selectedLang = lang.code }
//            }
//        } label: {
//            HStack {
//                Text(languages.first { $0.code == selectedLang }?.name ?? selectedLang)
//                Spacer()
//                Image(systemName: "chevron.down")
//                    .font(.caption)
//            }
//            .frame(maxWidth: .infinity)
//            .padding(.horizontal, 12)
//            .padding(.vertical, 8)
//            .background(Color.secondary.opacity(0.1))
//            .cornerRadius(8)
//        }
//        .menuStyle(BorderlessButtonMenuStyle())
//        .frame(width: 140)
//    }
//}
//
//// MARK: - Preview
//@available(macOS 12.0, *)
//struct TranslatorView_Previews: PreviewProvider {
//    static var previews: some View {
//        TranslatorView()
//            .frame(width: 420, height: 560)
//    }
//}
