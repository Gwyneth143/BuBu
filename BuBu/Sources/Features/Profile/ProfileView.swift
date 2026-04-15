import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var isLocked: Bool = false

    var body: some View {
        NavigationStack {
            List {
                Section("账户与同步") {
                    Button {
                        Task {
                            try? await env.cloudSyncService.enableSyncIfNeeded()
                            try? await env.cloudSyncService.syncNow()
                        }
                    } label: {
                        Label("同步到 iCloud", systemImage: "icloud.and.arrow.up")
                    }
                }

                Section("会员服务") {
                    Button {
                        // TODO: 跳转到会员购买页面 / StoreKit
                    } label: {
                        Label("开通会员", systemImage: "crown")
                    }
                }

                Section("隐私与安全") {
                    Toggle(isOn: $isLocked) {
                        Label("锁定敏感册子（Face ID）", systemImage: "lock.faceid")
                    }
                    .onChange(of: isLocked) { newValue in
                        if newValue {
                            Task {
                                let success = await env.authService.authenticate(reason: "解锁敏感册子")
                                await MainActor.run {
                                    if !success {
                                        isLocked = false
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("我的")
        }
    }
}

