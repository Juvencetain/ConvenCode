import SwiftUI
import AppKit

// MARK: - 光标扩展
extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { inside in
            if inside {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

// MARK: - 常用光标快捷方式
extension View {
    func pointingHandCursor() -> some View {
        self.cursor(NSCursor.pointingHand)
    }
    
    func arrowCursor() -> some View {
        self.cursor(NSCursor.arrow)
    }
    
    func textCursor() -> some View {
        self.cursor(NSCursor.iBeam)
    }
}
