import Foundation

/// 生物识别 / 本地认证，用于锁定敏感册子（孕期 / 日记等）
protocol AuthService {
    /// 检查当前设备是否支持 Face ID / Touch ID
    var isBiometricAvailable: Bool { get }

    /// 触发一次认证（实际实现可调用 `LAContext`）
    func authenticate(reason: String) async -> Bool
}

/// 占位实现：始终返回通过，用于开发和预览
final class LocalAuthService: AuthService {
    var isBiometricAvailable: Bool {
        true
    }

    func authenticate(reason: String) async -> Bool {
        // TODO: 在真实项目中用 LocalAuthentication 框架替换
        true
    }
}

