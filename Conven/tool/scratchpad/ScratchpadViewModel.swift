import SwiftUI
import Combine

@MainActor
class ScratchpadViewModel: ObservableObject {
    @Published var noteText: String = ""
    @Published var showCloseConfirmation = false
    
    // 用于在关闭时传递闭包
    var closeAction: (() -> Void)?
    
    func confirmClose(window: NSWindow?) {
        if !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            showCloseConfirmation = true
        } else {
            window?.close()
        }
    }
    
    func forceClose(window: NSWindow?) {
        showCloseConfirmation = false
        window?.close()
    }
    
    func openNewScratchpadWindow() {
        // 直接调用 AppTool.swift 中的统一方法来打开新窗口
        ToolsManager.shared.openToolWindow(.scratchpad)
    }
}
