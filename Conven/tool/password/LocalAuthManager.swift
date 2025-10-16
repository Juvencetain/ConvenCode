import Foundation
import LocalAuthentication

class LocalAuthManager {
    static let shared = LocalAuthManager()
    private var context = LAContext()

    // MARK: - 新增
    // 记录上次成功认证的时间戳
    private var lastAuthenticationTime: Date?
    // 会话有效期（300秒 = 5分钟）
    private let sessionDuration: TimeInterval = 300

    init() {
        context.localizedCancelTitle = "取消"
    }

    // MARK: - 新增
    /// 检查认证会话是否仍然有效
    func isSessionValid() -> Bool {
        guard let lastAuthTime = lastAuthenticationTime else { return false }
        // 检查当前时间与上次认证时间的间隔是否小于设定的有效期
        return Date().timeIntervalSince(lastAuthTime) < sessionDuration
    }

    func canEvaluatePolicy() -> Bool {
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    func authenticate(reason: String, completion: @escaping (Bool, Error?) -> Void) {
        // 每次认证前都重置 context
        context = LAContext()
        
        guard canEvaluatePolicy() else {
            completion(false, nil)
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            if success {
                // MARK: - 修改
                // 如果认证成功，更新时间戳
                self.lastAuthenticationTime = Date()
            }
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }
}
