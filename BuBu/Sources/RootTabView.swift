import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var selectedTab: Tab = .library
    @State private var isTabBarHidden: Bool = false

    enum Tab: CaseIterable {
        case library
        case capture
        case workshop
        case profile

        var title: String {
            switch self {
            case .library: return "Library"
            case .capture: return "Capture"
            case .workshop: return "Workshop"
            case .profile: return "Profile"
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
                                        ? AppTheme.Colors.tabHighlight
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
        // 登录拦截：未登录时，全局弹出登录页，覆盖一切点击
        .fullScreenCover(
            isPresented: Binding(
                get: { !env.session.isLoggedIn },
                set: { _ in }
            )
        ) {
            LoginView()
                .environmentObject(env)
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
}

private struct RootTabSelectionKey: EnvironmentKey {
    static let defaultValue: Binding<RootTabView.Tab>? = nil
}

