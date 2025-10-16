import SwiftUI

struct ScratchpadView: View {
    @StateObject private var viewModel = ScratchpadViewModel()
    // [修改] 使用了更具唯一性的环境键
    @Environment(\.scratchpadWindow) var window

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部工具栏
                headerBar
                    .padding(.bottom, 8)
                
                // 文本编辑区域
                TextEditor(text: $viewModel.noteText)
                    .font(.system(size: 14, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(12)
                
                // 底部状态栏
                statusBar
            }
        }
        .focusable(false)
        .onAppear {
            // 设置窗口代理以捕获关闭事件
            if let window = self.window {
                // [修改] 使用了新的代理类名
                window.delegate = ScratchpadWindowDelegate(viewModel: viewModel, window: window)
            }
        }
        .alert("要放弃便签内容吗？", isPresented: $viewModel.showCloseConfirmation) {
            Button("取消", role: .cancel) { }
            Button("放弃", role: .destructive) {
                viewModel.forceClose(window: window)
            }
        } message: {
            Text("关闭后，当前记录的内容将会丢失。")
        }
    }
    
    private var headerBar: some View {
        HStack {
            Image(systemName: "pencil.and.scribble")
                .font(.system(size: 14))
                .foregroundStyle(.yellow.gradient)
            
            Text("临时便签")
                .font(.system(size: 14, weight: .medium))
            
            Spacer()

            Button(action: {
                viewModel.openNewScratchpadWindow()
            }) {
                Image(systemName: "plus.square")
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help("新建便签窗口")

        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .background(Color.black.opacity(0.1))
        .onHover { inside in
            if inside {
                NSApp.keyWindow?.isMovableByWindowBackground = true
            } else {
                NSApp.keyWindow?.isMovableByWindowBackground = false
            }
        }
    }
    
    private var statusBar: some View {
        HStack {
            Text("字数: \(viewModel.noteText.count)")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: {
                viewModel.noteText = ""
            }) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.1))
    }
}

// MARK: - NSWindowDelegate to intercept close
// [修改] 重命名以避免冲突
class ScratchpadWindowDelegate: NSObject, NSWindowDelegate {
    private var viewModel: ScratchpadViewModel
    private weak var window: NSWindow?

    init(viewModel: ScratchpadViewModel, window: NSWindow) {
        self.viewModel = viewModel
        self.window = window
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        viewModel.confirmClose(window: window)
        return false // 阻止立即关闭，由 alert 决定
    }
}

// MARK: - EnvironmentKey for Window Access
// [修改] 扩展 EnvironmentValues 以便访问 NSWindow，使用更唯一的 Key
extension EnvironmentValues {
    private struct ScratchpadWindowKey: EnvironmentKey {
        static let defaultValue: NSWindow? = nil
    }

    var scratchpadWindow: NSWindow? {
        get { self[ScratchpadWindowKey.self] }
        set { self[ScratchpadWindowKey.self] = newValue }
    }
}

#Preview {
    ScratchpadView()
        .frame(width: 350, height: 400)
}
