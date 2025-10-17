//
//  MatchGameView.swift
//  Conven
//
//  Created by 土豆星球 on 2025/10/17.
//  Updated with smooth animations on 2025/10/17.
//

import SwiftUI

// MARK: - MatchGame View
struct MatchGameView: View {
    @StateObject private var matchGameViewModel = MatchGameViewModel()
    @State private var matchGameShowingRules = false
    @State private var pulseAnimation = false
    
    var body: some View {
        ZStack {
            // 背景渐变 - 添加呼吸动画
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.purple.opacity(pulseAnimation ? 0.35 : 0.3),
                    Color.pink.opacity(pulseAnimation ? 0.25 : 0.2),
                    Color.orange.opacity(pulseAnimation ? 0.15 : 0.1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    pulseAnimation = true
                }
            }
            
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                matchGameHeaderSection
                Divider().padding(.horizontal, 16)
                
                VStack(spacing: 16) {
                    matchGameScoreSection
                    matchGameBoardSection
                    matchGameControlSection
                }
                .padding(20)
            }
            
            if matchGameViewModel.matchGameIsGameOver {
                matchGameOverOverlay
            }
            
            if matchGameShowingRules {
                matchGameRulesOverlay
            }
        }
        .focusable(false)
        .frame(width: 520, height: 700)
    }
    
    // MARK: - Header Section
    private var matchGameHeaderSection: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.pink.opacity(0.2))
                    .frame(width: 32, height: 32)
                Image(systemName: "sparkles")
                    .font(.system(size: 16))
                    .foregroundStyle(.pink.gradient)
                    .rotationEffect(.degrees(pulseAnimation ? 5 : -5))
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulseAnimation)
            }
            Text("消消乐").font(.system(size: 16, weight: .semibold))
            Spacer()
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    matchGameShowingRules = true
                }
            }) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
            .scaleEffect(matchGameShowingRules ? 0.9 : 1)
            
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    matchGameViewModel.matchGameRestart()
                }
            }) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.pink.gradient)
                    .rotationEffect(.degrees(matchGameViewModel.matchGameScore > 0 ? 360 : 0))
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
    
    // MARK: - Score Section
    private var matchGameScoreSection: some View {
        HStack(spacing: 16) {
            MatchGameStatCard(
                icon: "star.fill",
                title: "分数",
                value: "\(matchGameViewModel.matchGameScore)",
                color: .yellow,
                shouldPulse: matchGameViewModel.matchGameCombo > 1
            )
            MatchGameStatCard(
                icon: "hand.tap.fill",
                title: "剩余步数",
                value: "\(matchGameViewModel.matchGameMoves)",
                color: .blue,
                shouldPulse: matchGameViewModel.matchGameMoves <= 5
            )
            MatchGameStatCard(
                icon: "bolt.fill",
                title: "连击",
                value: "×\(matchGameViewModel.matchGameCombo)",
                color: .orange,
                shouldPulse: matchGameViewModel.matchGameCombo > 0
            )
        }
    }
    
    // MARK: - Board Section (Canvas Implementation)
    private var matchGameBoardSection: some View {
        GeometryReader { geometry in
            let boardSize = min(geometry.size.width, geometry.size.height)
            let cellSize = boardSize / CGFloat(matchGameViewModel.matchGameGridSize)
            let gemSize = cellSize * 0.88
            
            Canvas { context, size in
                for (rowIndex, row) in matchGameViewModel.matchGameBoard.enumerated() {
                    for (colIndex, gem) in row.enumerated() {
                        let cellRect = CGRect(
                            x: CGFloat(colIndex) * cellSize,
                            y: CGFloat(rowIndex) * cellSize,
                            width: cellSize,
                            height: cellSize
                        )
                        
                        guard let gem = gem else { continue }
                        
                        let gemRect = CGRect(
                            x: cellRect.midX - gemSize / 2,
                            y: cellRect.midY - gemSize / 2,
                            width: gemSize,
                            height: gemSize
                        )
                        
                        let position = Position(row: rowIndex, col: colIndex)
                        let isMatching = matchGameViewModel.matchGameMatchingPositions.contains(position)
                        let isSelected = matchGameViewModel.matchGameSelectedPosition == position
                        
                        // 匹配动效 - 发光光晕
                        if isMatching {
                            let haloRect = gemRect.insetBy(dx: -gemSize * 0.25, dy: -gemSize * 0.25)
                            var haloContext = context
                            haloContext.addFilter(.blur(radius: 12))
                            haloContext.fill(
                                Path(ellipseIn: haloRect),
                                with: .color(gem.matchGameColor.opacity(0.7))
                            )
                            
                            // 额外的脉冲效果
                            let pulseRect = gemRect.insetBy(dx: -gemSize * 0.15, dy: -gemSize * 0.15)
                            haloContext.fill(
                                Path(ellipseIn: pulseRect),
                                with: .color(gem.matchGameColor.opacity(0.4))
                            )
                        }

                        // 宝石渐变填充
                        let gradient = Gradient(colors: [
                            gem.matchGameColor.opacity(0.9),
                            gem.matchGameColor.opacity(0.6)
                        ])
                        context.fill(
                            Path(ellipseIn: gemRect),
                            with: .linearGradient(
                                gradient,
                                startPoint: CGPoint(x: gemRect.midX, y: gemRect.minY),
                                endPoint: CGPoint(x: gemRect.midX, y: gemRect.maxY)
                            )
                        )
                        
                        // 高光效果
                        let highlightRect = CGRect(
                            x: gemRect.minX + gemSize * 0.15,
                            y: gemRect.minY + gemSize * 0.1,
                            width: gemSize * 0.4,
                            height: gemSize * 0.3
                        )
                        context.fill(
                            Path(ellipseIn: highlightRect),
                            with: .color(.white.opacity(0.3))
                        )

                        // 图标
                        let iconText = Text(Image(systemName: gem.matchGameIcon))
                            .font(.system(size: gemSize * 0.5, weight: .bold))
                            .foregroundColor(.white)
                        context.draw(iconText, in: gemRect)

                        // 选中状态 - 多层边框
                        if isSelected {
                            let selectionPath1 = Path(ellipseIn: gemRect.insetBy(dx: -4, dy: -4))
                            let selectionPath2 = Path(ellipseIn: gemRect.insetBy(dx: -2, dy: -2))
                            context.stroke(selectionPath1, with: .color(.white.opacity(0.6)), lineWidth: 2)
                            context.stroke(selectionPath2, with: .color(.white), lineWidth: 3)
                        }
                    }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        let col = Int(value.location.x / cellSize)
                        let row = Int(value.location.y / cellSize)
                        matchGameViewModel.matchGameSelectGem(at: Position(row: row, col: col))
                    }
            )
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.pink.opacity(0.4),
                                        Color.purple.opacity(0.3),
                                        Color.pink.opacity(0.4)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
            )
            .shadow(color: Color.pink.opacity(0.3), radius: 20, x: 0, y: 10)
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    // MARK: - Control Section
    private var matchGameControlSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.yellow.gradient)
                .scaleEffect(pulseAnimation ? 1.1 : 1.0)
            Text("点击相邻的宝石进行交换，连成3个或以上即可消除")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    // MARK: - Game Over Overlay
    private var matchGameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .transition(.opacity)
            
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.yellow.gradient)
                        .shadow(color: .yellow.opacity(0.5), radius: 20)
                        .rotationEffect(.degrees(pulseAnimation ? -5 : 5))
                    
                    Text("游戏结束")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.pink.gradient)
                }
                
                VStack(spacing: 16) {
                    HStack(spacing: 30) {
                        VStack(spacing: 4) {
                            Text("\(matchGameViewModel.matchGameScore)")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(.yellow.gradient)
                            Text("最终得分")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.pink.opacity(0.3), lineWidth: 1)
                        )
                )
                
                Button(action: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        matchGameViewModel.matchGameRestart()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise.circle.fill")
                        Text("再玩一局")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [.pink, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: .pink.opacity(0.5), radius: 10)
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
                .scaleEffect(pulseAnimation ? 1.02 : 1.0)
            }
            .padding(32)
            .frame(width: 360)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: .black.opacity(0.4), radius: 40)
            )
            .transition(.scale(scale: 0.8).combined(with: .opacity))
        }
    }
    
    // MARK: - Rules Overlay
    private var matchGameRulesOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        matchGameShowingRules = false
                    }
                }
            
            VStack(spacing: 20) {
                HStack {
                    Text("游戏规则")
                        .font(.system(size: 18, weight: .bold))
                    Spacer()
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            matchGameShowingRules = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    MatchGameRuleItem(
                        icon: "hand.tap.fill",
                        title: "如何消除",
                        description: "点击相邻的宝石进行交换，连成3个或以上同色宝石即可消除"
                    )
                    MatchGameRuleItem(
                        icon: "star.fill",
                        title: "计分规则",
                        description: "消除3个得10分，每多1个额外得5分。连击会有额外加成！"
                    )
                    MatchGameRuleItem(
                        icon: "flag.checkered.fill",
                        title: "游戏目标",
                        description: "在限定的步数内，尽可能获得更高的分数"
                    )
                    MatchGameRuleItem(
                        icon: "bolt.fill",
                        title: "连击系统",
                        description: "连续消除可以获得连击加成，分数会翻倍哦！"
                    )
                }
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        matchGameShowingRules = false
                    }
                }) {
                    Text("知道了")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.pink.gradient)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
            }
            .padding(24)
            .frame(width: 380)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: .black.opacity(0.3), radius: 30)
            )
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
    }
}

// MARK: - Subviews
struct MatchGameStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    var shouldPulse: Bool = false
    
    @State private var isPulsing = false
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color.gradient)
                .scaleEffect(isPulsing ? 1.2 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isPulsing)
            
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(color.gradient)
                .contentTransition(.numericText(countsDown: title.contains("步数")))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: value)
            
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(isPulsing ? 0.08 : 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(isPulsing ? 0.5 : 0.3), lineWidth: isPulsing ? 2 : 1)
                )
                .shadow(color: shouldPulse ? color.opacity(0.3) : .clear, radius: 10)
        )
        .onChange(of: shouldPulse) { newValue in
            if newValue {
                isPulsing = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isPulsing = false
                }
            }
        }
    }
}

struct MatchGameRuleItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.pink.gradient)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
        )
    }
}

#Preview { MatchGameView() }
