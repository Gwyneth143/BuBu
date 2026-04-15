import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.openURL) private var openURL
    @AppStorage("privacy.biometricLockEnabled") private var biometricLockEnabled = false
    @AppStorage("privacy.passcodeLockEnabled") private var passcodeLockEnabled = false
    @AppStorage("privacy.passcodeValue") private var passcodeValue = ""
    @State private var storageInfo: CloudStorageInfo?
    @State private var syncStatusText: String = "未同步"
    @State private var isSyncing: Bool = false
    @State private var showingPasscodeSheet = false
    @State private var showingLogoutConfirm = false
    @State private var passcodeFlow: PasscodeFlow = .set
    @State private var passcodeInput = ""
    @State private var passcodeConfirmInput = ""
    @State private var passcodeErrorText = ""
    @State private var isUpdatingBiometricToggle = false

    private enum PasscodeFlow {
        case set
        case disable
    }

    var body: some View {
        ZStack {
            AppTheme.Colors.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
//                    vipCard
                    iCloudCard
                    privacySection
                    legalSection
                    logoutSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
        .task {
            await loadICloudInfo()
        }
        .sheet(isPresented: $showingPasscodeSheet) {
            passcodeSheet
        }
        .overlay {
            if showingLogoutConfirm {
                ConfirmModalView(
                    title: "退出当前账号？",
                    message: "退出后你可以重新登录，当前本地数据不会被删除。",
                    iconName: "rectangle.portrait.and.arrow.right",
                    cancelTitle: "取消",
                    confirmTitle: "退出",
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
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("Profile & Archive")
                .font(AppTheme.Fonts.sectionTitle)
                .kerning(0.8)

            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(Color(hex: "FDE68A"))
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

                Text("Journaling since January 2023")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var profileDisplayName: String {
        env.session.displayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        ? (env.session.displayName ?? "用户")
        : "用户"
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
                    .foregroundColor(AppTheme.Colors.tabHighlight)
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

    private var iCloudCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "icloud")
                    .foregroundColor(AppTheme.Colors.tabHighlight)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(Color.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("iCloud Sync")
                        .font(.subheadline.weight(.semibold))
                    Text("STORAGE")
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
                    .foregroundColor(AppTheme.Colors.tabHighlight)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 6)

                    Capsule()
                        .fill(AppTheme.Colors.tabHighlight)
                        .frame(width: proxy.size.width * usageProgress, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
        .onTapGesture {
            Task { await triggerSyncNow() }
        }
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
                syncStatusText = "上次同步 \(date.formatted(date: .omitted, time: .shortened))"
            } else {
                syncStatusText = info.isICloudAvailable ? "未同步" : "iCloud 未登录"
            }
        }
    }

    private func triggerSyncNow() async {
        guard !isSyncing else { return }
        await MainActor.run { isSyncing = true }
        do {
            try await env.cloudSyncService.enableSyncIfNeeded()
            try await env.cloudSyncService.syncNow(documentStore: env.documentStore)
            await MainActor.run {
                syncStatusText = "已同步"
            }
            await loadICloudInfo()
        } catch {
            await MainActor.run {
                syncStatusText = "同步失败"
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
            Text("条款与协议")
                .font(.caption2)
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                Button {
                    openLegalURL(LegalDocumentURLs.userNotice)
                } label: {
                    HStack {
                        Image(systemName: "doc.text")
                        Text("用户须知")
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
                        Text("隐私协议")
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
            Text("隐私与安全")
                .font(.caption2)
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 10) {
                        Image(systemName: "faceid")
                        Text("面容锁")
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
                    Text("密码锁")
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

            let reason = newValue ? "开启面容锁以保护隐私内容" : "关闭面容锁前请先验证身份"
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

    private var passcodeSheet: some View {
        CompatibleNavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                if passcodeFlow == .set {
                    Text("设置 4 位密码")
                        .font(.headline)
                    SecureField("输入 4 位数字密码", text: $passcodeInput)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .onChange(of: passcodeInput) { _ in limitPasscodeDigits() }
                    SecureField("再次输入密码", text: $passcodeConfirmInput)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .onChange(of: passcodeConfirmInput) { _ in limitPasscodeDigits() }
                } else {
                    Text("输入密码以关闭密码锁")
                        .font(.headline)
                    SecureField("输入当前密码", text: $passcodeInput)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .onChange(of: passcodeInput) { _ in limitPasscodeDigits() }
                }

                if !passcodeErrorText.isEmpty {
                    Text(passcodeErrorText)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Spacer()

                Button {
                    submitPasscodeFlow()
                } label: {
                    Text(passcodeFlow == .set ? "保存密码" : "确认关闭")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule().fill(Color(hex: "FF5BA8"))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .navigationTitle("密码锁")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        cancelPasscodeFlow()
                    }
                }
            }
        }
    }

    private func limitPasscodeDigits() {
        passcodeInput = String(passcodeInput.filter(\.isNumber).prefix(4))
        passcodeConfirmInput = String(passcodeConfirmInput.filter(\.isNumber).prefix(4))
    }

    private func submitPasscodeFlow() {
        passcodeErrorText = ""
        switch passcodeFlow {
        case .set:
            guard passcodeInput.count == 4, passcodeConfirmInput.count == 4 else {
                passcodeErrorText = "请输入 4 位数字密码"
                return
            }
            guard passcodeInput == passcodeConfirmInput else {
                passcodeErrorText = "两次输入的密码不一致"
                return
            }
            passcodeValue = passcodeInput
            passcodeLockEnabled = true
            showingPasscodeSheet = false

        case .disable:
            guard passcodeInput == passcodeValue else {
                passcodeErrorText = "密码错误"
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

    private var logoutSection: some View {
        Button {
            showingLogoutConfirm = true
        } label: {
            HStack(alignment: .center,spacing: 10) {
                Spacer()
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("退出登录")
                Spacer()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(AppTheme.Colors.tabHighlight)
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

