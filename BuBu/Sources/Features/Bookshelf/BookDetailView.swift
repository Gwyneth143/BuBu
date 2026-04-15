import SwiftUI
import Kingfisher

struct BookDetailView: View {
    private let pageWidth: CGFloat = UIScreen.main.bounds.width - 48       //册子宽度
    private let pageHeight: CGFloat = (UIScreen.main.bounds.width - 48)  * 1.414    //册子高度
    let notebook: Notebook
    let photos: [NotebookPage]
    @AppStorage("privacy.biometricLockEnabled") private var biometricLockEnabled = false
    @AppStorage("privacy.passcodeLockEnabled") private var passcodeLockEnabled = false
    @AppStorage("privacy.passcodeValue") private var passcodeValue = ""
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.tabBarHidden) private var tabBarHidden
    @Environment(\.rootTabSelection) private var rootTabSelection
    @State private var showingCoverPreview = false
    @State private var showingMoreMenu = false
    @State private var showingDeleteConfirm = false
    @State private var isDeleting = false
    @State private var isOpen = false
    @State private var currentPage: NotebookPage?
    @State private var localPages: [NotebookPage] = []
    @State private var showingPasscodePrompt = false
    @State private var passcodeInput = ""
    @State private var passcodeErrorText = ""
    
    private var displayedPages: [NotebookPage] {
        localPages.isEmpty ? notebook.pages : localPages
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    metadataSection
                    coverView
                    if isOpen{
                        notePreviewSection
                    } else {
                        openButton
                    }
                }
                .padding(.horizontal, 48)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }

            if showingMoreMenu {
                VStack(spacing: 0) {
                    // Delete row
                    Button(role: .destructive) {
                        showingMoreMenu = false
                        showingDeleteConfirm = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "trash")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color(red: 0.91, green: 0.26, blue: 0.21))
                            Text("Delete")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color(red: 0.91, green: 0.26, blue: 0.21))
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: 170)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.16), radius: 14, x: 0, y: 8)
                )
                .padding(.trailing, 16)
                .padding(.top, 8)
            }

            if showingDeleteConfirm {
                ConfirmModalView(
                    title: "删除这本册子？",
                    message: "删除后无法恢复，云端与本地缓存将一并移除。",
                    iconName: "trash.fill",
                    cancelTitle: "取消",
                    confirmTitle: "删除",
                    confirmColor: Color(red: 0.91, green: 0.26, blue: 0.21),
                    onCancel: {
                        showingDeleteConfirm = false
                    },
                    onConfirm: {
                        showingDeleteConfirm = false
                        deleteCurrentNotebook()
                    }
                )
                .zIndex(20)
            }

            if showingPasscodePrompt {
                passcodePromptView
                    .zIndex(30)
            }
        }
        .background(AppTheme.Colors.appBackground.ignoresSafeArea())
        .navigationTitle(notebook.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        showingMoreMenu.toggle()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
        }
//        .fullScreenCover(isPresented: $showingCoverPreview) {
//            CompatibleNavigationStack {
//                ZStack {
//                    Color.black.opacity(0.98).ignoresSafeArea()
//                }
//                .navigationTitle(notebook.title)
//                .navigationBarTitleDisplayMode(.inline)
//                .toolbar {
//                    ToolbarItem(placement: .cancellationAction) {
//                        Button("关闭") {
//                            showingCoverPreview = false
//                        }
//                    }
//                }
//            }
//        }
        .onAppear {
            tabBarHidden?.wrappedValue = true
            loadLocalPages()
        }
        .onDisappear {
            tabBarHidden?.wrappedValue = false
        }
    }

    // 删除册子
    private func deleteCurrentNotebook() {
        guard !isDeleting else { return }
        guard let bookId = notebook.serverBookId, bookId > 0 else { return }
        isDeleting = true
        Task {
            defer {
                Task { @MainActor in
                    isDeleting = false
                }
            }

            do {
                try await env.bookStore.deleteBook(bookId: bookId)
                try? await env.documentStore.deleteNotebook(bookId)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                // 先避免中断用户流程；后续可接统一 toast/弹框。
            }
        }
    }

    // 加载册子数据
    private func loadLocalPages() {
        Task {
            let pages = (try? await env.documentStore.fetchPages(for: notebook.serverBookId)) ?? []
            await MainActor.run {
                localPages = pages
                if currentPage == nil {
                    currentPage = pages.first ?? photos.first ?? notebook.pages.first
                }
            }
        }
    }
    
    private var metadataSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Label(notebook.category, systemImage: "folder")
                    .labelStyle(.titleAndIcon)
                Text("|")
                Label(displayDate.uppercased(), systemImage: "calendar")
                    .labelStyle(.titleAndIcon)
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(Color(hex: "96A0B3"))
        }
        .frame(maxWidth: .infinity)
    }
    
    private var coverView: some View {
        ZStack {
            if isOpen {
                BookDetailAlbumView(notebook: notebook, photos: displayedPages, currentPage: $currentPage)
            }
            if !isOpen {
                KFImage.url(URL(string: notebook.cover.imageUrl))
                    .placeholder { ProgressView() }
                    .onFailureView {
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    }
                    .fade(duration: 0.2)
                    .resizable()
                    .scaledToFill()
                    .aspectRatio(1.0/1.414, contentMode: .fill)
                    .frame(width: pageWidth,height: pageHeight)
                    .clipped()
                    .shadow(color: Color.black.opacity(0.5), radius: 10, x: 4, y: 4)
                    .transition(.asymmetric(
                        insertion: .identity,
                        removal: .modifier(
                            active:   PageCurlModifier(progress: 1.0),
                            identity: PageCurlModifier(progress: 0.0)
                        )
                    ))
//                    .onTapGesture {
//                        withAnimation(.easeInOut(duration: 0.7)) {
//                            isOpen = true
//                        }
//                    }
                }
            }
    }
    struct PageCurlModifier: ViewModifier {
        var progress: CGFloat   // 0.0 → 1.0
        func body(content: Content) -> some View {
            content
                // 1. 沿右边缘旋转（透视翻页感）
                .rotation3DEffect(
                    .degrees(-160 * progress),
                    axis: (0, 1, 0),
                    anchor: .leading,
                    perspective: 0.4
                )
                // 2. 同步上移，模拟书页翻起
                .offset(y: -40 * progress)
                // 3. 淡出收尾
                .opacity(1 - progress)
        }
    }
    
    private var openButton: some View {
        if displayedPages.count == 0 {
            Button {
                rootTabSelection?.wrappedValue = .capture
            } label: {
                Text("去采集")
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
        }else {
            Button {
                guard !isOpen else { return }
                startOpenFlow()
            } label: {
                Text("开启")
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
    }

    private func startOpenFlow() {
        if passcodeLockEnabled, !passcodeValue.isEmpty {
            passcodeInput = ""
            passcodeErrorText = ""
            showingPasscodePrompt = true
            return
        }
        Task { await authenticateAndOpenIfNeeded() }
    }

    private func confirmPasscodeAndOpen() {
        guard passcodeInput == passcodeValue else {
            passcodeErrorText = "密码错误，请重试"
            return
        }
        showingPasscodePrompt = false
        Task { await authenticateAndOpenIfNeeded() }
    }

    private func authenticateAndOpenIfNeeded() async {
        if biometricLockEnabled {
            let success = await env.authService.authenticate(reason: "验证身份后开启册子")
            guard success else { return }
        }
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.7)) {
                isOpen = true
            }
        }
    }

    private var passcodePromptView: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                Text("输入密码")
                    .font(.headline)
                Text("请输入 4 位密码后开启册子")
                    .font(.caption)
                    .foregroundColor(.secondary)

                SecureField("4 位密码", text: $passcodeInput)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.12))
                    )
                    .onChange(of: passcodeInput) { value in
                        passcodeInput = String(value.filter(\.isNumber).prefix(4))
                    }

                if !passcodeErrorText.isEmpty {
                    Text(passcodeErrorText)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                HStack(spacing: 12) {
                    Button("取消") {
                        showingPasscodePrompt = false
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.12))
                    )

                    Button("确认") {
                        confirmPasscodeAndOpen()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "FF5BA8"))
                    )
                    .disabled(passcodeInput.count < 4)
                    .opacity(passcodeInput.count < 4 ? 0.6 : 1)
                }
            }
            .padding(18)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
            )
        }
    }
    
    private var notePreviewSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Color(hex: "F6EDB7"))
                .frame(width: 72, height: 12)
                .cornerRadius(3)
                .frame(maxWidth: .infinity, alignment: .center)
                .offset(y: 8)
            
            Text(currentPage?.note ?? "")
                .font(.system(size: 17, weight: .medium, design: .serif))
                .italic()
                .foregroundColor(Color(hex: "36383F"))
                .lineSpacing(7)
                .lineLimit(5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 30)
                .padding(.bottom, 24)
        }
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: "F5EDAF"))
        )
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
        .rotationEffect(.degrees(-2))
        .padding(.top, 8)
    }
    
    private var displayDate: String {
        notebook.updatedAt.formatted(.dateTime.month(.wide).day().year())
    }
}
