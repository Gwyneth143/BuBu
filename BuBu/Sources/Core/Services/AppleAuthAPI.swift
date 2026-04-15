import Foundation

/// 后端 Apple 登录接口响应
struct AppleLoginResponse: Codable {
    let message: String
    let accessToken: String
    let tokenType: String
    let expiresIn: String
    let user: AppleUserDTO
}

struct AppleUserDTO: Codable {
    let id: Int
    let provider: String
    let appleUserId: String
    let email: String?
    let emailVerified: Bool?
    let isPrivateEmail: Bool?
    let lastLoginAt: String?
}

enum AppleAuthAPIError: LocalizedError {
    case invalidURL
    case invalidIdentityToken
    case httpStatus(Int, String?)
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的登录地址"
        case .invalidIdentityToken: return "无法获取 Apple identityToken"
        case .httpStatus(let code, let body):
            return code == 500 ? "服务器错误" : "登录失败 (\(code))\(body.map { ": \($0)" } ?? "")"
        case .decodeFailed: return "响应解析失败"
        }
    }
}

/// 调用后端 `POST https://xsmb.world/auth/apple`
///
/// 约定：
/// - **Header**：`Content-Type: application/json`
/// - **Body（JSON）**：必须包含字段 `identityToken`（字符串），即 Sign in with Apple 返回的 **identity token（JWT 字符串）**
enum AppleAuthAPI {
    private static let baseURL = URL(string: "https://xsmb.world/auth/apple")!

    static func login(identityToken: String) async throws -> AppleLoginResponse {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        /// 仅包含 `identityToken`，与后端字段名一致
        struct Body: Encodable { let identityToken: String }
        request.httpBody = try JSONEncoder().encode(Body(identityToken: identityToken))

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AppleAuthAPIError.httpStatus(-1, nil)
        }

        if http.statusCode != 200 {
            let text = String(data: data, encoding: .utf8)
            throw AppleAuthAPIError.httpStatus(http.statusCode, text)
        }

        do {
            return try JSONDecoder().decode(AppleLoginResponse.self, from: data)
        } catch {
            throw AppleAuthAPIError.decodeFailed
        }
    }
}
