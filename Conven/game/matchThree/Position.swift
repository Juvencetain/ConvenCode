//
//  MatchGameModels.swift
//  Conven
//
//  Created by 土豆星球 on 2025/10/17.
//  Updated by Gemini on 2025/10/17 with a state-driven game loop for maximum performance.
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
        // [TWEAK] 确保点击位置在棋盘内
        guard position.row >= 0 && position.row < matchGameGridSize && position.col >= 0 && position.col < matchGameGridSize else { return }
        guard gameState == .idle, !matchGameIsGameOver else { return }
        
        if let selected = matchGameSelectedPosition {
            if matchGameIsAdjacent(selected, position) {
                matchGameSwapGems(at: selected, and: position)
                matchGameSelectedPosition = nil
            } else {
                matchGameSelectedPosition = position
            }
        } else {
            matchGameSelectedPosition = position
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
        
        withAnimation(.easeOut(duration: 0.2)) {
            let temp = matchGameBoard[pos1.row][pos1.col]
            matchGameBoard[pos1.row][pos1.col] = matchGameBoard[pos2.row][pos2.col]
            matchGameBoard[pos2.row][pos2.col] = temp
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            let matches = self.findMatches()
            if !matches.isEmpty {
                self.matchGameMoves -= 1
                self.processMatches()
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
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
            gameState = .idle
            checkGameOver()
            return
        }
        
        matchGameCombo += 1
        resetComboTimer()
        
        clearMatches(animated: true) {
            self.fillEmptySpaces(animated: true) {
                self.processMatches()
            }
        }
    }

    private func findMatches() -> Set<Position> {
        var matchPositions = Set<Position>()
        for row in 0..<matchGameGridSize {
            for col in 0..<(matchGameGridSize - 2) {
                guard let gem = matchGameBoard[row][col] else { continue }
                if let next1 = matchGameBoard[row][col + 1],
                   let next2 = matchGameBoard[row][col + 2],
                   gem.matchGameType == next1.matchGameType && gem.matchGameType == next2.matchGameType {
                    (0...2).forEach { matchPositions.insert(Position(row: row, col: col + $0)) }
                }
            }
        }
        for col in 0..<matchGameGridSize {
            for row in 0..<(matchGameGridSize - 2) {
                guard let gem = matchGameBoard[row][col] else { continue }
                if let next1 = matchGameBoard[row + 1][col],
                   let next2 = matchGameBoard[row + 2][col],
                   gem.matchGameType == next1.matchGameType && gem.matchGameType == next2.matchGameType {
                    (0...2).forEach { matchPositions.insert(Position(row: row + $0, col: col)) }
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
            matchGameScore += baseScore * max(1, matchGameCombo)
            
            matchGameMatchingPositions = matchPositions
            // [TWEAK] 使用更有趣的弹簧动画进行消除
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                for position in matchPositions {
                    self.matchGameBoard[position.row][position.col] = nil
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { // 延迟时间要匹配动画
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
        // [TWEAK] Canvas 动画很快，可以缩短延迟
        let duration = 0.35
        if animated {
            withAnimation(.easeOut(duration: duration)) {
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
        matchGameComboTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            // [TWEAK] 连击结束时加一个UI反馈
            DispatchQueue.main.async {
                self?.matchGameCombo = 0
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

