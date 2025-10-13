import Foundation
import LocalAuthentication

class LocalAuthManager {
    static let shared = LocalAuthManager()
    private var context = LAContext()

    init() {
        // 可以为context进行一些通用配置
        context.localizedCancelTitle = "取消"
    }

    /// 检查设备是否支持生物识别
    func canEvaluatePolicy() -> Bool {
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    /// 请求指纹认证
    func authenticate(reason: String, completion: @escaping (Bool, Error?) -> Void) {
        // 每次认证前，重置context以获取最新状态
        context = LAContext()
        
        guard canEvaluatePolicy() else {
            completion(false, nil)
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }
}
