import SwiftUI

struct ProfileSettingsView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    var onAccountDeleted: () -> Void

    var body: some View {
        List {
            Section {
                NavigationLink {
                    ProfileAccountSecurityView(onAccountDeleted: onAccountDeleted)
                        .environmentObject(env)
                } label: {
                    HStack {
                        Image(systemName: "lock.shield")
                        Text(localized: "profile.account_security")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String.localized("profile.settings"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                }
            }
        }
    }
}

private struct ProfileAccountSecurityView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    var onAccountDeleted: () -> Void

    @State private var showingDeleteAccountConfirm = false
    @State private var isDeletingAccount = false
    @State private var deleteErrorMessage: String?

    var body: some View {
        ZStack {
            AppTheme.Colors.appBackground
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Button {
                    showingDeleteAccountConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text(localized: "profile.delete_account")
                        Spacer()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color(red: 0.91, green: 0.26, blue: 0.21))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isDeletingAccount)
                .opacity(isDeletingAccount ? 0.6 : 1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if showingDeleteAccountConfirm {
                ConfirmModalView(
                    title: String.localized("profile.delete_account_confirm_title"),
                    message: String.localized("profile.delete_account_confirm_message"),
                    iconName: "trash.fill",
                    cancelTitle: String.localized("common.cancel"),
                    confirmTitle: String.localized("common.delete"),
                    confirmColor: Color(red: 0.91, green: 0.26, blue: 0.21),
                    onCancel: {
                        showingDeleteAccountConfirm = false
                    },
                    onConfirm: {
                        showingDeleteAccountConfirm = false
                        Task { await deleteAccount() }
                    }
                )
            }
        }
        .navigationTitle(String.localized("profile.account_security"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                }
            }
        }
        .alert(String.localized("common.ok"), isPresented: Binding(
            get: { deleteErrorMessage != nil },
            set: { if !$0 { deleteErrorMessage = nil } }
        )) {
            Button(String.localized("common.ok"), role: .cancel) { deleteErrorMessage = nil }
        } message: {
            Text(deleteErrorMessage ?? "")
        }
    }

    private func deleteAccount() async {
        guard !isDeletingAccount else { return }
        await MainActor.run { isDeletingAccount = true }
        defer {
            Task { @MainActor in
                isDeletingAccount = false
            }
        }

        do {
            try await requestDeleteAccount(token: env.session.accessToken)
            try await env.cloudSyncService.clearCloudData()
            try await clearLocalUserData()
            await MainActor.run {
                env.session.signOut()
                onAccountDeleted()
                dismiss()
            }
        } catch {
            await MainActor.run {
                deleteErrorMessage = error.localizedDescription
            }
        }
    }

    private func clearLocalUserData() async throws {
        let notebooks = try await env.documentStore.fetchAllNotebooks()
        for notebook in notebooks {
            if let serverBookId = notebook.serverBookId {
                try? await env.documentStore.deleteNotebook(serverBookId)
            } else {
                var cleared = notebook
                cleared.pages = []
                cleared.tags = []
                cleared.updatedAt = Date()
                try? await env.documentStore.saveNotebook(cleared)
            }
        }

        let fm = FileManager.default
        if let docs = try? fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
            let scansDir = docs.appendingPathComponent("scans", isDirectory: true)
            let coversDir = docs.appendingPathComponent("covers", isDirectory: true)
            if fm.fileExists(atPath: scansDir.path) {
                try? fm.removeItem(at: scansDir)
            }
            if fm.fileExists(atPath: coversDir.path) {
                try? fm.removeItem(at: coversDir)
            }
        }

        if let appSupport = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
            let localStoreDir = appSupport.appendingPathComponent("BuBu", isDirectory: true)
            if fm.fileExists(atPath: localStoreDir.path) {
                try? fm.removeItem(at: localStoreDir)
            }
        }
    }

    private func requestDeleteAccount(token: String?) async throws {
        guard let token = token?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }
        guard let url = URL(string: "https://xsmb.world/users/delete") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(
                domain: "ProfileAccountSecurity",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: body.isEmpty ? "Delete account failed (\(http.statusCode))" : body]
            )
        }
    }
}
