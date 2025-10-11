import SwiftUI
import AppKit

// MARK: - 毛玻璃效果视图
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var state: NSVisualEffectView.State = .active
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

// MARK: - 预设样式扩展
extension VisualEffectBlur {
    /// 菜单栏样式（半透明，融合背景）
    static var menuBar: VisualEffectBlur {
        VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
    }
    
    /// 弹出窗口样式（更明显的毛玻璃效果）
    static var popover: VisualEffectBlur {
        VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
    }
    
    /// 侧边栏样式
    static var sidebar: VisualEffectBlur {
        VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow)
    }
    
    /// 标题栏样式
    static var titlebar: VisualEffectBlur {
        VisualEffectBlur(material: .titlebar, blendingMode: .behindWindow)
    }
}

// MARK: - 使用示例
#Preview {
    ZStack {
        // 背景颜色（用于演示效果）
        LinearGradient(
            colors: [.blue, .purple, .pink],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        VStack(spacing: 20) {
            // 菜单栏样式
            Text("菜单栏样式")
                .padding()
                .background(
                    VisualEffectBlur.menuBar
                        .opacity(0.95)
                        .cornerRadius(10)
                )
            
            // 弹出窗口样式
            Text("弹出窗口样式")
                .padding()
                .background(
                    VisualEffectBlur.popover
                        .cornerRadius(10)
                )
            
            // 自定义样式
            Text("自定义样式")
                .padding()
                .background(
                    VisualEffectBlur(
                        material: .underWindowBackground,
                        blendingMode: .withinWindow
                    )
                    .cornerRadius(10)
                )
        }
        .padding()
    }
    .frame(width: 400, height: 400)
}
