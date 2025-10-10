import SwiftUI

struct CatStatusView: View {
    // @ObservedObject 让我们能实时观察 ViewModel 的变化
    @ObservedObject var viewModel: CatViewModel
    
    var body: some View {
        VStack(spacing: 15) {
            if viewModel.isAlive {
                Text("小猫状态")
                    .font(.headline)
                
                // 使用 VStack 和 Label 来对齐显示状态
                VStack(alignment: .leading, spacing: 10) {
                    StatusRow(icon: "heart.fill", label: "心情", value: viewModel.mood, color: .pink)
                    StatusRow(icon: "leaf.fill", label: "饥饿", value: viewModel.hunger, color: .green)
                    StatusRow(icon: "drop.fill", label: "清洁", value: viewModel.cleanliness, color: .blue)
                }
                
                // 操作按钮
                HStack(spacing: 10) {
                    Button("陪它玩", systemImage: "gamecontroller.fill", action: viewModel.play)
                    Button("喂食物", systemImage: "fork.knife", action: viewModel.feed)
                    Button("洗澡澡", systemImage: "bathtub.fill", action: viewModel.clean)
                }
                .buttonStyle(.borderedProminent)

            } else {
                VStack(spacing: 20) {
                    Image(systemName: "heart.slash.fill")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("小猫去天堂了...")
                        .font(.title2)
                    Button("重新开始", action: viewModel.restart)
                        .buttonStyle(.borderedProminent)
                }
            }
            
            Divider()
            
            // 退出按钮
            Button("退出应用") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            
        }
        .padding(20)
        .frame(width: 280) // 给弹窗一个固定的宽度
    }
}

// 这是一个辅助视图，用于美化状态显示行
struct StatusRow: View {
    let icon: String
    let label: String
    let value: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text("\(label): \(Int(value))")
            }
            // 进度条
            ProgressView(value: value, total: 100)
                .progressViewStyle(LinearProgressViewStyle(tint: color))
        }
    }
}