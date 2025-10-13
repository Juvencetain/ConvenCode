import SwiftUI

// MARK: - History Item Struct
/// 定义一条历史记录的数据结构
struct CalculationHistoryItem: Identifiable, Hashable {
    let id = UUID()
    let expression: String
    let result: String
}

// MARK: - Calculator View
struct CalculatorView: View {
    
    // MARK: - Properties
    @State private var displayValue = "0"
    @State private var currentOperation: Operation?
    @State private var firstOperand: Double?
    @State private var isTypingNewNumber = true
    
    // [新增] 用于显示完整计算式的状态
    @State private var fullExpression = ""
    
    // [新增] 用于存储计算历史
    @State private var history: [CalculationHistoryItem] = []
    
    // [新增] 控制历史记录区域的显示
    @State private var showHistory = false

    private let buttons: [[CalculatorButton]] = [
        [.clear, .negate, .percent, .divide],
        [.seven, .eight, .nine, .multiply],
        [.four, .five, .six, .subtract],
        [.one, .two, .three, .add],
        [.zero, .decimal, .equals]
    ]

    // MARK: - Body
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
             
            VStack(spacing: 0) {
                headerSection
                Divider().padding(.horizontal, 16)
                
                VStack(spacing: 12) {
                    displaySection // [重构] 提取为独立的显示区域
                    
                    buttonsGrid // [重构] 提取为独立的按钮网格
                    
                    historyToggle // [新增] 历史记录开关
                }
                .padding(.bottom)
                .padding(.horizontal, 16)
            }
        }
        // [新增] 底部滑出的历史记录视图
        .sheet(isPresented: $showHistory) {
            HistoryView(history: $history, onSelect: { item in
                displayValue = item.result
                isTypingNewNumber = true
                firstOperand = nil
                currentOperation = nil
                fullExpression = ""
                showHistory = false
            })
        }.focusable(false)
    }
    
    // MARK: - Subviews
    private var headerSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "function")
                .font(.system(size: 16))
                .foregroundStyle(.purple.gradient)
            
            Text("计算器")
                .font(.system(size: 14, weight: .medium))
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    /// [新增] 显示区域
    private var displaySection: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Spacer()
            // [新增] 完整表达式显示
            Text(fullExpression)
                .font(.system(size: 24, weight: .light))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            // 主数字显示
            Text(displayValue)
                .font(.system(size: 72, weight: .light))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
        }
        .padding(.horizontal)
        .frame(height: 120)
    }

    /// [新增] 按钮网格
    private var buttonsGrid: some View {
        ForEach(buttons, id: \.self) { row in
            HStack(spacing: 12) {
                ForEach(row, id: \.self) { button in
                    Button(action: {
                        handleTap(button: button)
                    }) {
                        let buttonText = (button == .clear) ? (isTypingNewNumber ? "AC" : "C") : button.title
                        
                        Text(buttonText)
                            .font(.system(size: 32))
                            .frame(width: buttonWidth(for: button), height: 72)
                            .background(button.backgroundColor)
                            .foregroundColor(button.foregroundColor)
                            .cornerRadius(36)
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                }
            }
        }
    }

    /// [新增] 历史记录开关
    private var historyToggle: some View {
        Button(action: { showHistory.toggle() }) {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 12))
                Text("历史记录")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(.secondary)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
    }
    
    // MARK: - Logic
    
    private func handleTap(button: CalculatorButton) {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
            if button.isDigit {
                handleDigitInput(button)
            } else if button == .decimal {
                handleDecimalInput()
            } else if button.isOperation {
                handleOperationInput(button)
            } else if button == .equals {
                handleEquals()
            } else if button.isUtility {
                handleUtilityInput(button)
            }
        }
    }
    
    private func handleDigitInput(_ button: CalculatorButton) {
        if isTypingNewNumber || displayValue == "0" {
            displayValue = button.title
            isTypingNewNumber = false
        } else {
            guard displayValue.count < 15 else { return }
            displayValue += button.title
        }
    }
    
    private func handleDecimalInput() {
        if isTypingNewNumber {
            displayValue = "0."
            isTypingNewNumber = false
        } else if !displayValue.contains(".") {
            displayValue += "."
        }
    }
    
    private func handleOperationInput(_ button: CalculatorButton) {
        // [修改] 更新表达式
        let formattedOperand = formatResult(Double(displayValue) ?? 0)
        
        if firstOperand != nil {
            handleEquals() // 连续计算
        }
        
        firstOperand = Double(displayValue)
        currentOperation = button.operation
        fullExpression = "\(formattedOperand) \(button.title)"
        isTypingNewNumber = true
    }
    
    private func handleEquals() {
        guard let operand1 = firstOperand, let operation = currentOperation, let operand2 = Double(displayValue), !isTypingNewNumber else {
            return
        }
        
        let result = calculate(op1: operand1, op2: operand2, operation: operation)
        let formattedResult = formatResult(result)
        
        // [新增] 添加到历史记录
        let expressionForHistory = "\(formatResult(operand1)) \(operation.displayTitle) \(formatResult(operand2))"
        addHistory(expression: expressionForHistory, result: formattedResult)
        
        displayValue = formattedResult
        fullExpression = "\(expressionForHistory) ="
        
        firstOperand = result // 允许连续计算
        currentOperation = nil
        isTypingNewNumber = true
    }
    
    private func handleUtilityInput(_ button: CalculatorButton) {
        guard displayValue != "Error" else {
            if button == .clear { allClear() }
            return
        }
        
        switch button {
        case .clear:
            if !isTypingNewNumber {
                displayValue = "0"
                isTypingNewNumber = true
            } else {
                allClear()
            }
        case .negate:
            if let currentValue = Double(displayValue) {
                displayValue = formatResult(-currentValue)
            }
        case .percent:
            if let currentValue = Double(displayValue) {
                displayValue = formatResult(currentValue / 100)
                isTypingNewNumber = true
            }
        default:
            break
        }
    }

    private func allClear() {
        displayValue = "0"
        firstOperand = nil
        currentOperation = nil
        isTypingNewNumber = true
        fullExpression = "" // [新增] 同时清空表达式
    }
    
    // [新增] 添加历史记录的方法
    private func addHistory(expression: String, result: String) {
        guard result != "Error" else { return }
        
        let newItem = CalculationHistoryItem(expression: expression, result: result)
        
        // 避免重复添加
        if history.first?.expression == newItem.expression && history.first?.result == newItem.result {
            return
        }
        
        history.insert(newItem, at: 0)
        
        // 保持最多50条
        if history.count > 50 {
            history.removeLast()
        }
    }
    
    private func calculate(op1: Double, op2: Double, operation: Operation) -> Double {
        switch operation {
        case .add: return op1 + op2
        case .subtract: return op1 - op2
        case .multiply: return op1 * op2
        case .divide:
            if op2 == 0 { return .nan }
            return op1 / op2
        }
    }
    
    private func formatResult(_ number: Double) -> String {
        if number.isNaN || number.isInfinite {
            return "Error"
        }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 8
        formatter.minimumFractionDigits = 0
        
        // 对于非常大或非常小的数，使用科学计数法
        if abs(number) > 1e15 || (abs(number) < 1e-8 && number != 0) {
            formatter.numberStyle = .scientific
            formatter.exponentSymbol = "e"
        }
        
        return formatter.string(from: NSNumber(value: number)) ?? String(number)
    }
    
    private func buttonWidth(for button: CalculatorButton) -> CGFloat {
        let spacing: CGFloat = 12
        let totalSpacing: CGFloat = 3 * spacing
        let availableWidth = 420 - 2 * 16 - totalSpacing
        let buttonWidth = availableWidth / 4

        if button == .zero {
            return (buttonWidth * 2) + spacing
        }
        return buttonWidth
    }
}

// MARK: - History View
/// [新增] 用于展示历史记录的独立视图
struct HistoryView: View {
    @Binding var history: [CalculationHistoryItem]
    let onSelect: (CalculationHistoryItem) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 标题栏
                HStack {
                    Text("计算历史")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                
                Divider()
                
                // 历史列表
                if history.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.badge.xmark")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("暂无历史记录")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(history) { item in
                                historyRow(item)
                                Divider().padding(.leading)
                            }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 300, idealWidth: 350, minHeight: 400, idealHeight: 500)
    }
    
    private func historyRow(_ item: CalculationHistoryItem) -> some View {
        Button(action: { onSelect(item) }) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.expression + " =")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.secondary)
                Text(item.result)
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .contentShape(Rectangle()) // 让整个区域可点击
        }
        .buttonStyle(.plain)
    }
}


// MARK: - Calculator Enums
enum Operation {
    case add, subtract, multiply, divide
    
    var displayTitle: String {
        switch self {
        case .add: return "+"
        case .subtract: return "-"
        case .multiply: return "×"
        case .divide: return "÷"
        }
    }
}

enum CalculatorButton: String, Hashable, CaseIterable {
    // ... 内容与之前版本相同 ...
    case zero, one, two, three, four, five, six, seven, eight, nine
    case decimal
    case equals, add, subtract, multiply, divide
    case clear, negate, percent
    
    var title: String {
        switch self {
        case .add: return "+"
        case .subtract: return "-"
        case .multiply: return "×"
        case .divide: return "÷"
        // 其他case ...
        case .zero: return "0"
        case .one: return "1"
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        case .decimal: return "."
        case .equals: return "="
        case .clear: return "AC"
        case .negate: return "+/-"
        case .percent: return "%"
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .add, .subtract, .multiply, .divide, .equals:
            return .orange
        case .clear, .negate, .percent:
            return .white.opacity(0.25)
        default:
            return .white.opacity(0.12)
        }
    }
    
    var foregroundColor: Color { .primary }
    
    var isDigit: Bool {
        switch self {
        case .zero, .one, .two, .three, .four, .five, .six, .seven, .eight, .nine:
            return true
        default: return false
        }
    }
    
    var isOperation: Bool {
        return self == .add || self == .subtract || self == .multiply || self == .divide
    }
    
    var isUtility: Bool {
        return self == .clear || self == .negate || self == .percent
    }
    
    var operation: Operation? {
        switch self {
        case .add: return .add
        case .subtract: return .subtract
        case .multiply: return .multiply
        case .divide: return .divide
        default: return nil
        }
    }
}

// MARK: - Preview
#Preview {
    CalculatorView()
        .frame(width: 420, height: 560)
}
