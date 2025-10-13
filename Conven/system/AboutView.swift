//
//  AboutView.swift
//  Conven
//
//  Created by 土豆星球 on 2025/10/13.
//


// ================================
// 创建新文件: AboutView.swift
// ================================

import SwiftUI
import AppKit

// MARK: - 关于视图
struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    @State private var qrCodeImage: NSImage?
    @State private var showCopiedToast = false
    
    private let email = "424261131@qq.com"
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 标题栏
                headerSection
                
                Divider()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Logo 区域
                        logoSection
                        
                        // 简介区域
                        introSection
                        
                        // 联系方式区域
                        contactSection
                        
                        // 打赏区域
                        donationSection
                    }
                    .padding(24)
                }
            }
            
            // 复制成功提示
            if showCopiedToast {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("邮箱已复制到剪贴板")
                            .font(.system(size: 13))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.8))
                    )
                    .foregroundColor(.white)
                    .padding(.bottom, 20)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(width: 450, height: 580)
        .focusable(false)
        .onAppear {
            loadQRCode()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.blue.gradient)
            
            Text("关于应用")
                .font(.system(size: 16, weight: .semibold))
            
            Spacer()
            
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    // MARK: - Logo Section
    private var logoSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Text("🐱")
                    .font(.system(size: 48))
            }
            
            Text("Conven")
                .font(.system(size: 24, weight: .bold))
            
            Text("版本 \(appVersion)")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Intro Section
    private var introSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(icon: "sparkles", title: "应用介绍")
            
            Text("Conven 是一款轻量级的菜单栏工具集，集成了剪贴板管理、IP 查询、HTTP 调试、数据处理等实用功能。同时内置了可爱的虚拟宠物陪伴系统，让工作更有趣味。")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .lineSpacing(4)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.1))
                )
            
            HStack(spacing: 16) {
                featureTag(icon: "hammer.fill", text: "业余开发", color: .orange)
                featureTag(icon: "heart.fill", text: "用爱发电", color: .pink)
                featureTag(icon: "square.and.arrow.up.fill", text: "持续更新", color: .blue)
            }
        }
    }
    
    // MARK: - Contact Section
    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(icon: "envelope.fill", title: "联系开发者")
            
            VStack(spacing: 10) {
                contactRow(
                    icon: "envelope.circle.fill",
                    label: "Bug 反馈 / 功能建议",
                    value: email,
                    color: .blue
                )
                
                Text("如果您在使用过程中遇到问题，或有任何功能建议，欢迎通过邮件与我联系")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.1))
            )
        }
    }
    
    // MARK: - Donation Section
    private var donationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(icon: "gift.fill", title: "支持开发")
            
            VStack(spacing: 16) {
                Text("如果这个应用对您有帮助，欢迎扫码请我喝杯咖啡 ☕️")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                
                // 二维码区域
                if let qrImage = qrCodeImage {
                    VStack(spacing: 8) {
                        Image(nsImage: qrImage)
                            .resizable()
                            .interpolation(.none)
                            .frame(width: 200, height: 200)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        
                        Text("扫码支持")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 200, height: 200)
                            .overlay(
                                VStack(spacing: 8) {
                                    Image(systemName: "qrcode")
                                        .font(.system(size: 40))
                                        .foregroundColor(.secondary)
                                    Text("未找到收款码")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            )
                        
                        Text("请在应用包中添加 qrcode.jpg")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
                
                Text("您的支持是我继续开发的动力 🙏")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }
    
    // MARK: - Helper Views
    private func sectionTitle(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.blue.gradient)
            
            Text(title)
                .font(.system(size: 15, weight: .semibold))
            
            Spacer()
        }
    }
    
    private func featureTag(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
    }
    
    private func contactRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            Button(action: {
                copyEmail()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                    Text("复制")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.blue.opacity(0.15))
                )
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
        }
    }
    
    // MARK: - Helper Methods
    private func loadQRCode() {
        // 尝试从多个可能的位置加载二维码图片
        let possiblePaths = [
            Bundle.main.path(forResource: "qrcode", ofType: "jpg"),
            Bundle.main.path(forResource: "qrcode", ofType: "png"),
            Bundle.main.resourcePath?.appending("/qrcode.jpg"),
            Bundle.main.resourcePath?.appending("/qrcode.png")
        ]
        
        for path in possiblePaths {
            if let validPath = path, let image = NSImage(contentsOfFile: validPath) {
                qrCodeImage = image
                print("✅ 成功加载收款码: \(validPath)")
                return
            }
        }
        
        print("⚠️ 未找到收款码图片，请在项目中添加 qrcode.jpg")
    }
    
    private func copyEmail() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(email, forType: .string)
        
        withAnimation {
            showCopiedToast = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedToast = false
            }
        }
    }
}

// MARK: - Preview
#Preview {
    AboutView()
}
