import SwiftUI
import Lottie
import AppKit

struct LottieView: NSViewRepresentable {
    var animationName: String
    var loopMode: LottieLoopMode = .loop

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // 创建动画视图
        let animationView = LottieAnimationView(name: animationName)
        animationView.loopMode = loopMode
        animationView.backgroundBehavior = .pauseAndRestore
        animationView.contentMode = .scaleAspectFit
        animationView.translatesAutoresizingMaskIntoConstraints = false

        // 将动画添加进容器
        container.addSubview(animationView)

        // ✅ 关键约束：强制动画居中 + 按父视图比例缩放
        NSLayoutConstraint.activate([
            animationView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            animationView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            animationView.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 1.0),
            animationView.heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: 1.0)
        ])

        // 播放动画
        animationView.play()

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let animationView = nsView.subviews.first as? LottieAnimationView else { return }
        if animationView.isAnimationPlaying == false {
            animationView.play()
        }
    }
}
