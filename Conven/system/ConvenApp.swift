import SwiftUI

@main
struct ConvenApp: App {
    // 引入 AppDelegate 来管理应用生命周期
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
