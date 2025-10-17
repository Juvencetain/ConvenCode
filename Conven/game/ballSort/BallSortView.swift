import SwiftUI

// MARK: - 主视图
struct BallSortView: View {
    @StateObject private var viewModel = BallSortViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var showHelpSheet = false

    var body: some View {
        ZStack {
            // 华丽的背景
            RadialGradient(
                gradient: Gradient(colors: [Color.indigo.opacity(0.5), Color.purple.opacity(0.3), Color.black]),
                center: .center,
                startRadius: 5,
                endRadius: 500
            )
            .ignoresSafeArea()

            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                Divider().padding(.horizontal, 20)

                if viewModel.isGameWon {
                    winView
                } else {
                    gameArea
                }
            }
        }
        .focusable(false)
        .frame(width: 480, height: 600)
        .font(.system(.body, design: .rounded))
        .sheet(isPresented: $showHelpSheet) {
            GameHelpView()
        }
    }

    // MARK: - 视图组件
    private var headerBar: some View {
        HStack {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 18))
                .foregroundStyle(.purple.gradient)
            Text("彩球排序")
                .font(.system(size: 16, weight: .semibold))
            Spacer()
            
            // 步数显示
            HStack(spacing: 6) {
                Image(systemName: "move.3d")
                Text("步数: \(viewModel.moveCount)")
            }
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .padding(.horizontal, 10)
            
            // 重置按钮
            Button(action: viewModel.resetGame) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(PlainButtonStyle())
            .help("新游戏")
            
            // 帮助按钮
            Button(action: { showHelpSheet = true }) {
                Image(systemName: "questionmark.circle.fill")
            }
            .buttonStyle(PlainButtonStyle())
            .help("游戏玩法")

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
    }
    
    private var gameArea: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                
                // 游戏网格
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: geometry.size.width / 10) {
                    ForEach(viewModel.tubes.indices, id: \.self) { index in
                        TubeView(
                            tube: viewModel.tubes[index],
                            isSelected: viewModel.selectedTubeIndex == index,
                            onTap: {
                                viewModel.selectTube(at: index)
                            }
                        )
                    }
                }
                
                Spacer()
                
                // 底部操作栏
                Button("撤销上一步") {
                    viewModel.undoMove()
                }
                .buttonStyle(ModernButtonStyle(style: .normal))
                .disabled(viewModel.moveCount == 0)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 20)
        }
    }
    
    private var winView: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("🎉")
                .font(.system(size: 80))
                .scaleEffect(1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.4).delay(0.2), value: viewModel.isGameWon)
            
            VStack {
                Text("恭喜你！")
                    .font(.largeTitle.bold())
                Text("你用了 \(viewModel.moveCount) 步完成了游戏")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            Button("再玩一局") {
                viewModel.resetGame()
            }
            .buttonStyle(ModernButtonStyle(style: .execute))
            .padding(.top)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }
}

// MARK: - 试管视图
struct TubeView: View {
    let tube: Tube
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 球
            VStack(spacing: 4) {
                Spacer(minLength: 0)
                ForEach(tube.balls.indices.reversed(), id: \.self) { index in
                    BallView(color: tube.balls[index])
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)

            // 玻璃管
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.3), lineWidth: 3)
                
                // 内壁高光
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                    .padding(3)
            }
        }
        .frame(height: 180)
        .frame(minWidth: 40, maxWidth: 48)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Color.white.opacity(0.1))
                if isSelected {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(Color.purple, lineWidth: 3)
                        .shadow(color: .purple, radius: 5)
                }
            }
        )
        .scaleEffect(isSelected ? 1.08 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        .onTapGesture(perform: onTap)
    }
}

// MARK: - 彩球视图
struct BallView: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [color.lighter(), color]),
                    center: .center,
                    startRadius: 1,
                    endRadius: 16
                )
            )
            .frame(width: 32, height: 32)
            .shadow(color: color.opacity(0.6), radius: 6, y: 4)
    }
}

// MARK: - Color 扩展
extension Color {
    func lighter(by percentage: CGFloat = 30.0) -> Color {
        return self.adjust(by: abs(percentage))
    }

    func adjust(by percentage: CGFloat) -> Color {
        guard let nsColor = NSColor(self).usingColorSpace(.sRGB) else {
            return self
        }
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        nsColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return Color(
            red: min(red + percentage / 100, 1.0),
            green: min(green + percentage / 100, 1.0),
            blue: min(blue + percentage / 100, 1.0),
            opacity: alpha
        )
    }
}

// MARK: - 游戏帮助视图
struct GameHelpView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Label("游戏玩法", systemImage: "questionmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.purple.gradient)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                
                Divider()

                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        HelpSection(
                            icon: "target",
                            title: "游戏目标",
                            content: "将所有相同颜色的彩球移动到同一个试管中。当每个试管都只包含一种颜色的彩球（或为空）时，游戏胜利。"
                        )
                        
                        HelpSection(
                            icon: "list.bullet.rectangle.portrait",
                            title: "游戏规则",
                            rules: [
                                "一次只能移动一个彩球。",
                                "只能将彩球移动到空的试管中。",
                                "或者，将彩球移动到另一个试管顶部颜色相同的彩球之上。",
                                "一个试管最多只能容纳 4 个彩球。"
                            ]
                        )

                        HelpSection(
                            icon: "hand.tap.fill",
                            title: "如何操作",
                            content: "1. **选择彩球**: 点击一个非空试管，最顶部的彩球会被选中。\n2. **移动彩球**: 再次点击另一个符合规则的目标试管，彩球就会移动过去。\n3. **取消选择**: 再次点击已选中的试管，可以取消选择。"
                        )
                        
                        HelpSection(
                            icon: "arrow.uturn.backward.circle.fill",
                            title: "遇到困难？",
                            content: "如果走错了，可以点击主界面上的 “撤销上一步” 按钮回到上一个状态。如果想重新开始，可以点击 “新游戏” 按钮。"
                        )
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 400, height: 500)
    }
}

struct HelpSection: View {
    let icon: String
    let title: String
    var content: String? = nil
    var rules: [String]? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(.primary)

            if let content = content {
                Text(content)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
            }
            
            if let rules = rules {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(rules, id: \.self) { rule in
                        HStack(alignment: .top) {
                            Text("•")
                                .foregroundColor(.purple)
                            Text(rule)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

