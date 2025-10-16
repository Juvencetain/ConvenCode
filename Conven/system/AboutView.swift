import SwiftUI
import AppKit
import Combine

// MARK: - 致谢数据模型
fileprivate struct AcknowledgedPerson: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let contribution: String
    let icon: String
    let color: Color
}

// MARK: - 致谢 ViewModel
fileprivate class AcknowledgeViewModel: ObservableObject {
    @Published var acknowledgePeople: [AcknowledgedPerson] = []
    
    init() {
        self.acknowledgePeople = [
            AcknowledgedPerson(
                name: "sudo",
                contribution: "开发者",
                icon: "terminal.fill",
                color: .black
            ),
            AcknowledgedPerson(
                name: "@啦啦啦@",
                contribution: "开发者",
                icon: "music.note.list",
                color: .purple
            ),
            AcknowledgedPerson(
                name: "小张牛宝",
                contribution: "开发者",
                icon: "lightbulb.fill",
                color: .yellow
            ),
            AcknowledgedPerson(
                name: "明天会更好",
                contribution: "参与应用共建",
                icon: "sun.max.fill",
                color: .orange
            ),
            AcknowledgedPerson(
                name: "茂子哥",
                contribution: "参与应用共建",
                icon: "figure.strengthtraining.traditional",
                color: .blue
            ),
            AcknowledgedPerson(
                name: "小敏子",
                contribution: "参与应用共建",
                icon: "sparkles",
                color: .pink
            ),
            AcknowledgedPerson(
                name: "小姓吴",
                contribution: "参与应用共建",
                icon: "book.fill",
                color: .cyan
            ),
            AcknowledgedPerson(
                name: "吴优无虑",
                contribution: "参与应用共建",
                icon: "cloud.sun.fill",
                color: .teal
            ),
            AcknowledgedPerson(
                name: "L",
                contribution: "参与应用共建",
                icon: "bolt.fill",
                color: .indigo
            ),
            AcknowledgedPerson(
                name: "惠达卫浴",
                contribution: "参与应用共建",
                icon: "drop.fill",
                color: .mint
            ),
            AcknowledgedPerson(
                name: "jnwu",
                contribution: "参与应用共建",
                icon: "gearshape.fill",
                color: .blue
            ),
            AcknowledgedPerson(
                name: "黑博",
                contribution: "参与应用共建",
                icon: "globe",
                color: .gray
            ),
            AcknowledgedPerson(
                name: "mc伟",
                contribution: "参与应用共建",
                icon: "cube.fill",
                color: .red
            ),
            AcknowledgedPerson(
                name: "开飞机舒克",
                contribution: "参与应用共建",
                icon: "airplane",
                color: .blue
            ),
            AcknowledgedPerson(
                name: "LYC",
                contribution: "参与应用共建",
                icon: "bubble.left.and.text.bubble.right.fill",
                color: .green
            ),
            AcknowledgedPerson(
                name: "水哥",
                contribution: "参与应用共建",
                icon: "drop.circle.fill",
                color: .cyan
            ),
            AcknowledgedPerson(
                name: "躺赢选手",
                contribution: "参与应用共建",
                icon: "bed.double.fill",
                color: .purple
            ),
            AcknowledgedPerson(
                name: "ocket Sun",
                contribution: "参与应用共建",
                icon: "flame.fill",
                color: .orange
            ),
            AcknowledgedPerson(
                name: "跑调Joy",
                contribution: "参与应用共建",
                icon: "waveform.path.ecg",
                color: .pink
            ),
            AcknowledgedPerson(
                name: "汽水气泡Soda",
                contribution: "参与应用共建",
                icon: "sparkle.magnifyingglass",
                color: .mint
            ),
            AcknowledgedPerson(
                name: "澄",
                contribution: "参与应用共建",
                icon: "circle.lefthalf.filled",
                color: .blue
            ),
            AcknowledgedPerson(
                name: "韭菜本菜",
                contribution: "参与应用共建",
                icon: "leaf.fill",
                color: .green
            ),
            AcknowledgedPerson(
                name: "夜航船",
                contribution: "参与应用共建",
                icon: "moon.stars.fill",
                color: .indigo
            ),
            AcknowledgedPerson(
                name: "24帧生活",
                contribution: "参与应用共建",
                icon: "film.fill",
                color: .yellow
            )
        ]
    }
}

// MARK: - 关于视图
struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    @State private var qrCodeImage: NSImage?
    @State private var showCopiedToast = false
    @StateObject private var acknowledgeViewModel = AcknowledgeViewModel()
    
    @State private var itemsPerPage: Int = 4
    @State private var currentPageIndex: Int = 0
    @State private var dragOffset: CGFloat = .zero
    
    // --- BUG FIX ---
    // State to track hover over the carousel to pause auto-scrolling
    @State private var isHoveringAcknowledge = false
    // A reference to the timer to allow invalidation
    @State private var autoScrollTimer: Timer?
    // --- END BUG FIX ---
    
    private let email = "424261131@qq.com（交流群：1065476363）"
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerSection
                Divider()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        logoSection
                        introSection
                        contactSection
                        donationSection
                        acknowledgeSection
                    }
                    .padding(24)
                }
            }
            
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
        .frame(minWidth: 400, idealWidth: 450, maxWidth: 500, minHeight: 500, idealHeight: 600, maxHeight: 700)
        .focusable(false)
        .onAppear {
            loadQRCode()
            setupAutoScroll() // Use the new timer setup method
        }
        .onDisappear {
            // Invalidate the timer when the view disappears to prevent memory leaks
            autoScrollTimer?.invalidate()
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
            .aboutCursor()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    // MARK: - Logo Section
    private var logoSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
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
        .frame(maxWidth: .infinity)
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
                        .fill(Color.white.opacity(0.05))
                )
            
            HStack(spacing: 16) {
                featureTag(icon: "hammer.fill", text: "业余开发", color: .orange)
                featureTag(icon: "heart.fill", text: "用爱发电", color: .pink)
                featureTag(icon: "square.and.arrow.up.fill", text: "持续更新", color: .blue)
            }
            .frame(maxWidth: .infinity)
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
                    .fill(Color.white.opacity(0.05))
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
                
                if let qrImage = qrCodeImage {
                    VStack(spacing: 8) {
                        Image(nsImage: qrImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 200, height: 200)
                            .clipped()
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        
                        Text("扫码支持")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
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

    // MARK: - Acknowledge Section (macOS 兼容分页)
    private var acknowledgeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(icon: "sparkles", title: "特别致谢")
            
            let chunkedPeople = acknowledgeViewModel.acknowledgePeople.chunked(into: itemsPerPage)
            let pageCount = chunkedPeople.count
            
            let rowCount = (itemsPerPage + 1) / 2
            let cardHeight: CGFloat = 85
            let totalHeight = (cardHeight * CGFloat(rowCount)) + (16 * CGFloat(rowCount - 1))

            VStack(spacing: 0) {
                GeometryReader { geometry in
                    let pageWidth = geometry.size.width
                    
                    HStack(spacing: 0) {
                        ForEach(Array(chunkedPeople.enumerated()), id: \.offset) { pageIndex, peopleOnPage in
                            let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
                            
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(peopleOnPage) { person in
                                    AcknowledgeCardView(person: person)
                                }
                            }
                            .padding(.horizontal)
                            .frame(width: pageWidth)
                        }
                    }
                    .offset(x: -CGFloat(currentPageIndex) * pageWidth + dragOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation.width
                            }
                            .onEnded { value in
                                let threshold = pageWidth / 5
                                var newIndex = currentPageIndex
                                
                                if value.translation.width < -threshold {
                                    newIndex = min(currentPageIndex + 1, pageCount - 1)
                                } else if value.translation.width > threshold {
                                    newIndex = max(currentPageIndex - 1, 0)
                                }
                                
                                // --- 优化部分: 更灵敏的弹性动画 ---
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    dragOffset = .zero
                                    currentPageIndex = newIndex
                                }
                            }
                    )
                }
                .frame(height: totalHeight)
                .clipped()
                
                if pageCount > 1 {
                    HStack(spacing: 8) {
                        ForEach(0..<pageCount, id: \.self) { index in
                            Circle()
                                .fill(currentPageIndex == index ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .scaleEffect(currentPageIndex == index ? 1.2 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: currentPageIndex)
                                .onTapGesture {
                                    withAnimation(.spring()) {
                                        currentPageIndex = index
                                    }
                                }
                                .aboutCursor()
                        }
                    }
                    .padding(.top, 16)
                }
            }
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.1),
                                Color.purple.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.3),
                                Color.purple.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        // --- BUG FIX ---
        // Add onHover to the entire section to control the auto-scroll pause
        .onHover { hovering in
            isHoveringAcknowledge = hovering
        }
        // --- END BUG FIX ---
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
            .aboutCursor()
        }
    }
    
    // MARK: - Helper Methods
    private func setupAutoScroll() {
        // Calculate the number of pages
        let pageCount = (acknowledgeViewModel.acknowledgePeople.count + itemsPerPage - 1) / itemsPerPage
        // Don't start the timer if there's only one page or less
        guard pageCount > 1 else { return }
        
        // Create the timer that will advance the page
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            // --- BUG FIX ---
            // Check if the mouse is hovering over the section. If so, do not advance the page.
            guard !isHoveringAcknowledge else { return }
            
            // Animate to the next page, looping back to the start if at the end
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                currentPageIndex = (currentPageIndex + 1) % pageCount
            }
        }
    }
    
    private func loadQRCode() {
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

// MARK: - 致谢卡片视图 (已优化)
fileprivate struct AcknowledgeCardView: View {
    let person: AcknowledgedPerson
    @State private var isHovering = false // 用于鼠标悬停状态
    
    var body: some View {
        VStack(spacing: 5) {
            // 图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                person.color.opacity(0.3),
                                person.color.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                Image(systemName: person.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(person.color.gradient)
            }
            
            // 名称
            Text(person.name)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.primary)
            
            // 贡献
            Text(person.contribution)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .padding(.vertical, 2)
        // --- 优化部分: 悬停交互 ---
        .scaleEffect(isHovering ? 1.08 : 1.0)
        .shadow(color: .black.opacity(isHovering ? 0.2 : 0), radius: 8, y: 4)
        .onHover { hovering in
            // --- BUG FIX: 修复悬停频闪问题 ---
            // 使用更平滑的 easeInOut 动画，以避免在快速切换悬停目标时，
            // 复杂的 spring 动画（一个移出、一个移入）之间相互干扰导致视觉闪烁。
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - 辅助扩展
extension View {
    func aboutCursor() -> some View {
        self.onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}


// MARK: - Preview
#Preview {
    AboutView()
}

