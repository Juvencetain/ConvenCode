//
//  MatchGameView.swift
//  Conven
//
//  Created by 土豆星球 on 2025/10/17.
//  Updated by Gemini on 2025/10/17 with Canvas renderer for maximum performance.
//

import SwiftUI

// MARK: - MatchGame View
struct MatchGameView: View {
    @StateObject private var matchGameViewModel = MatchGameViewModel()
    @State private var matchGameShowingRules = false
    
    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.purple.opacity(0.3),
                    Color.pink.opacity(0.2),
                    Color.orange.opacity(0.1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                matchGameHeaderSection
                Divider().padding(.horizontal, 16)
                
                VStack(spacing: 16) {
                    matchGameScoreSection
                    // [REWRITE] 整个棋盘现在由一个高性能的 Canvas 渲染
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
                Circle().fill(Color.pink.opacity(0.2)).frame(width: 32, height: 32)
                Image(systemName: "sparkles")
                    .font(.system(size: 16))
                    .foregroundStyle(.pink.gradient)
            }
            Text("消消乐").font(.system(size: 16, weight: .semibold))
            Spacer()
            Button(action: { matchGameShowingRules = true }) {
                Image(systemName: "questionmark.circle").font(.system(size: 16)).foregroundColor(.secondary)
            }.buttonStyle(.plain).pointingHandCursor()
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    matchGameViewModel.matchGameRestart()
                }
            }) {
                Image(systemName: "arrow.clockwise.circle.fill").font(.system(size: 18)).foregroundStyle(.pink.gradient)
            }.buttonStyle(.plain).pointingHandCursor()
        }.padding(.horizontal, 20).padding(.vertical, 14)
    }
    
    // MARK: - Score Section
    private var matchGameScoreSection: some View {
        HStack(spacing: 16) {
            MatchGameStatCard(icon: "star.fill", title: "分数", value: "\(matchGameViewModel.matchGameScore)", color: .yellow)
            MatchGameStatCard(icon: "hand.tap.fill", title: "剩余步数", value: "\(matchGameViewModel.matchGameMoves)", color: .blue)
            MatchGameStatCard(icon: "bolt.fill", title: "连击", value: "×\(matchGameViewModel.matchGameCombo)", color: .orange)
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
                        
                        if isMatching {
                            let haloRect = gemRect.insetBy(dx: -gemSize * 0.2, dy: -gemSize * 0.2)
                            context.fill(Path(ellipseIn: haloRect), with: .color(gem.matchGameColor.opacity(0.5)))
                            context.addFilter(.blur(radius: 10))
                        }

                        // [FIX] 创建 Gradient 数据结构，而不是 LinearGradient 视图
                        let gradient = Gradient(colors: [gem.matchGameColor, gem.matchGameColor.opacity(0.7)])
                        context.fill(
                            Path(ellipseIn: gemRect),
                            with: .linearGradient(
                                gradient,
                                startPoint: CGPoint(x: gemRect.midX, y: gemRect.minY),
                                endPoint: CGPoint(x: gemRect.midX, y: gemRect.maxY)
                            )
                        )

                        // [PERFORMANCE] 使用 Text 渲染图标以提高性能
                        let iconText = Text(Image(systemName: gem.matchGameIcon))
                            .font(.system(size: gemSize * 0.5, weight: .bold))
                            .foregroundColor(.white)
                        context.draw(iconText, in: gemRect)

                        if matchGameViewModel.matchGameSelectedPosition == position {
                            let selectionPath = Path(ellipseIn: gemRect.insetBy(dx: -3, dy: -3))
                            context.stroke(selectionPath, with: .color(.white), lineWidth: 3)
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
                            .stroke(Color.pink.opacity(0.3), lineWidth: 2)
                    )
            )
            .shadow(color: Color.pink.opacity(0.2), radius: 20, x: 0, y: 10)
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    // MARK: - Control Section
    private var matchGameControlSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb.fill").foregroundStyle(.yellow.gradient)
            Text("点击相邻的宝石进行交换，连成3个或以上即可消除").font(.system(size: 11)).foregroundColor(.secondary)
        }.padding(10).frame(maxWidth: .infinity).background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
    }
    
    // MARK: - Overlays (Game Over, Rules)
    private var matchGameOverOverlay: some View { ZStack{ Color.black.opacity(0.6).ignoresSafeArea() ; VStack(spacing:24){VStack(spacing:8){Image(systemName:"gamecontroller.fill").font(.system(size:60)).foregroundStyle(.yellow.gradient).shadow(color:.yellow.opacity(0.5),radius:20);Text("游戏结束").font(.system(size:28,weight:.bold)).foregroundStyle(.pink.gradient)}
    VStack(spacing:16){HStack(spacing:30){VStack(spacing:4){Text("\(matchGameViewModel.matchGameScore)").font(.system(size:32,weight:.bold)).foregroundStyle(.yellow.gradient);Text("最终得分").font(.system(size:12)).foregroundColor(.secondary)}}}.padding(20).background(RoundedRectangle(cornerRadius:16).fill(Color.white.opacity(0.1)))
    Button(action:{withAnimation(.spring(response:0.5,dampingFraction:0.7)){matchGameViewModel.matchGameRestart()}}){HStack{Image(systemName:"arrow.clockwise.circle.fill");Text("再玩一局")}.font(.system(size:15,weight:.semibold)).foregroundColor(.white).frame(maxWidth:.infinity).padding(.vertical,14).background(LinearGradient(colors:[.pink,.purple],startPoint:.leading,endPoint:.trailing)).cornerRadius(12)}.buttonStyle(.plain).pointingHandCursor()}.padding(32).frame(width:360).background(RoundedRectangle(cornerRadius:24).fill(Color(nsColor:.windowBackgroundColor)).shadow(color:.black.opacity(0.3),radius:30)).transition(.scale.combined(with:.opacity))}}
    
    private var matchGameRulesOverlay: some View { ZStack{ Color.black.opacity(0.6).ignoresSafeArea().onTapGesture{matchGameShowingRules=false};VStack(spacing:20){HStack{Text("游戏规则").font(.system(size:18,weight:.bold));Spacer();Button(action:{matchGameShowingRules=false}){Image(systemName:"xmark.circle.fill").font(.system(size:20)).foregroundStyle(.secondary)}.buttonStyle(.plain)}
    VStack(alignment:.leading,spacing:16){MatchGameRuleItem(icon:"hand.tap.fill",title:"如何消除",description:"点击相邻的宝石进行交换，连成3个或以上同色宝石即可消除");MatchGameRuleItem(icon:"star.fill",title:"计分规则",description:"消除3个得10分，每多1个额外得5分。连击会有额外加成！");MatchGameRuleItem(icon:"flag.checkered.fill",title:"游戏目标",description:"在限定的步数内，尽可能获得更高的分数");MatchGameRuleItem(icon:"bolt.fill",title:"连击系统",description:"连续消除可以获得连击加成，分数会翻倍哦！")}
    Button(action:{matchGameShowingRules=false}){Text("知道了").font(.system(size:14,weight:.semibold)).foregroundColor(.white).frame(maxWidth:.infinity).padding(.vertical,12).background(Color.pink.gradient).cornerRadius(10)}.buttonStyle(.plain).pointingHandCursor()}.padding(24).frame(width:380).background(RoundedRectangle(cornerRadius:20).fill(Color(nsColor:.windowBackgroundColor)).shadow(color:.black.opacity(0.3),radius:30))}}
}


// MARK: - Subviews (StatCard, RuleItem)
struct MatchGameStatCard:View{let icon:String;let title:String;let value:String;let color:Color;var body:some View{VStack(spacing:8){Image(systemName:icon).font(.system(size:20)).foregroundStyle(color.gradient);Text(value).font(.system(size:20,weight:.bold)).foregroundStyle(color.gradient).contentTransition(.numericText(countsDown:title.contains("步数"))).animation(.spring(response:0.3,dampingFraction:0.7),value:value);Text(title).font(.system(size:10)).foregroundColor(.secondary)}.frame(maxWidth:.infinity).padding(.vertical,14).background(RoundedRectangle(cornerRadius:12).fill(Color.white.opacity(0.05)).overlay(RoundedRectangle(cornerRadius:12).stroke(color.opacity(0.3),lineWidth:1)))}}
struct MatchGameRuleItem:View{let icon:String;let title:String;let description:String;var body:some View{HStack(alignment:.top,spacing:12){Image(systemName:icon).font(.system(size:18)).foregroundStyle(.pink.gradient).frame(width:24);VStack(alignment:.leading,spacing:4){Text(title).font(.system(size:13,weight:.semibold));Text(description).font(.system(size:11)).foregroundColor(.secondary).fixedSize(horizontal:false,vertical:true)}}.padding(12).frame(maxWidth:.infinity,alignment:.leading).background(RoundedRectangle(cornerRadius:10).fill(Color.white.opacity(0.05)))}}

#Preview { MatchGameView() }

