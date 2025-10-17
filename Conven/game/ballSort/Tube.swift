import SwiftUI
import Combine

// MARK: - 数据模型
struct Tube: Identifiable, Equatable {
    let id = UUID()
    var balls: [Color]
    let capacity: Int = 4
    
    var isFull: Bool { balls.count == capacity }
    var isEmpty: Bool { balls.isEmpty }
    var isSorted: Bool {
        guard !isEmpty else { return true }
        guard isFull else { return false }
        return Set(balls).count == 1
    }
}

// MARK: - 移动记录
struct Move {
    let from: Int
    let to: Int
}

// MARK: - ViewModel
@MainActor
class BallSortViewModel: ObservableObject {
    @Published var tubes: [Tube] = []
    @Published var selectedTubeIndex: Int?
    @Published var moveCount = 0
    @Published var isGameWon = false

    private var moveHistory: [Move] = []
    private let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange]
    private let tubeCount = 8

    init() {
        resetGame()
    }

    func selectTube(at index: Int) {
        if let selectedIndex = selectedTubeIndex {
            if selectedIndex != index {
                moveBall(from: selectedIndex, to: index)
            }
            selectedTubeIndex = nil
        } else {
            if !tubes[index].isEmpty {
                selectedTubeIndex = index
            }
        }
    }
    
    func resetGame() {
        withAnimation(.spring()) {
            isGameWon = false
            moveCount = 0
            selectedTubeIndex = nil
            moveHistory.removeAll()
            setupNewGame()
        }
    }
    
    func undoMove() {
        guard let lastMove = moveHistory.popLast() else { return }
        
        withAnimation(.spring()) {
            if var sourceTube = tubes[safe: lastMove.to],
               var destinationTube = tubes[safe: lastMove.from],
               let ballToMove = sourceTube.balls.popLast() {
                
                destinationTube.balls.append(ballToMove)
                tubes[lastMove.to] = sourceTube
                tubes[lastMove.from] = destinationTube
                
                moveCount -= 1
            }
        }
    }

    private func moveBall(from fromIndex: Int, to toIndex: Int) {
        guard var sourceTube = tubes[safe: fromIndex],
              var destinationTube = tubes[safe: toIndex] else { return }

        guard !sourceTube.isEmpty, !destinationTube.isFull else { return }

        if destinationTube.isEmpty || sourceTube.balls.last == destinationTube.balls.last {
             withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                if let ballToMove = sourceTube.balls.popLast() {
                    destinationTube.balls.append(ballToMove)
                    
                    tubes[fromIndex] = sourceTube
                    tubes[toIndex] = destinationTube
                    
                    moveCount += 1
                    moveHistory.append(Move(from: fromIndex, to: toIndex))
                    
                    checkWinCondition()
                }
            }
        }
    }

    private func checkWinCondition() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if self.tubes.allSatisfy({ $0.isSorted }) {
                withAnimation(.spring()) {
                    self.isGameWon = true
                }
            }
        }
    }
    
    private func setupNewGame() {
        var tempTubes = [Tube](repeating: Tube(balls: []), count: tubeCount)
        var allBalls = colors.flatMap { Array(repeating: $0, count: 4) }.shuffled()
        
        // 填充前 n-2 个试管
        for i in 0..<(tubeCount - 2) {
            for _ in 0..<4 {
                if let ball = allBalls.popLast() {
                    tempTubes[i].balls.append(ball)
                }
            }
        }
        
        self.tubes = tempTubes
    }
}

// 安全访问数组的扩展
extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
