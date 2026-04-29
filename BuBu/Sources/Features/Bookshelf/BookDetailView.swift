import SwiftUI
import Kingfisher

struct BookDetailView: View {
    private let pageWidth: CGFloat = UIScreen.main.bounds.width - 60       //册子宽度
    private let pageHeight: CGFloat = (UIScreen.main.bounds.width - 60)  * 1.414   //册子高度
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
    @State private var showingDeletePageConfirm = false
    @State private var isDeleting = false
    @State private var isOpen = false
    @State private var showingTagsModal = false
    @State private var currentPage: NotebookPage?
    @State private var localPages: [NotebookPage] = []
    @State private var hasLoadedLocalPages = false
    @State private var showingPasscodePrompt = false
    @State private var passcodePromptContext: PasscodePromptContext = .open
    @State private var passcodeInput = ""
    @State private var passcodeErrorText = ""

    private enum PasscodePromptContext {
        case open
        case delete
    }
    
    private var displayedPages: [NotebookPage] {
        hasLoadedLocalPages ? localPages : notebook.pages
    }

    private var pageTags: [String] {
        Array(
            Set(
                displayedPages
                    .map { $0.tag.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        ).sorted()
    }

    private var tagFirstPageMap: [String: NotebookPage] {
        var result: [String: NotebookPage] = [:]
        for page in displayedPages {
            let normalizedTag = page.tag.trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalizedTag.isEmpty, result[normalizedTag] == nil {
                result[normalizedTag] = page
            }
        }
        return result
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
                    Button(role: .destructive) {
                        showingMoreMenu = false
                        showingDeletePageConfirm = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "trash.slash")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color(red: 0.91, green: 0.26, blue: 0.21))
                            Text(localized: "bookdetail.delete_page")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color(red: 0.91, green: 0.26, blue: 0.21))
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .disabled(currentPage == nil)
                    .opacity(currentPage == nil ? 0.5 : 1)

                    Divider()
                        .padding(.horizontal, 12)

                    // Delete row
                    Button(role: .destructive) {
                        showingMoreMenu = false
                        beginDeleteSecureFlow()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "trash")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color(red: 0.91, green: 0.26, blue: 0.21))
                            Text(localized: "common.delete")
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
                    title: String.localized("bookdetail.book_delete"),
                    message: String.localized("bookdetail.book_delete_info"),
                    iconName: "trash.fill",
                    cancelTitle: String.localized("common.cancel"),
                    confirmTitle: String.localized("common.delete"),
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

            if showingDeletePageConfirm {
                ConfirmModalView(
                    title: String.localized("bookdetail.delete_page_title"),
                    message: String.localized("bookdetail.delete_page_message"),
                    iconName: "trash.slash.fill",
                    cancelTitle: String.localized("common.cancel"),
                    confirmTitle: String.localized("common.delete"),
                    confirmColor: Color(red: 0.91, green: 0.26, blue: 0.21),
                    onCancel: {
                        showingDeletePageConfirm = false
                    },
                    onConfirm: {
                        showingDeletePageConfirm = false
                        deleteCurrentPage()
                    }
                )
                .zIndex(21)
            }

            if showingTagsModal {
                tagGridModalView
                .zIndex(25)
            }

            if showingPasscodePrompt {
                passcodePromptView
                    .zIndex(30)
            }
        }
        .background(AppTheme.Colors.appBackground.ignoresSafeArea())
        .navigationTitle(notebook.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                }
                .accessibilityLabel(Text(localized: "bookdetail.back"))
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        showingMoreMenu.toggle()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .accessibilityLabel(Text(localized: "bookdetail.toolbar_more"))
            }
        }
        .onAppear {
            tabBarHidden?.wrappedValue = true
            loadLocalPages()
        }
        .onDisappear {
            tabBarHidden?.wrappedValue = false
        }
        /// 从详情切到采集/工坊/个人等 Tab 时视图常不离栈，onDisappear 不触发；切回书架时需再次隐藏 TabBar。
        .onChange(of: rootTabSelection?.wrappedValue ?? .library) { newTab in
            if newTab == .library {
                tabBarHidden?.wrappedValue = true
            }
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

    // 删除当前页
    private func deleteCurrentPage() {
        guard let page = currentPage else { return }
        Task {
            guard var book = try? await env.documentStore.fetchNotebook(id: notebook.serverBookId) else { return }
            book.pages.removeAll { $0.id == page.id }
            book.pages = book.pages.enumerated().map { index, p in
                var copy = p
                copy.sortIndex = index
                return copy
            }
            book.updatedAt = Date()
            try? await env.documentStore.saveNotebook(book)
            await MainActor.run {
                localPages = book.pages
                hasLoadedLocalPages = true
                currentPage = book.pages.first
                if book.pages.isEmpty {
                    isOpen = false
                }
            }
        }
    }

    // 加载册子数据
    private func loadLocalPages() {
        Task {
            let pages = (try? await env.documentStore.fetchPages(for: notebook.serverBookId)) ?? []
            await MainActor.run {
                localPages = pages
                hasLoadedLocalPages = true
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

            Button {
                showingTagsModal = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "tag.fill")
                    Text("\(String.localized("bookdetail.tags_button")) (\(pageTags.count))")
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.Colors.primaryColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.white)
                        .overlay(
                            Capsule().stroke(AppTheme.Colors.primaryColor.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var coverView: some View {
        ZStack {
            if isOpen {
                BookDetailAlbumView(notebook: notebook, photos: displayedPages, currentPage: $currentPage)
            }
            if !isOpen {
                ZStack(alignment: .bottomTrailing) {
                    Rectangle()
                        .fill(AppTheme.Colors.shadowBlockColor)
                        .frame(width: pageWidth,height: pageHeight)
                        .offset(x: 4,y: 4)
                        .shadow(color: AppTheme.Colors.shadowColor, radius: 10, x: 2, y: 2)
                    KFImage.url(URL(string: notebook.cover.imageUrl))
                        .placeholder { ProgressView() }
                        .onFailureView {
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                        }
                        .fade(duration: 0.2)
                        .resizable()
                        .scaledToFill()
                        .frame(width: pageWidth,height: pageHeight)
                        .clipped()
                        .transition(.asymmetric(
                            insertion: .identity,
                            removal: .modifier(
                                active:   PageCurlModifier(progress: 1.0),
                                identity: PageCurlModifier(progress: 0.0)
                            )
                        ))
                }
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
                tabBarHidden?.wrappedValue = false
                rootTabSelection?.wrappedValue = .capture
            } label: {
                Text(localized: "bookdetail.capture")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(AppTheme.Colors.primaryColor)
                    )
            }
            .buttonStyle(.plain)
        }else {
            Button {
                guard !isOpen else { return }
                startOpenFlow()
            } label: {
                Text(localized:"bookdetail.open")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(AppTheme.Colors.primaryColor)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func startOpenFlow() {
        if passcodeLockEnabled, !passcodeValue.isEmpty {
            passcodePromptContext = .open
            passcodeInput = ""
            passcodeErrorText = ""
            showingPasscodePrompt = true
            return
        }
        Task { await authenticateAndOpenIfNeeded() }
    }

    /// 删除前：先密码锁（若开启）→ 再面容锁（若开启）→ 最后弹出删除确认
    private func beginDeleteSecureFlow() {
        if passcodeLockEnabled, !passcodeValue.isEmpty {
            passcodePromptContext = .delete
            passcodeInput = ""
            passcodeErrorText = ""
            showingPasscodePrompt = true
            return
        }
        Task { await authenticateForDeleteIfNeeded() }
    }

    private func confirmPasscodeForDelete() {
        guard passcodeInput == passcodeValue else {
            passcodeErrorText = String.localized("bookdetail.password.error")
            return
        }
        showingPasscodePrompt = false
        Task { await authenticateForDeleteIfNeeded() }
    }

    private func authenticateForDeleteIfNeeded() async {
        if biometricLockEnabled {
            let success = await env.authService.authenticate(reason: String.localized("bookdetail.delete_auth_reason"))
            guard success else { return }
        }
        await MainActor.run {
            showingDeleteConfirm = true
        }
    }

    private func confirmPasscodeAndOpen() {
        guard passcodeInput == passcodeValue else {
            passcodeErrorText = String.localized("bookdetail.password.error")
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
                Text(localized: "bookdetail.password.title")
                    .font(.headline)
                Text(String.localized(passcodePromptContext == .open ? "bookdetail.password.subtitle" : "bookdetail.password.delete_subtitle"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                SecureField(String.localized("bookdetail.password.placeholder"), text: $passcodeInput)
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
                    Button(String.localized("common.cancel")) {
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

                    Button(String.localized("common.confirm")) {
                        switch passcodePromptContext {
                        case .open:
                            confirmPasscodeAndOpen()
                        case .delete:
                            confirmPasscodeForDelete()
                        }
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppTheme.Colors.primaryColor)
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

    private var tagGridModalView: some View {
        let columns = [GridItem(.adaptive(minimum: 110), spacing: 10)]
        return ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    showingTagsModal = false
                }

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(String.localized("bookdetail.tags_modal_title"), systemImage: "tag.fill")
                        .font(.headline)
                    Spacer()
                    Button {
                        showingTagsModal = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.gray.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }

                Text(localized: "bookdetail.tags_tap_hint")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if pageTags.isEmpty {
                    Text(localized: "bookdetail.tags_empty")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 16)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                            ForEach(pageTags, id: \.self) { tag in
                                Button {
                                    if let targetPage = tagFirstPageMap[tag] {
                                        currentPage = targetPage
                                    }
                                    if !isOpen {
                                        withAnimation(.easeInOut(duration: 0.7)) {
                                            isOpen = true
                                        }
                                    }
                                    showingTagsModal = false
                                } label: {
                                    Text(tag)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(AppTheme.Colors.primaryColor)
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color.white)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(AppTheme.Colors.primaryColor.opacity(0.35), lineWidth: 1)
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 260)
                }
            }
            .padding(18)
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 10)
            )
            .padding(.horizontal, 24)
        }
    }
}
