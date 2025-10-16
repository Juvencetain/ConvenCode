import SwiftUI

// MARK: - ChmodCalculator View
struct ChmodCalculatorView: View {
    
    // MARK: - Permission Group
    enum PermissionGroup: String, CaseIterable {
        case owner = "所有者"
        case group = "用户组"
        case other = "其他"
    }
    
    // MARK: - State Properties
    @State private var ownerRead = false
    @State private var ownerWrite = false
    @State private var ownerExecute = false
    
    @State private var groupRead = false
    @State private var groupWrite = false
    @State private var groupExecute = false
    
    @State private var otherRead = false
    @State private var otherWrite = false
    @State private var otherExecute = false

    // MARK: - Body
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerSection
                Divider().padding(.horizontal, 16)
                
                VStack(spacing: 20) {
                    permissionGrid
                    resultDisplay
                    Spacer()
                }
                .padding(20)
            }
        }
        .focusable(false)
        .frame(width: 420, height: 560)
    }
    
    // MARK: - Subviews
    private var headerSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 16))
                .foregroundStyle(.cyan.gradient)
            
            Text("Chmod 计算器")
                .font(.system(size: 14, weight: .medium))
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    private var permissionGrid: some View {
        VStack {
            HStack {
                Text("").frame(maxWidth: .infinity)
                Text("读 (r)").frame(maxWidth: .infinity)
                Text("写 (w)").frame(maxWidth: .infinity)
                Text("执行 (x)").frame(maxWidth: .infinity)
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            ChmodPermissionRow(group: .owner, read: $ownerRead, write: $ownerWrite, execute: $ownerExecute)
            ChmodPermissionRow(group: .group, read: $groupRead, write: $groupWrite, execute: $groupExecute)
            ChmodPermissionRow(group: .other, read: $otherRead, write: $otherWrite, execute: $otherExecute)
        }
    }
    
    private var resultDisplay: some View {
        VStack(spacing: 15) {
            ChmodResultRow(label: "Octal", value: octalResult)
            ChmodResultRow(label: "Symbolic", value: symbolicResult, isMonospaced: true)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }
    
    // MARK: - Computed Properties
    private var octalResult: String {
        let ownerValue = (ownerRead ? 4 : 0) + (ownerWrite ? 2 : 0) + (ownerExecute ? 1 : 0)
        let groupValue = (groupRead ? 4 : 0) + (groupWrite ? 2 : 0) + (groupExecute ? 1 : 0)
        let otherValue = (otherRead ? 4 : 0) + (otherWrite ? 2 : 0) + (otherExecute ? 1 : 0)
        return "\(ownerValue)\(groupValue)\(otherValue)"
    }
    
    private var symbolicResult: String {
        let owner = (ownerRead ? "r" : "-") + (ownerWrite ? "w" : "-") + (ownerExecute ? "x" : "-")
        let group = (groupRead ? "r" : "-") + (groupWrite ? "w" : "-") + (groupExecute ? "x" : "-")
        let other = (otherRead ? "r" : "-") + (otherWrite ? "w" : "-") + (otherExecute ? "x" : "-")
        return "-\(owner)\(group)\(other)"
    }
}

// MARK: - ChmodPermissionRow
struct ChmodPermissionRow: View {
    let group: ChmodCalculatorView.PermissionGroup
    @Binding var read: Bool
    @Binding var write: Bool
    @Binding var execute: Bool
    
    var body: some View {
        HStack {
            Text(group.rawValue)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Toggle("", isOn: $read).toggleStyle(.checkbox).frame(maxWidth: .infinity)
            Toggle("", isOn: $write).toggleStyle(.checkbox).frame(maxWidth: .infinity)
            Toggle("", isOn: $execute).toggleStyle(.checkbox).frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - ChmodResultRow
struct ChmodResultRow: View {
    let label: String
    let value: String
    var isMonospaced: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(isMonospaced ? .system(.body, design: .monospaced) : .body)
                .fontWeight(.bold)
        }
    }
}


#Preview {
    ChmodCalculatorView()
}
