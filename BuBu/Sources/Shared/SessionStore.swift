import Foundation
import Combine

final class SessionStore: ObservableObject {
    @Published var isLoggedIn: Bool
    @Published var userIdentifier: String?
    @Published var displayName: String?
    @Published var accessToken: String?
    @Published var serverUserId: Int?

    private let isLoggedInKey = "session.isLoggedIn"
    private let userIdKey = "session.userIdentifier"
    private let displayNameKey = "session.displayName"
    private let accessTokenKey = "session.accessToken"
    private let serverUserIdKey = "session.serverUserId"

    init() {
        let defaults = UserDefaults.standard
        self.isLoggedIn = defaults.bool(forKey: isLoggedInKey)
        self.userIdentifier = defaults.string(forKey: userIdKey)
        self.displayName = defaults.string(forKey: displayNameKey)
        self.accessToken = defaults.string(forKey: accessTokenKey)
        if defaults.object(forKey: serverUserIdKey) != nil {
            self.serverUserId = defaults.integer(forKey: serverUserIdKey)
        } else {
            self.serverUserId = nil
        }
    }

    /// 本地/预览用（无网络）
    func setLoggedIn(userIdentifier: String, displayName: String? = nil) {
        self.userIdentifier = userIdentifier
        self.isLoggedIn = true
        if let displayName, !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.displayName = displayName
        }
        persistBasic()
    }

    /// 后端 Apple 登录成功后写入
    func setLoggedInFromServer(response: AppleLoginResponse) {
        let u = response.user
        userIdentifier = u.appleUserId
        serverUserId = u.id
        accessToken = response.accessToken
        isLoggedIn = true

        if let email = u.email, !email.isEmpty {
            displayName = email.components(separatedBy: "@").first ?? email
        } else {
            displayName = displayName ?? String(u.appleUserId.prefix(8))
        }

        let defaults = UserDefaults.standard
        defaults.set(true, forKey: isLoggedInKey)
        defaults.set(u.appleUserId, forKey: userIdKey)
        defaults.set(u.id, forKey: serverUserIdKey)
        if let name = displayName {
            defaults.set(name, forKey: displayNameKey)
        }
        defaults.set(response.accessToken, forKey: accessTokenKey)
    }

    private func persistBasic() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: isLoggedInKey)
        if let id = userIdentifier {
            defaults.set(id, forKey: userIdKey)
        }
        if let name = displayName {
            defaults.set(name, forKey: displayNameKey)
        }
    }

    func signOut() {
        userIdentifier = nil
        displayName = nil
        accessToken = nil
        serverUserId = nil
        isLoggedIn = false
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: isLoggedInKey)
        defaults.removeObject(forKey: userIdKey)
        defaults.removeObject(forKey: displayNameKey)
        defaults.removeObject(forKey: accessTokenKey)
        defaults.removeObject(forKey: serverUserIdKey)
    }
}
