import SwiftUI
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

struct LoginView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            AppTheme.Colors.appBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Welcome to BuBu")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "111827"))
                    Text("请使用 Apple ID 登录以继续")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)

                #if canImport(AuthenticationServices)
                SignInWithAppleButton(.signIn, onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                }, onCompletion: handleResult)
                .signInWithAppleButtonStyle(.black)
                .frame(height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 24)
                .disabled(isLoading)
                .opacity(isLoading ? 0.5 : 1)
                #else
                Button {
                    env.session.setLoggedIn(userIdentifier: UUID().uuidString)
                } label: {
                    Text("Continue")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black))
                }
                .padding(.horizontal, 24)
                #endif

                if isLoading {
                    ProgressView()
                        .padding(.top, 8)
                }

                Spacer()
            }
        }
        .alert("登录失败", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "请稍后重试")
        }
    }

    #if canImport(AuthenticationServices)
    private func handleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "未获取到 AppleIDCredential"
                return
            }
            guard let tokenData = credential.identityToken,
                  let tokenString = String(data: tokenData, encoding: .utf8) else {
                errorMessage = "无法获取 identityToken"
                return
            }
            Task { await loginWithServer(identityToken: tokenString) }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loginWithServer(identityToken: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await AppleAuthAPI.login(identityToken: identityToken)
            env.session.setLoggedInFromServer(response: response)
            dismiss()
        } catch {
            if let e = error as? LocalizedError, let d = e.errorDescription {
                errorMessage = d
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
    #endif
}
