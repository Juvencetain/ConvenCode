////
////  ModernButtonStyle.swift
////  Conven
////
////  Created by 土豆星球 on 2025/10/11.
////
//
//
//import SwiftUI
//
//// MARK: - 现代化按钮样式
//struct ModernButtonStyle: ButtonStyle {
//    var style: ButtonStyleType = .normal
//    
//    enum ButtonStyleType {
//        case normal, accent, execute, danger
//    }
//    
//    func makeBody(configuration: Configuration) -> some View {
//        let colors = getColors(for: style, pressed: configuration.isPressed)
//        
//        return configuration.label
//            .font(.system(size: 12, weight: .medium))
//            .padding(.vertical, 7)
//            .padding(.horizontal, 14)
//            .background(colors.background)
//            .foregroundColor(colors.foreground)
//            .cornerRadius(8)
//            .overlay(
//                RoundedRectangle(cornerRadius: 8)
//                    .stroke(colors.border, lineWidth: style == .execute ? 0 : 1)
//            )
//            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
//            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
//            .pointingHandCursor()
//    }
//    
//    private func getColors(for style: ButtonStyleType, pressed: Bool) -> (background: Color, foreground: Color, border: Color) {
//        switch style {
//        case .normal:
//            return (
//                Color.white.opacity(pressed ? 0.15 : 0.1),
//                Color.primary,
//                Color.primary.opacity(pressed ? 0.4 : 0.25)
//            )
//        case .accent:
//            return (
//                Color.accentColor.opacity(0.2),
//                Color.accentColor,
//                Color.accentColor.opacity(pressed ? 0.6 : 0.4)
//            )
//        case .execute:
//            return (
//                Color.accentColor,
//                Color.white,
//                Color.clear
//            )
//        case .danger:
//            return (
//                Color.red.opacity(0.15),
//                Color.red.opacity(0.85),
//                Color.red.opacity(pressed ? 0.4 : 0.25)
//            )
//        }
//    }
//}
//
//// MARK: - 现代化文本编辑区域
//struct ModernTextArea: View {
//    let title: String
//    @Binding var text: String
//    let placeholder: String
//    let isEditable: Bool
//    let minHeight: CGFloat
//    
//    init(title: String, text: Binding<String>, placeholder: String = "", isEditable: Bool = true, minHeight: CGFloat = 120) {
//        self.title = title
//        self._text = text
//        self.placeholder = placeholder
//        self.isEditable = isEditable
//        self.minHeight = minHeight
//    }
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            HStack {
//                Text(title)
//                    .font(.system(size: 11, weight: .semibold))
//                    .foregroundColor(.secondary)
//                
//                if !isEditable && !text.isEmpty {
//                    Spacer()
//                    Button(action: {
//                        NSPasteboard.general.clearContents()
//                        NSPasteboard.general.setString(text, forType: .string)
//                    }) {
//                        HStack(spacing: 4) {
//                            Image(systemName: "doc.on.doc")
//                                .font(.system(size: 10))
//                            Text("复制")
//                                .font(.system(size: 10, weight: .medium))
//                        }
//                        .foregroundColor(.accentColor)
//                    }
//                    .buttonStyle(.plain)
//                    .pointingHandCursor()
//                    .transition(.scale.combined(with: .opacity))
//                }
//            }
//            
//            ZStack(alignment: .topLeading) {
//                RoundedRectangle(cornerRadius: 10)
//                    .fill(isEditable ? Color.white.opacity(0.15) : Color.white.opacity(0.08))
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 10)
//                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
//                    )
//                
//                if text.isEmpty && isEditable {
//                    Text(placeholder)
//                        .font(.system(.body, design: .monospaced))
//                        .foregroundColor(.secondary.opacity(0.5))
//                        .padding(12)
//                        .allowsHitTesting(false)
//                }
//                
//                TextEditor(text: $text)
//                    .font(.system(.body, design: .monospaced))
//                    .scrollContentBackground(.hidden)
//                    .padding(8)
//                    .allowsHitTesting(isEditable)
//                    .textSelection(.enabled)
//            }
//            .frame(minHeight: minHeight, maxHeight: .infinity)
//        }
//    }
//}
