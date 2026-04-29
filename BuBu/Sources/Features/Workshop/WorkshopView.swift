import SwiftUI
import Combine
import Kingfisher

final class WorkshopViewModel: ObservableObject {
    @Published var covers: [NotebookCover] = []
    /// 当前用户在服务端上传的 DIY 皮肤（`GET /skins?type=2&creatorUserId=`）
    @Published var diySkins: [NotebookCover] = []
    /// 收藏成功等 toast 文案
    @Published var toastMessage: String?

    private let coverStore: CoverStore
    private let creatorUserIdProvider: () -> Int?

    init(coverStore: CoverStore, creatorUserIdProvider: @escaping () -> Int? = { nil }) {
        self.coverStore = coverStore
        self.creatorUserIdProvider = creatorUserIdProvider
    }

    @MainActor
    func load() async {
        do {
            let data = try await coverStore.fetchAllCovers()
            covers = data
        } catch {
            // TODO: 错误提示
        }
        await loadSavedCoverImages()
    }

    @MainActor
    func collectSkin(skinId: Int) async {
        do {
            try await coverStore.addSkinToMyCollection(skinId: skinId)
            if let idx = covers.firstIndex(where: { $0.id == skinId }) {
                var updated = covers[idx]
                updated.isCollected = true
                covers[idx] = updated
            }
            toastMessage = String.localized("workshop.toast_collect_success")
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run { toastMessage = nil }
            }
        } catch {
            toastMessage = error.localizedDescription
            Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                await MainActor.run { toastMessage = nil }
            }
        }
    }

    /// 从 `GET https://xsmb.world/skins` 拉取当前用户的 DIY 皮肤列表（`type=2`、`creatorUserId` 为登录用户）
    @MainActor
    func loadSavedCoverImages() async {
        guard let uid = creatorUserIdProvider(), uid > 0 else {
            diySkins = []
            return
        }
        do {
            let query = CoverQuery(type: 2, page: 1, pageSize: 50, creatorUserId: uid)
            diySkins = try await coverStore.fetchAllCovers(query: query)
        } catch {
            // 网络/解析失败或并发请求后失败时不应清空，否则下拉刷新会把已有列表抹掉
        }
    }

    /// `POST /skins/delete`，body `{ "skinId": <skins.id> }`
    @MainActor
    func deleteDiySkin(skinId: Int) async {
        do {
            try await coverStore.deleteSkin(skinId: skinId)
            diySkins.removeAll { $0.id == skinId }
            toastMessage = String.localized("workshop.toast_skin_deleted")
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run { toastMessage = nil }
            }
        } catch {
            toastMessage = error.localizedDescription
            Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                await MainActor.run { toastMessage = nil }
            }
        }
    }
}

struct WorkshopView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.presentLogin) private var presentLogin
    @StateObject private var viewModel: WorkshopViewModel
    @Environment(\.rootTabSelection) private var rootTabSelection
    @State private var showCoverEditor = false
    @State private var showingDeleteConfirm = false
    @State private var deletingSkinID: Int?

    /// 与 `RootTabView` 当前选中 Tab 同步（常驻 Tab 时子视图始终在树上，不能仅依赖 `onAppear`）
    private var selectedRootTab: RootTabView.Tab {
        rootTabSelection?.wrappedValue ?? .library
    }

    private var canCreateMoreDiy: Bool {
        viewModel.diySkins.count < 3
    }

    init(coverStore: CoverStore, creatorUserIdProvider: @escaping () -> Int? = { nil }) {
        _viewModel = StateObject(wrappedValue: WorkshopViewModel(
            coverStore: coverStore,
            creatorUserIdProvider: creatorUserIdProvider
        ))
    }

    var body: some View {
        CompatibleNavigationStack {
            ZStack {
                NavigationLink(destination: CoverEditorView(), isActive: $showCoverEditor) {
                    EmptyView()
                }
                .frame(width: 0, height: 0)
                .opacity(0)

                AppTheme.Colors.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        titleSection
                        previewSection
                        materialsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
                .refreshable {
                    await viewModel.load()
                }
                if let message = viewModel.toastMessage {
                    VStack {
                        Spacer()
                        Text(message)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.78))
                            .clipShape(Capsule())
                            .padding(.bottom, 88)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.2), value: viewModel.toastMessage)
                }

                if showingDeleteConfirm {
                    ConfirmModalView(
                        title: String.localized("common.delete_confirm_title"),
                        message: String.localized("workshop.delete_skin_confirm_message"),
                        iconName: "trash.fill",
                        cancelTitle: String.localized("common.cancel"),
                        confirmTitle: String.localized("common.delete"),
                        confirmColor: Color(red: 0.91, green: 0.26, blue: 0.21),
                        onCancel: {
                            showingDeleteConfirm = false
                            deletingSkinID = nil
                        },
                        onConfirm: {
                            let skinId = deletingSkinID
                            showingDeleteConfirm = false
                            deletingSkinID = nil
                            guard let skinId else { return }
                            Task { await viewModel.deleteDiySkin(skinId: skinId) }
                        }
                    )
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            if selectedRootTab == .workshop {
                Task { await viewModel.load() }
            }
        }
        .onChange(of: selectedRootTab) { newTab in
            if newTab == .workshop {
                Task { await viewModel.load() }
            }
        }
        .onChange(of: env.session.isLoggedIn) { loggedIn in
            if loggedIn {
                Task { await viewModel.load() }
            } else {
                viewModel.covers = []
                viewModel.diySkins = []
                viewModel.toastMessage = nil
                showCoverEditor = false
            }
        }
        .onChange(of: showCoverEditor) { isPresented in
            // CoverEditor 关闭（保存后或手动返回）时，立即刷新 DIY 设计列表
            guard !isPresented, env.session.isLoggedIn, selectedRootTab == .workshop else { return }
            Task { await viewModel.loadSavedCoverImages() }
        }
    }

    private var titleSection: some View {
        Text(localized: "workshop.title")
            .font(AppTheme.Fonts.navTitle)
            .kerning(0.8)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized: "workshop.section_diy")
                .font(.caption)
                .foregroundColor(.secondary)

            if viewModel.diySkins.isEmpty {
                emptyPreviewCard
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.diySkins) { cover in
                            coverImageCard(cover: cover)
                        }
                        addPreviewCoverCell
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var emptyPreviewCard: some View {
        Button {
            openCoverEditorIfAllowed()
        } label: {
            VStack(spacing: 16) {
                Circle()
                    .fill(Color(hex: "F4F9F4"))
                    .frame(width: 72, height: 72)
                    .overlay(
                        Image(systemName: "paintbrush.pointed")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.primaryColor)
                    )

                Text(localized: "workshop.empty_diy_card")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
    }

    private func requireLogin() -> Bool {
        if env.session.isLoggedIn { return true }
        presentLogin()
        return false
    }

    private func coverImageCard(cover: NotebookCover) -> some View {
        let url = URL(string: cover.thumbUrl.isEmpty ? cover.imageUrl : cover.thumbUrl)
        return ZStack(alignment: .topTrailing) {
            KFImage.url(url)
                .placeholder {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.gray.opacity(0.15))
                        .overlay(ProgressView())
                }
                .onFailureView {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                        )
                }
                .fade(duration: 0.2)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
            Button {
                guard requireLogin() else { return }
                deletingSkinID = cover.id
                showingDeleteConfirm = true
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(AppTheme.Colors.primaryColor)
                    .frame(width: 40, height: 40)
                    .scaledToFill()
            }
        }
    }

    /// 与 `coverImageCard` 同尺寸，点击去 DIY 封面编辑
    private var addPreviewCoverCell: some View {
        Button {
            openCoverEditorIfAllowed()
        } label: {
            Rectangle()
                .fill(Color.white.opacity(0.6))
                .frame(width: 100, height: 140)
                .overlay(
                    Rectangle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                        .foregroundColor(Color.gray.opacity(0.4))
                )
                .overlay(
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(AppTheme.Colors.primaryColor.opacity(0.9))
                )
                .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .opacity(canCreateMoreDiy ? 1 : 0.45)
    }

    private func openCoverEditorIfAllowed() {
        guard requireLogin() else { return }
        guard canCreateMoreDiy else {
            viewModel.toastMessage = String.localized("workshop.toast_diy_limit_reached")
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run { viewModel.toastMessage = nil }
            }
            return
        }
        showCoverEditor = true
    }

    private var materialsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized: "workshop.section_skin_gallery")
                .font(.caption)
                .foregroundColor(.secondary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: 16)],
                spacing: 16
            ) {
                ForEach(viewModel.covers) { cover in
                    materialCard(for: cover)
                }
            }
        }
    }

    private func materialCard(for cover: NotebookCover) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(hex: "FFFFFF"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
                    .aspectRatio(1.0/1.414, contentMode: .fit)
                    .overlay(
                        KFImage.url(URL(string: cover.imageUrl))
                            .placeholder { ProgressView() }
                            .onFailureView {
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                            }
                            .fade(duration: 0.2)
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    )

                if cover.isPremium {
                    Text(localized: "workshop.badge_member")
                        .foregroundColor(AppTheme.Colors.primaryColor)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .stroke(AppTheme.Colors.primaryColor, lineWidth: 1)
                        )
                        .padding(8)
                }
            }

            
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 8 ){
                    Text(cover.name)
                        .font(.footnote.weight(.semibold))
                    Text("¥\(cover.price)")
                        .font(.caption2)
                        .foregroundColor(AppTheme.Colors.primaryColor)
                }
                Spacer()
                Button {
                    guard requireLogin() else { return }
                    if !cover.isCollected {
                        Task { await viewModel.collectSkin(skinId: cover.id) }
                    }else {
                    }
                } label: {
                    Image(systemName: cover.isCollected ? "heart.fill" : "heart")
                        .foregroundColor(AppTheme.Colors.primaryColor)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
        )
    }
}

