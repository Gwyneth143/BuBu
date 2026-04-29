import SwiftUI
import Kingfisher

struct CreateNotebookView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var env: AppEnvironment

    @State private var title: String = ""
    @State private var selectedStyleTab: StyleTab = .solid
    @State private var selectedCover: NotebookCover?
    @State private var selectedCategory: String?
    @State private var showingAddCategory = false
    @State private var newCategoryName = ""
    @State private var categoryErrorMessage: String?
    @State private var createErrorMessage: String?
    @State private var isCreating = false
    @FocusState private var isTitleFieldFocused: Bool

    private enum StyleTab: String, CaseIterable {
        case solid = "系统封面"
        case skins = "我的封面"
        case diy = "DIY封面"
    }

    @State private var solidOptions: [NotebookCover] = []

    @State private var skinOptions: [NotebookCover] = []
    
    @State private var diyOptions: [NotebookCover] = []

    private var currentCoverOptions: [NotebookCover] {
        switch selectedStyleTab {
        case .solid:
            solidOptions
        case .skins:
            skinOptions
        case .diy:
            diyOptions
        }
    }

    var body: some View {
        CompatibleNavigationStack {
            ZStack(alignment: .bottom) {
                AppTheme.Colors.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        titleSection
                        categorySection
                        styleSection
                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                }
                .scrollDismissesKeyboardIfAvailable()

                createButton
            }
            .navigationTitle(String.localized("create_journal.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(AppTheme.Colors.navTitleColor)
                    }
                }
            }
        }
        .onAppear {
            Task {
                do {
                    let remote = try await env.categoryStore.fetchAllCategory()
                    await MainActor.run {
                        if selectedCategory == nil, let first = remote.first {
                            selectedCategory = first
                        }
                    }
                } catch {
                    await MainActor.run {
                        if selectedCategory == nil, let first = env.categoryStore.categories.first {
                            selectedCategory = first
                        }
                    }
                }
            }
            Task {
                do {
                    let remoteSolid = try await env.coverStore.fetchSystemCovers(type: 0)
                    await MainActor.run {
                        solidOptions = remoteSolid
                        if selectedStyleTab == .solid, selectedCover == nil {
                            selectedCover = remoteSolid.first
                        }
                    }
                } catch {
                    // 无网或接口异常时，继续使用本地兜底 solidOptions
                }
            }
            Task {
                do {
                    let remoteSkins = try await env.coverStore.fetchMyCovers(query: CoverQuery(page: 1, pageSize: 20))
                    await MainActor.run {
                        skinOptions = remoteSkins
                        if selectedStyleTab == .skins, selectedCover == nil {
                            selectedCover = remoteSkins.first
                        }
                    }
                } catch {
                    // 未登录或接口失败时保持空数组
                }
            }
            Task {
                do {
                    let remoteSkins = try await env.coverStore.fetchAllCovers(query: CoverQuery(type:2))
                    await MainActor.run {
                        diyOptions = remoteSkins
                        if selectedStyleTab == .diy, selectedCover == nil {
                            selectedCover = remoteSkins.first
                        }
                    }
                } catch {
                    // 未登录或接口失败时保持空数组
                }
            }
        }
        .overlay {
            if showingAddCategory {
                InputModalView(
                    title: String.localized("create_journal.add_category"),
                    subtitle: String.localized("create_journal.add_category_subtitle"),
                    inputLabel: String.localized("create_journal.category"),
                    placeholder: String.localized("create_journal.category_placeholder"),
                    text: $newCategoryName,
                    cancelTitle: String.localized("common.cancel"),
                    confirmTitle: String.localized("common.confirm"),
                    onCancel: {
                        showingAddCategory = false
                        newCategoryName = ""
                    },
                    onConfirm: {
                        let nameToAdd = newCategoryName
                        Task {
                            do {
                                try await env.categoryStore.addCategory(name: nameToAdd)
                                if let added = env.categoryStore.categories.last {
                                    await MainActor.run {
                                        selectedCategory = added
                                    }
                                }
                            } catch {
                                await MainActor.run {
                                    categoryErrorMessage = error.localizedDescription
                                }
                            }
                        }
                        showingAddCategory = false
                        newCategoryName = ""
                    }
                )
            }
        }
        .alert(String.localized("create_journal.create_error"), isPresented: Binding(
            get: { categoryErrorMessage != nil },
            set: { if !$0 { categoryErrorMessage = nil } }
        )) {
            Button(String.localized("common.confirm"), role: .cancel) { categoryErrorMessage = nil }
        } message: {
            Text(categoryErrorMessage ?? "")
        }
        .alert(String.localized("create_journal.new_category_error"), isPresented: Binding(
            get: { createErrorMessage != nil },
            set: { if !$0 { createErrorMessage = nil } }
        )) {
            Button(String.localized("common.confirm"), role: .cancel) { createErrorMessage = nil }
        } message: {
            Text(createErrorMessage ?? "")
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localized: "create_journal.journal_title")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField(String.localized("create_journal.title_placeholder"), text: $title)
                .font(AppTheme.Fonts.body)
                .focused($isTitleFieldFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                )
        }
        .padding(.top, 8)
    }

    private var styleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized: "create_journal.choose_cover")
                .font(.caption)
                .foregroundColor(.secondary)

            // Segmented control
            HStack(spacing: 0) {
                ForEach(StyleTab.allCases, id: \.self) { tab in
                    Button {
                        selectedStyleTab = tab
                        if let first = currentCoverOptions.first {
                            selectedCover = first
                        }
                    } label: {
                        Text(tab.rawValue)
                            .font(.caption)
                            .foregroundColor(selectedStyleTab == tab ? .white : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selectedStyleTab == tab ? AppTheme.Colors.primaryColor : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.9))
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            )

            // Cover options grid
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 16)], spacing: 16) {
                ForEach(currentCoverOptions) { option in
                    VStack(spacing: 6) {
                        coverPreview(option)
                            .frame(width: 90, height: 128)
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(
                                        selectedCover?.id == option.id
                                        ? AppTheme.Colors.primaryColor
                                        : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 4)
                    }
                    .frame(maxWidth: .infinity)
                    .onTapGesture {
                        selectedCover = option
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func coverPreview(_ option: NotebookCover) -> some View {
        if option.image.hasPrefix("http") {
            KFImage.url(URL(string: option.image))
                .placeholder {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.12))
                        .overlay(ProgressView())
                }
                .onFailureView {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.15))
                        .overlay(Image(systemName: "photo").foregroundColor(.secondary))
                }
                .fade(duration: 0.2)
                .resizable()
                .scaledToFill()
                .clipped()
        } else {
            Image(option.image)
                .resizable()
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized: "create_journal.category")
                .font(.caption)
                .foregroundColor(.secondary)
            let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]
            LazyVGrid(columns: columns, spacing: 8) {
                if !env.categoryStore.categories.isEmpty {
                    ForEach(env.categoryStore.categories, id: \.self) { cat in
                        categoryChip(cat)
                    }
                }
                addCategoryChip
            }
        }
    }

    private func categoryChip(_ category: String) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            selectedCategory = category
        } label: {
            Text(category)
            .font(.caption)
            .foregroundColor(isSelected ? AppTheme.Colors.primaryColor : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.white : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isSelected ? AppTheme.Colors.primaryColor : Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var addCategoryChip: some View {
        Button {
            newCategoryName = ""
            showingAddCategory = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.caption)
                Text(localized: "create_journal.new_category" )
                    .font(.caption)
            }
            .foregroundColor(AppTheme.Colors.primaryColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(AppTheme.Colors.primaryColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var isCreateEnabled: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && selectedCover != nil
            && selectedCategory != nil
    }

    private var createButton: some View {
        Button {
            guard
                let category = selectedCategory,
                let cover = selectedCover,
                !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return }

            Task {
                await MainActor.run {
                    isCreating = true
                    createErrorMessage = nil
                }
                do {
                    let _ = try await env.bookStore.createBook(
                        title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                        categoryName: category,
                        skinId: cover.id
                    )
                    await MainActor.run {
                        isCreating = false
                        dismiss()
                    }
                } catch {
                    await MainActor.run {
                        isCreating = false
                        createErrorMessage = error.localizedDescription
                    }
                }
            }
        } label: {
            Group {
                if isCreating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(localized: "create_journal.create_btn")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(AppTheme.Colors.primaryColor)
            )
        }
        .buttonStyle(.plain)
        .shadow(color: AppTheme.Colors.shadowColor, radius: 6,x: 4,y: 4)
        .disabled(!isCreateEnabled || isCreating)
        .opacity((isCreateEnabled && !isCreating) ? 1 : 0.5)
        .padding(.horizontal, 32)
        .padding(.bottom, 24)
    }
}

#Preview {
    CreateNotebookView()
        .environmentObject(AppEnvironment.bootstrap())
}

