import SwiftUI
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

struct LoginView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage("icloud.uploadEnabled") private var iCloudUploadEnabled = false
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            AppTheme.Colors.appBackground.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer(minLength: 40)

                VStack(spacing: 10) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primaryColor)
                    Text(localized: "login.title")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "111827"))
                    Text(localized: "login.subtitle")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 12) {
                    loginFeatureRow(icon: "lock.shield.fill", textKey: "login.feature.privacy")
                    loginFeatureRow(icon: "icloud.fill", textKey: "login.feature.sync")
                    loginFeatureRow(icon: "sparkles", textKey: "login.feature.workshop")
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.9))
                        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
                )
                .padding(.horizontal, 24)

                VStack(spacing: 10) {
                    #if canImport(AuthenticationServices)
                    SignInWithAppleButton(.signIn, onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    }, onCompletion: handleResult)
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .disabled(isLoading)
                    .opacity(isLoading ? 0.5 : 1)
                    #else
                    Button {
                        Task { await completeLocalLogin() }
                    } label: {
                        Text(localized: "login.fallback_continue")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.black)
                            )
                    }
                    #endif

                    Text(localized: "login.terms_hint")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

//                    Text(localized: "profile.icloud_upload_hint")
//                        .font(.caption2)
//                        .foregroundColor(.secondary)
//                        .multilineTextAlignment(.leading)
//                        .frame(maxWidth: .infinity, alignment: .leading)
//                        .padding(.top, 2)

                    HStack(spacing: 10) {
                        Button(String.localized("login.user_notice")) {
                            if let url = LegalDocumentURLs.userNotice {
                                openURL(url)
                            }
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppTheme.Colors.primaryColor)
                        .buttonStyle(.plain)

                        Text("·")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button(String.localized("login.privacy_policy")) {
                            if let url = LegalDocumentURLs.privacyPolicy {
                                openURL(url)
                            }
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppTheme.Colors.primaryColor)
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)

                if isLoading {
                    ProgressView()
                        .padding(.top, 8)
                }

                Spacer(minLength: 24)
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.85))
                            )
                    }
                    .accessibilityLabel(Text(localized: "login.close"))
                    .buttonStyle(.plain)
                    .padding(.top, 12)
                    .padding(.trailing, 16)
                }
                Spacer()
            }
        }
        .alert(String.localized("login.error_title"), isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button(String.localized("common.ok"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? String.localized("login.error_fallback"))
        }
    }

    private func loginFeatureRow(icon: String, textKey: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(AppTheme.Colors.primaryColor)
            Text(localized: textKey)
                .font(.subheadline)
                .foregroundColor(Color(hex: "1F2937"))
            Spacer()
        }
    }

    #if canImport(AuthenticationServices)
    private func handleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = String.localized("login.error.missing_credential")
                return
            }
            guard let tokenData = credential.identityToken,
                  let tokenString = String(data: tokenData, encoding: .utf8) else {
                errorMessage = String.localized("login.error.missing_identity_token")
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
            if iCloudUploadEnabled {
                try? await env.cloudSyncService.enableSyncIfNeeded()
                try? await env.cloudSyncService.restoreFromCloud(documentStore: env.documentStore)
            }
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

    @MainActor
    private func completeLocalLogin() async {
        env.session.setLoggedIn(userIdentifier: UUID().uuidString)
        if iCloudUploadEnabled {
            try? await env.cloudSyncService.enableSyncIfNeeded()
            try? await env.cloudSyncService.restoreFromCloud(documentStore: env.documentStore)
        }
        dismiss()
    }
}
