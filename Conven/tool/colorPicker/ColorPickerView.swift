//
//  ColorPickerView.swift
//  Conven
//
//  Created by 土豆星球 on 2025/10/16.
//


import SwiftUI
import AppKit

struct ColorPickerView: View {
    @StateObject private var viewModel = ColorPickerViewModel()

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                headerBar
                
                colorPreview
                
                colorValueFields
                
                Spacer()
            }
            .padding(20)
        }
        .frame(width: 420, height: 560)
        .focusable(false)
        .overlay(alignment: .top) {
            if viewModel.showToast {
                toastView
            }
        }
    }

    private var headerBar: some View {
        HStack {
            Image(systemName: "eyedropper.halffull")
                .font(.system(size: 16))
                .foregroundStyle(.purple.gradient)
            Text("颜色选择器")
                .font(.system(size: 14, weight: .medium))
            Spacer()
        }
    }

    private var colorPreview: some View {
        HStack(spacing: 15) {
            ColorPicker("", selection: $viewModel.selectedColor, supportsOpacity: false)
                .labelsHidden()

            RoundedRectangle(cornerRadius: 10)
                .fill(viewModel.selectedColor)
                .frame(height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )

            Button(action: viewModel.pickColorFromScreen) {
                Image(systemName: "eyedropper")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .help("从屏幕拾取颜色")
        }
    }

    private var colorValueFields: some View {
        VStack(spacing: 12) {
            ColorValueRow(label: "HEX", value: $viewModel.hexValue, onCopy: { viewModel.copyValue(viewModel.hexValue) })
            ColorValueRow(label: "RGB", value: $viewModel.rgbValue, onCopy: { viewModel.copyValue(viewModel.rgbValue) })
            ColorValueRow(label: "HSL", value: $viewModel.hslValue, onCopy: { viewModel.copyValue(viewModel.hslValue) })
        }
    }

    private var toastView: some View {
        Text("✓ 已复制")
            .font(.system(size: 13))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.green.opacity(0.9))
            .foregroundColor(.white)
            .cornerRadius(20)
            .padding(.top, 60)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation {
                        viewModel.showToast = false
                    }
                }
            }
    }
}

struct ColorValueRow: View {
    let label: String
    @Binding var value: String
    let onCopy: () -> Void

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .frame(width: 40, alignment: .leading)
            
            TextField("", text: $value)
                .textFieldStyle(.plain)
                .font(.system(size: 14, design: .monospaced))
                .padding(8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
            
            Button(action: onCopy) {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.plain)
        }
    }
}

#if DEBUG
struct ColorPickerView_Previews: PreviewProvider {
    static var previews: some View {
        ColorPickerView()
    }
}
#endif
