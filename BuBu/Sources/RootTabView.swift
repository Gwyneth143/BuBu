import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var env: AppEnvironment
    @AppStorage("icloud.uploadEnabled") private var iCloudUploadEnabled = false
    @State private var selectedTab: Tab = .library
    @State private var isTabBarHidden: Bool = false
    @State private var hasAttemptedCloudRestore = false
    @State private var showLoginSheet = false

    enum Tab: CaseIterable {
        case library
        case capture
        case workshop
        case profile

        var title: String {
            switch self {
            case .library: return String.localized("tab.library")
            case .capture: return String.localized("tab.capture")
            case .workshop: return String.localized("tab.workshop")
            case .profile: return String.localized("tab.profile")
            }
        }

        /// 未选中态图标名称（放在 Assets -> tabbar 下）
        var iconNormal: String {
            switch self {
            case .library: return "tabbar_library_normal"
            case .capture: return "tabbar_capture_normal"
            case .workshop: return "tabbar_workshop_normal"
            case .profile: return "tabbar_profile_normal"
            }
        }

        /// 选中态图标名称（放在 Assets -> tabbar 下）
        var iconSelected: String {
            switch self {
            case .library: return "tabbar_library_selected"
            case .capture: return "tabbar_capture_selected"
            case .workshop: return "tabbar_workshop_selected"
            case .profile: return "tabbar_profile_selected"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // 常驻 Tab：四个子页面同时挂在树上，仅当前页可见且可点击，避免切换时销毁视图与 StateObject
            ZStack {
                BookshelfView(
                    categoryStore: env.categoryStore,
                    bookStore: env.bookStore
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(selectedTab == .library ? 1 : 0)
                .allowsHitTesting(selectedTab == .library)
                .zIndex(selectedTab == .library ? 1 : 0)

                CollectView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(selectedTab == .capture ? 1 : 0)
                    .allowsHitTesting(selectedTab == .capture)
                    .zIndex(selectedTab == .capture ? 1 : 0)

                WorkshopView(coverStore: env.coverStore) {
                    env.session.serverUserId
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(selectedTab == .workshop ? 1 : 0)
                .allowsHitTesting(selectedTab == .workshop)
                .zIndex(selectedTab == .workshop ? 1 : 0)

                ProfileView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(selectedTab == .profile ? 1 : 0)
                    .allowsHitTesting(selectedTab == .profile)
                    .zIndex(selectedTab == .profile ? 1 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .environment(\.tabBarHidden, $isTabBarHidden)
            .environment(\.rootTabSelection, $selectedTab)
            .environment(\.presentLogin) {
                showLoginSheet = true
            }

            // 自定义 TabBar
            VStack(spacing: 0) {
                Divider()
                    .background(AppTheme.Colors.divider)

                HStack {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            VStack(spacing: 4) {
                                Image(
                                    selectedTab == tab
                                    ? tab.iconSelected
                                    : tab.iconNormal
                                )
                                .renderingMode(.original)

                                Text(tab.title)
                                    .font(.caption2)
                                    .foregroundColor(
                                        selectedTab == tab
                                        ? AppTheme.Colors.primaryColor
                                        : .secondary
                                    )
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 16)
                .background(AppTheme.Colors.appBackground.ignoresSafeArea(edges: .bottom))
            }
            .opacity(isTabBarHidden ? 0 : 1)
            .animation(.easeInOut(duration: 0.2), value: isTabBarHidden)
        }
        .fullScreenCover(isPresented: $showLoginSheet) {
            LoginView()
                .environmentObject(env)
        }
        .onChange(of: env.session.isLoggedIn) { loggedIn in
            guard loggedIn else { return }
            attemptCloudRestoreIfNeeded()
        }
        .onChange(of: iCloudUploadEnabled) { enabled in
            guard enabled, env.session.isLoggedIn else { return }
            attemptCloudRestoreIfNeeded()
        }
        /// 书架上的子页（如册子详情）会隐藏 TabBar；切到其他 Tab 时子页可能仍挂在栈上而不触发 onDisappear，需在此统一恢复。
        .onChange(of: selectedTab) { newTab in
            if newTab != .library {
                isTabBarHidden = false
            }
        }
    }

    private func attemptCloudRestoreIfNeeded() {
        guard iCloudUploadEnabled, !hasAttemptedCloudRestore else { return }
        hasAttemptedCloudRestore = true
        Task {
            try? await env.cloudSyncService.enableSyncIfNeeded()
            try? await env.cloudSyncService.restoreFromCloud(documentStore: env.documentStore)
        }
    }
}

private struct TabBarHiddenKey: EnvironmentKey {
    static let defaultValue: Binding<Bool>? = nil
}

extension EnvironmentValues {
    var tabBarHidden: Binding<Bool>? {
        get { self[TabBarHiddenKey.self] }
        set { self[TabBarHiddenKey.self] = newValue }
    }

    var rootTabSelection: Binding<RootTabView.Tab>? {
        get { self[RootTabSelectionKey.self] }
        set { self[RootTabSelectionKey.self] = newValue }
    }

    /// 未登录时由子页面调用，弹出全屏登录（Tab 仍可切换）。
    var presentLogin: () -> Void {
        get { self[PresentLoginKey.self] }
        set { self[PresentLoginKey.self] = newValue }
    }
}

private struct RootTabSelectionKey: EnvironmentKey {
    static let defaultValue: Binding<RootTabView.Tab>? = nil
}

private struct PresentLoginKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

