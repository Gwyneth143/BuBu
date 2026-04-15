import Foundation
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif

/// 生物识别 / 本地认证，用于锁定敏感册子（孕期 / 日记等）
protocol AuthService {
    /// 检查当前设备是否支持 Face ID / Touch ID
    var isBiometricAvailable: Bool { get }

    /// 触发一次认证（实际实现可调用 `LAContext`）
    func authenticate(reason: String) async -> Bool
}

/// 基于 LocalAuthentication 的本地生物识别实现
final class LocalAuthService: AuthService {
    var isBiometricAvailable: Bool {
        #if canImport(LocalAuthentication)
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        #else
        return false
        #endif
    }

    func authenticate(reason: String) async -> Bool {
        #if canImport(LocalAuthentication)
        let context = LAContext()
        context.localizedCancelTitle = "取消"
        context.localizedFallbackTitle = "输入设备密码"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            if let error {
                print("LocalAuth canEvaluatePolicy failed: \(error.domain) code=\(error.code) desc=\(error.localizedDescription)")
            }
            return false
        }

        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, evalError in
                if let evalError, !success {
                    print("LocalAuth evaluatePolicy failed: \(evalError.localizedDescription)")
                }
                continuation.resume(returning: success)
            }
        }
        #else
        return false
        #endif
    }
}

