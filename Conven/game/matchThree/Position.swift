//
//  MatchGameModels.swift
//  Conven
//
//  Created by 土豆星球 on 2025/10/17.
//  Updated with smooth animations on 2025/10/17.
//

import SwiftUI
import Combine

// MARK: - Position
struct Position: Equatable, Hashable {
    let row: Int
    let col: Int
}

// MARK: - MatchGame Gem
struct MatchGameGem: Identifiable, Equatable {
    let id = UUID()
    let matchGameType: Int
    
    var matchGameColor: Color {
        switch matchGameType {
        case 0: return .red
        case 1: return .blue
        case 2: return .green
        case 3: return .yellow
        case 4: return .purple
        case 5: return .orange
        default: return .gray
        }
    }
    
    var matchGameIcon: String {
        switch matchGameType {
        case 0: return "heart.fill"
        case 1: return "star.fill"
        case 2: return "leaf.fill"
        case 3: return "sun.max.fill"
        case 4: return "moon.fill"
        case 5: return "flame.fill"
        default: return "circle.fill"
        }
    }
}

// MARK: - MatchGame ViewModel
class MatchGameViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var matchGameBoard: [[MatchGameGem?]]
    @Published var matchGameScore: Int = 0
    @Published var matchGameMoves: Int
    @Published var matchGameCombo: Int = 0
    @Published var matchGameSelectedPosition: Position?
    @Published var matchGameMatchingPositions: Set<Position> = []
    @Published var matchGameIsGameOver: Bool = false
    
    // MARK: - Properties
    let matchGameGridSize: Int = 8
    let matchGameGemTypes: Int = 6
    let matchGameMoveLimit: Int = 30
    
    // MARK: - Private Properties
    private enum GameState { case idle, processing }
    private var gameState: GameState = .idle
    private var matchGameComboTimer: Timer?
    
    // MARK: - Init
    init() {
        self.matchGameMoves = matchGameMoveLimit
        self.matchGameBoard = Array(repeating: Array(repeating: nil, count: matchGameGridSize), count: matchGameGridSize)
        matchGameInitializeBoard()
    }
    
    // MARK: - Public Methods
    func matchGameRestart() {
        gameState = .idle
        matchGameScore = 0
        matchGameMoves = matchGameMoveLimit
        matchGameCombo = 0
        matchGameIsGameOver = false
        matchGameSelectedPosition = nil
        matchGameMatchingPositions = []
        matchGameInitializeBoard()
    }
    
    func matchGameSelectGem(at position: Position) {
        guard position.row >= 0 && position.row < matchGameGridSize &&
              position.col >= 0 && position.col < matchGameGridSize else { return }
        guard gameState == .idle, !matchGameIsGameOver else { return }
        
        if let selected = matchGameSelectedPosition {
            if matchGameIsAdjacent(selected, position) {
                matchGameSwapGems(at: selected, and: position)
                matchGameSelectedPosition = nil
            } else {
                // 添加平滑的选择切换动画
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    matchGameSelectedPosition = position
                }
            }
        } else {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                matchGameSelectedPosition = position
            }
        }
    }
    
    // MARK: - Private Methods (Game Logic)
    private func matchGameInitializeBoard() {
        for row in 0..<matchGameGridSize {
            for col in 0..<matchGameGridSize {
                matchGameBoard[row][col] = MatchGameGem(matchGameType: Int.random(in: 0..<matchGameGemTypes))
            }
        }
        
        while findMatches().isEmpty == false {
            clearMatches(animated: false)
            fillEmptySpaces(animated: false)
        }
        self.matchGameScore = 0
    }
    
    private func matchGameIsAdjacent(_ pos1: Position, _ pos2: Position) -> Bool {
        let rowDiff = abs(pos1.row - pos2.row)
        let colDiff = abs(pos1.col - pos2.col)
        return (rowDiff == 1 && colDiff == 0) || (rowDiff == 0 && colDiff == 1)
    }
    
    private func matchGameSwapGems(at pos1: Position, and pos2: Position) {
        gameState = .processing
        
        // 更流畅的交换动画
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            let temp = matchGameBoard[pos1.row][pos1.col]
            matchGameBoard[pos1.row][pos1.col] = matchGameBoard[pos2.row][pos2.col]
            matchGameBoard[pos2.row][pos2.col] = temp
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let matches = self.findMatches()
            if !matches.isEmpty {
                self.matchGameMoves -= 1
                self.processMatches()
            } else {
                // 无效交换 - 弹回动画
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    let temp = self.matchGameBoard[pos1.row][pos1.col]
                    self.matchGameBoard[pos1.row][pos1.col] = self.matchGameBoard[pos2.row][pos2.col]
                    self.matchGameBoard[pos2.row][pos2.col] = temp
                }
                self.gameState = .idle
            }
        }
    }

    private func processMatches() {
        let matches = findMatches()
        
        if matches.isEmpty {
            // 连击结束，平滑过渡
            if matchGameCombo > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        self.matchGameCombo = 0
                    }
                }
            }
            gameState = .idle
            checkGameOver()
            return
        }
        
        // 连击增加动画
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            matchGameCombo += 1
        }
        resetComboTimer()
        
        clearMatches(animated: true) {
            self.fillEmptySpaces(animated: true) {
                // 添加短暂延迟让玩家看清楚新掉落的宝石
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.processMatches()
                }
            }
        }
    }

    private func findMatches() -> Set<Position> {
        var matchPositions = Set<Position>()
        
        // 横向检测
        for row in 0..<matchGameGridSize {
            for col in 0..<(matchGameGridSize - 2) {
                guard let gem = matchGameBoard[row][col] else { continue }
                if let next1 = matchGameBoard[row][col + 1],
                   let next2 = matchGameBoard[row][col + 2],
                   gem.matchGameType == next1.matchGameType && gem.matchGameType == next2.matchGameType {
                    var length = 3
                    for i in 0..<length {
                        matchPositions.insert(Position(row: row, col: col + i))
                    }
                    // 检测更长的连续匹配
                    while col + length < matchGameGridSize,
                          let nextGem = matchGameBoard[row][col + length],
                          nextGem.matchGameType == gem.matchGameType {
                        matchPositions.insert(Position(row: row, col: col + length))
                        length += 1
                    }
                }
            }
        }
        
        // 纵向检测
        for col in 0..<matchGameGridSize {
            for row in 0..<(matchGameGridSize - 2) {
                guard let gem = matchGameBoard[row][col] else { continue }
                if let next1 = matchGameBoard[row + 1][col],
                   let next2 = matchGameBoard[row + 2][col],
                   gem.matchGameType == next1.matchGameType && gem.matchGameType == next2.matchGameType {
                    var length = 3
                    for i in 0..<length {
                        matchPositions.insert(Position(row: row + i, col: col))
                    }
                    // 检测更长的连续匹配
                    while row + length < matchGameGridSize,
                          let nextGem = matchGameBoard[row + length][col],
                          nextGem.matchGameType == gem.matchGameType {
                        matchPositions.insert(Position(row: row + length, col: col))
                        length += 1
                    }
                }
            }
        }
        
        return matchPositions
    }
    
    private func clearMatches(animated: Bool, completion: (() -> Void)? = nil) {
        let matchPositions = findMatches()
        guard !matchPositions.isEmpty else {
            completion?()
            return
        }
        
        if animated {
            let baseScore = 10 + (matchPositions.count - 3) * 5
            let comboMultiplier = max(1, matchGameCombo)
            let earnedScore = baseScore * comboMultiplier
            
            // 平滑的分数增加动画
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                matchGameScore += earnedScore
            }
            
            matchGameMatchingPositions = matchPositions
            
            // 更有冲击力的消除动画
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                for position in matchPositions {
                    self.matchGameBoard[position.row][position.col] = nil
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                self.matchGameMatchingPositions = []
                completion?()
            }
        } else {
            for position in matchPositions {
                self.matchGameBoard[position.row][position.col] = nil
            }
            completion?()
        }
    }

    private func fillEmptySpaces(animated: Bool, completion: (() -> Void)? = nil) {
        let duration = 0.4
        if animated {
            // 更自然的掉落动画
            withAnimation(.spring(response: duration, dampingFraction: 0.75)) {
                performFillLogic()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.05) {
                completion?()
            }
        } else {
            performFillLogic()
            completion?()
        }
    }
    
    private func performFillLogic() {
        for col in 0..<matchGameGridSize {
            var emptyRow = matchGameGridSize - 1
            for row in (0..<matchGameGridSize).reversed() {
                if let gem = matchGameBoard[row][col] {
                    if row != emptyRow {
                        matchGameBoard[emptyRow][col] = gem
                        matchGameBoard[row][col] = nil
                    }
                    emptyRow -= 1
                }
            }
            if emptyRow >= 0 {
                for row in 0...emptyRow {
                    matchGameBoard[row][col] = MatchGameGem(matchGameType: Int.random(in: 0..<matchGameGemTypes))
                }
            }
        }
    }
    
    private func resetComboTimer() {
        matchGameComboTimer?.invalidate()
        matchGameComboTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    self?.matchGameCombo = 0
                }
            }
        }
    }
    
    private func checkGameOver() {
        if matchGameMoves <= 0 {
            gameState = .processing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    self.matchGameIsGameOver = true
                }
            }
        }
    }
}
