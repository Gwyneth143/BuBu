import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.openURL) private var openURL
    @Environment(\.presentLogin) private var presentLogin
    @AppStorage("privacy.biometricLockEnabled") private var biometricLockEnabled = false
    @AppStorage("privacy.passcodeLockEnabled") private var passcodeLockEnabled = false
    @AppStorage("privacy.passcodeValue") private var passcodeValue = ""
    @AppStorage("icloud.uploadEnabled") private var iCloudUploadEnabled = false
    @State private var storageInfo: CloudStorageInfo?
    @State private var syncStatusText: String = String.localized("profile.sync.not_synced")
    @State private var isSyncing: Bool = false
    @State private var showingPasscodeSheet = false
    @State private var showingLogoutConfirm = false
    @State private var showingLogoutSyncPrompt = false
    @State private var showingDeleteCloudDataConfirm = false
    @State private var passcodeFlow: ProfilePasscodeFlow = .set
    @State private var passcodeInput = ""
    @State private var passcodeConfirmInput = ""
    @State private var passcodeErrorText = ""
    @State private var isUpdatingBiometricToggle = false

    var body: some View {
        ZStack {
            AppTheme.Colors.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    if env.session.isLoggedIn {
                        if iCloudUploadEnabled {
                            iCloudCard
                        }
                        iCloudUploadToggleRow
                        privacySection
                        legalSection
                        logoutSection
                    } else {
                        notLoggedInSection
                    }
                    
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
        .task {
            if env.session.isLoggedIn {
                await loadICloudInfo()
            }
        }
        .fullScreenCover(isPresented: $showingPasscodeSheet) {
            ProfilePasscodeSheet(
                flow: passcodeFlow,
                passcodeInput: $passcodeInput,
                passcodeConfirmInput: $passcodeConfirmInput,
                errorText: $passcodeErrorText,
                onSubmit: { submitPasscodeFlow() },
                onCancel: { cancelPasscodeFlow() }
            )
        }
        .overlay {
            if showingLogoutConfirm {
                ConfirmModalView(
                    title: String.localized("profile.logout_confirm_title"),
                    message: String.localized("profile.logout_confirm_message"),
                    iconName: "rectangle.portrait.and.arrow.right",
                    cancelTitle: String.localized("common.cancel"),
                    confirmTitle: String.localized("profile.logout_confirm_action"),
                    confirmColor: Color(red: 0.91, green: 0.26, blue: 0.21),
                    onCancel: {
                        showingLogoutConfirm = false
                    },
                    onConfirm: {
                        showingLogoutConfirm = false
                        env.session.signOut()
                    }
                )
            }

            if showingLogoutSyncPrompt {
                ConfirmModalView(
                    title: String.localized("profile.logout_sync_prompt_title"),
                    message: String.localized("profile.logout_sync_prompt_message"),
                    iconName: "icloud.and.arrow.up",
                    cancelTitle: String.localized("profile.logout_immediate_action"),
                    confirmTitle: String.localized("profile.logout_sync_action"),
                    confirmColor: AppTheme.Colors.primaryColor,
                    onCancel: {
                        showingLogoutSyncPrompt = false
                        env.session.signOut()
                    },
                    onConfirm: {
                        showingLogoutSyncPrompt = false
                        Task { await syncThenLogout() }
                    }
                )
            }

            if showingDeleteCloudDataConfirm {
                ConfirmModalView(
                    title: String.localized("profile.cloud_delete_title"),
                    message: String.localized("profile.cloud_delete_message"),
                    iconName: "trash.fill",
                    cancelTitle: String.localized("common.cancel"),
                    confirmTitle: String.localized("common.delete"),
                    confirmColor: Color(red: 0.91, green: 0.26, blue: 0.21),
                    onCancel: {
                        showingDeleteCloudDataConfirm = false
                    },
                    onConfirm: {
                        showingDeleteCloudDataConfirm = false
                        Task { await triggerDeleteCloudData() }
                    }
                )
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text(localized: "profile.title")
                .font(AppTheme.Fonts.navTitle)
                .kerning(0.8)

            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(AppTheme.Colors.primaryColor)
                    .frame(width: 96, height: 96)
                    .overlay(
                        Text(profileAvatarText)
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(hex: "111827"))
                    )

            }

            VStack(spacing: 4) {
                Text(profileDisplayName)
                    .font(.system(size: 20, weight: .semibold))
                if !env.session.isLoggedIn {
                    Text(localized: "profile.not_logged_in")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var profileDisplayName: String {
        if !env.session.isLoggedIn {
            return String.localized("login.title")
        }
        if let masked = maskedDisplayName() {
            return masked
        }
        return String.localized("profile.default_user_name")
    }

    /// 对邮箱 / AppleID 做脱敏，避免完整暴露用户标识
    private func maskedDisplayName() -> String? {
        let rawDisplayName = env.session.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !rawDisplayName.isEmpty {
            return maskSensitiveIdentifier(rawDisplayName)
        }
        let rawUserIdentifier = env.session.userIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !rawUserIdentifier.isEmpty {
            return maskSensitiveIdentifier(rawUserIdentifier)
        }
        return nil
    }

    private func maskSensitiveIdentifier(_ value: String) -> String {
        if let atIndex = value.firstIndex(of: "@") {
            let local = String(value[..<atIndex])
            let domain = String(value[atIndex...])
            return maskMiddle(of: local) + domain
        }
        return maskMiddle(of: value)
    }

    private func maskMiddle(of text: String) -> String {
        let chars = Array(text)
        guard chars.count > 2 else { return String(chars.prefix(1)) + "*" }
        let prefix = String(chars.prefix(2))
        let suffix = String(chars.suffix(2))
        return prefix + String(repeating: "*", count: min(max(chars.count - 4, 2), 8)) + suffix
    }

    private var profileAvatarText: String {
        let name = profileDisplayName
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "U" }
        // 取前 1-2 个字符做头像占位
        let chars = Array(trimmed)
        return String(chars.prefix(min(2, chars.count))).uppercased()
    }

    // MARK: - VIP

    private var vipCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "crown.fill")
                    .foregroundColor(AppTheme.Colors.primaryColor)
                    .padding(10)
                    .background(
                        Circle()
                            .fill(Color.white)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Join VIP")
                        .font(.subheadline.weight(.semibold))
                    Text("Unlock all skins & custom themes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Button {
                // TODO: 跳转到会员购买页面 / StoreKit
            } label: {
                Text("Join Now")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color(hex: "FF5BA8"))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
    }

    // MARK: - iCloud

    private var iCloudUploadToggleRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(String.localized("login.icloud_upload_toggle"), systemImage: "icloud.and.arrow.up.fill")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Toggle("", isOn: $iCloudUploadEnabled)
                    .labelsHidden()
            }

            Text(localized: "profile.icloud_upload_hint")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
    }

    private var iCloudCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "icloud")
                    .foregroundColor(AppTheme.Colors.primaryColor)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(Color.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(localized: "profile.icloud_sync")
                        .font(.subheadline.weight(.semibold))
                    Text(localized: "profile.storage")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: isSyncing ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.clockwise")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text(storageText)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(syncStatusText)
                    .font(.caption2)
                    .foregroundColor(AppTheme.Colors.primaryColor)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 6)

                    Capsule()
                        .fill(AppTheme.Colors.primaryColor)
                        .frame(width: proxy.size.width * usageProgress, height: 6)
                }
            }
            .frame(height: 6)

            HStack(spacing: 10) {
                Button {
                    Task { await triggerRestoreNow() }
                } label: {
                    Text(localized: "profile.sync.pull_action")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppTheme.Colors.primaryColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(AppTheme.Colors.primaryColor.opacity(0.35), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isSyncing)
                .opacity(isSyncing ? 0.6 : 1)

                Button {
                    Task { await triggerUploadNow() }
                } label: {
                    Text(localized: "profile.sync.upload_action")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(AppTheme.Colors.primaryColor)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isSyncing || !iCloudUploadEnabled)
                .opacity((isSyncing || !iCloudUploadEnabled) ? 0.6 : 1)
            }

            Button {
                showingDeleteCloudDataConfirm = true
            } label: {
                Text(localized: "profile.sync.delete_cloud_action")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Color(red: 0.91, green: 0.26, blue: 0.21))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(red: 1.0, green: 0.95, blue: 0.95))
                    )
            }
            .buttonStyle(.plain)
            .disabled(isSyncing)
            .opacity(isSyncing ? 0.6 : 1)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
    }

    private var storageText: String {
        guard let info = storageInfo else { return "-- / --" }
        return "\(formatByte(info.usedBytes)) / \(formatByte(info.totalBytes))"
    }

    private var usageProgress: CGFloat {
        guard let info = storageInfo, info.totalBytes > 0 else { return 0 }
        let ratio = Double(info.usedBytes) / Double(info.totalBytes)
        return CGFloat(min(max(ratio, 0), 1))
    }

    private func loadICloudInfo() async {
        let info = await env.cloudSyncService.fetchStorageInfo()
        await MainActor.run {
            self.storageInfo = info
            if let date = info.lastSyncDate {
                syncStatusText = String(
                    format: String.localized("profile.sync.last_synced_at"),
                    date.formatted(date: .omitted, time: .shortened)
                )
            } else {
                syncStatusText = info.isICloudAvailable
                    ? String.localized("profile.sync.not_synced")
                    : String.localized("profile.sync.icloud_not_signed_in")
            }
        }
    }

    private func triggerUploadNow() async {
        guard !isSyncing else { return }
        guard iCloudUploadEnabled else {
            await MainActor.run {
                syncStatusText = String.localized("profile.sync.disabled")
            }
            return
        }
        await MainActor.run { isSyncing = true }
        do {
            try await env.cloudSyncService.enableSyncIfNeeded()
            // 覆盖模式：每次上传前先清空云端旧备份，再以上传结果为准。
            try? await env.cloudSyncService.clearCloudData()
            try await env.cloudSyncService.syncNow(documentStore: env.documentStore)
            await MainActor.run {
                syncStatusText = String.localized("profile.sync.synced")
            }
            await loadICloudInfo()
        } catch {
            await MainActor.run {
                syncStatusText = "\(String.localized("profile.sync.failed")): \(error.localizedDescription)"
            }
        }
        await MainActor.run { isSyncing = false }
    }

    private func triggerRestoreNow() async {
        guard !isSyncing else { return }
        await MainActor.run { isSyncing = true }
        do {
            try await env.cloudSyncService.enableSyncIfNeeded()
            try await env.cloudSyncService.restoreFromCloud(documentStore: env.documentStore)
            await MainActor.run {
                syncStatusText = String.localized("profile.sync.synced")
            }
            await loadICloudInfo()
        } catch {
            await MainActor.run {
                syncStatusText = "\(String.localized("profile.sync.failed")): \(error.localizedDescription)"
            }
        }
        await MainActor.run { isSyncing = false }
    }

    private func triggerDeleteCloudData() async {
        guard !isSyncing else { return }
        await MainActor.run { isSyncing = true }
        do {
            try await env.cloudSyncService.enableSyncIfNeeded()
            try await env.cloudSyncService.clearCloudData()
            await MainActor.run {
                syncStatusText = String.localized("profile.sync.not_synced")
            }
            await loadICloudInfo()
        } catch {
            await MainActor.run {
                syncStatusText = "\(String.localized("profile.sync.failed")): \(error.localizedDescription)"
            }
        }
        await MainActor.run { isSyncing = false }
    }

    private func syncThenLogout() async {
        guard !isSyncing else { return }
        await MainActor.run { isSyncing = true }
        do {
            try await env.cloudSyncService.enableSyncIfNeeded()
            // 与手动上传保持一致：退出前同步采用覆盖模式。
            try? await env.cloudSyncService.clearCloudData()
            try await env.cloudSyncService.syncNow(documentStore: env.documentStore)
            try? await env.cloudSyncService.restoreFromCloud(documentStore: env.documentStore)
            await MainActor.run {
                syncStatusText = String.localized("profile.sync.synced")
                env.session.signOut()
            }
        } catch {
            await MainActor.run {
                syncStatusText = "\(String.localized("profile.sync.failed")): \(error.localizedDescription)"
            }
        }
        await MainActor.run { isSyncing = false }
    }

    private func formatByte(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "0 B" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    // MARK: - Legal

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized: "profile.legal_section")
                .font(.caption2)
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                Button {
                    openLegalURL(LegalDocumentURLs.userNotice)
                } label: {
                    HStack {
                        Image(systemName: "doc.text")
                        Text(localized: "profile.legal.user_notice")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.leading, 16)

                Button {
                    openLegalURL(LegalDocumentURLs.privacyPolicy)
                } label: {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                        Text(localized: "profile.legal.privacy_policy")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.leading, 16)

//                Button {
//                    openLegalURL(LegalDocumentURLs.feedback)
//                } label: {
//                    HStack {
//                        Image(systemName: "questionmark.bubble")
//                        Text(localized: "profile.legal.feedback")
//                        Spacer()
//                        Image(systemName: "chevron.right")
//                            .font(.caption)
//                            .foregroundColor(.secondary)
//                    }
//                    .font(.subheadline)
//                    .foregroundColor(.primary)
//                    .padding(.horizontal, 16)
//                    .padding(.vertical, 12)
//                    .contentShape(Rectangle())
//                }
//                .buttonStyle(.plain)
            }
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
            )
        }
    }

    private func openLegalURL(_ url: URL?) {
        guard let url else { return }
        openURL(url)
    }

    // MARK: - Privacy

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized: "profile.privacy_security")
                .font(.caption2)
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 10) {
                        Image(systemName: "faceid")
                        Text(localized: "profile.biometric_lock")
                    }
                    .font(.subheadline)

                    Spacer()

                    Toggle("", isOn: $biometricLockEnabled)
                        .labelsHidden()
                        .onChange(of: biometricLockEnabled) { newValue in
                            handleBiometricToggleChanged(newValue)
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()

                HStack {
                    Image(systemName: "lock")
                    Text(localized: "profile.passcode")
                    Spacer()
                    Toggle("", isOn: $passcodeLockEnabled)
                        .labelsHidden()
                        .onChange(of: passcodeLockEnabled) { newValue in
                            handlePasscodeToggleChanged(newValue)
                        }
                }
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
            )
        }
    }

    private func handlePasscodeToggleChanged(_ newValue: Bool) {
        passcodeErrorText = ""
        passcodeInput = ""
        passcodeConfirmInput = ""

        if newValue {
            // 开启密码锁：若未设置密码，先弹窗设置；否则直接启用。
            if passcodeValue.isEmpty {
                passcodeFlow = .set
                showingPasscodeSheet = true
            }
        } else {
            // 关闭密码锁：要求输入现有密码验证。
            if !passcodeValue.isEmpty {
                passcodeFlow = .disable
                showingPasscodeSheet = true
            } else {
                passcodeLockEnabled = false
            }
        }
    }

    private func handleBiometricToggleChanged(_ newValue: Bool) {
        if isUpdatingBiometricToggle { return }
        Task {
            guard env.authService.isBiometricAvailable else {
                await MainActor.run {
                    isUpdatingBiometricToggle = true
                    biometricLockEnabled = false
                    isUpdatingBiometricToggle = false
                }
                return
            }

            let reason = newValue
                ? String.localized("profile.biometric_enable_reason")
                : String.localized("profile.biometric_disable_reason")
            let success = await env.authService.authenticate(reason: reason)
            await MainActor.run {
                if !success {
                    isUpdatingBiometricToggle = true
                    biometricLockEnabled = !newValue
                    isUpdatingBiometricToggle = false
                }
            }
        }
    }

    private func submitPasscodeFlow() {
        passcodeErrorText = ""
        switch passcodeFlow {
        case .set:
            guard passcodeInput.count == 4, passcodeConfirmInput.count == 4 else {
                passcodeErrorText = String.localized("profile.passcode.error_required_4_digits")
                return
            }
            guard passcodeInput == passcodeConfirmInput else {
                passcodeErrorText = String.localized("profile.passcode.error_not_match")
                return
            }
            passcodeValue = passcodeInput
            passcodeLockEnabled = true
            showingPasscodeSheet = false

        case .disable:
            guard passcodeInput == passcodeValue else {
                passcodeErrorText = String.localized("profile.passcode.error_wrong")
                return
            }
            passcodeLockEnabled = false
            showingPasscodeSheet = false
        }
    }

    private func cancelPasscodeFlow() {
        if passcodeFlow == .set && passcodeValue.isEmpty {
            passcodeLockEnabled = false
        } else if passcodeFlow == .disable {
            passcodeLockEnabled = true
        }
        showingPasscodeSheet = false
    }

    private var notLoggedInSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized: "profile.login_prompt")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button {
                presentLogin()
            } label: {
                HStack {
                    Spacer()
                    Text(localized: "login.fallback_continue")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppTheme.Colors.primaryColor)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        )
    }

    private var logoutSection: some View {
        Button {
            if iCloudUploadEnabled {
                showingLogoutSyncPrompt = true
            } else {
                showingLogoutConfirm = true
            }
        } label: {
            HStack(alignment: .center,spacing: 10) {
                Spacer()
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text(localized: "profile.logout")
                Spacer()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(AppTheme.Colors.primaryColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
    }

}

