import SwiftUI

struct BookshelfView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.presentLogin) private var presentLogin
    @Environment(\.rootTabSelection) private var rootTabSelection
    @StateObject private var viewModel: BookshelfViewModel
    @State private var searchText: String = ""
    @State private var selectedCategory: String = String.localized("bookshelf.category.all")
    @State private var showingCreateNotebook = false
    @State private var selectedNotebook: Notebook?

    init(categoryStore: CategoryStore, bookStore: BookStore) {
        _viewModel = StateObject(
            wrappedValue: BookshelfViewModel(
                categoryStore: categoryStore,
                bookStore: bookStore
            )
        )
    }

    var body: some View {
        CompatibleNavigationStack {
            ZStack {
                NavigationLink(
                    destination: Group {
                        if let n = selectedNotebook {
                            BookDetailView(notebook: n, photos: n.pages)
                        }
                    },
                    isActive: Binding(
                        get: { selectedNotebook != nil },
                        set: { if !$0 { selectedNotebook = nil } }
                    )
                ) {
                    EmptyView()
                }
                .frame(width: 0, height: 0)
                .hidden()

                AppTheme.Colors.appBackground
                    .ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        title
//                        searchBar
                        CategoryTabsView(
                            categories: viewModel.categorys,
                            selection: $selectedCategory,
                            onLoginGate: {
                                if env.session.isLoggedIn { return true }
                                presentLogin()
                                return false
                            }
                        )
                        shelves
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $showingCreateNotebook, onDismiss: {
                Task {
                    await viewModel.loadBooks(categorySelection: selectedCategory)
                }
            }) {
                CreateNotebookView()
            }
            .onAppear {
                Task { await viewModel.load() }
            }
            .onChange(of: selectedCategory) { newValue in
                Task { await viewModel.loadBooks(categorySelection: newValue) }
            }
            .onChange(of: env.session.isLoggedIn) { loggedIn in
                // 常驻 Tab 下登录成功不会触发 onAppear，这里显式刷新数据。
                if loggedIn {
                    Task { await viewModel.load() }
                } else {
                    viewModel.notebooks = []
                    viewModel.categorys = []
                    selectedNotebook = nil
                }
            }
            .onChange(of: selectedRootTab) { newTab in
                // 切离书架时重置导航栈，避免返回书架仍停留在详情页。
                if newTab != .library {
                    selectedNotebook = nil
                }
            }
        }
    }

    private var selectedRootTab: RootTabView.Tab {
        rootTabSelection?.wrappedValue ?? .library
    }

    private func requireLogin() -> Bool {
        if env.session.isLoggedIn { return true }
        presentLogin()
        return false
    }

    private var title: some View {
        Text(localized: "bookshelf.title")
            .font(AppTheme.Fonts.navTitle)
            .foregroundStyle(AppTheme.Colors.navTitleColor)
//                .kerning(1.2)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField(String.localized("bookshelf.search_placeholder"), text: $searchText)
                .font(.subheadline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(AppTheme.Colors.surfaceColor)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
    }

    private var shelfColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 18, alignment: .center), count: 3)
    }

    @ViewBuilder
    private var shelves: some View {
        if filteredNotebooks.isEmpty {
            emptyState
        } else {
            LazyVGrid(columns: shelfColumns, alignment: .center, spacing: 32) {
                ForEach(Array(filteredNotebooks.enumerated()), id: \.element.id) { index, notebook in
                    Button {
                        guard requireLogin() else { return }
                        selectedNotebook = notebook
                    } label: {
                        ShelfCardView(
                            notebook: notebook,
                            styleIndex: index
                        )
                    }
                    .buttonStyle(.plain)
                }

                addCard
            }
            .padding(.top, 16)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Circle()
                .fill(Color(hex: "F3F4F6"))
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: "book.pages")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(Color(hex: "6B7280"))
                )
                .overlay(
                    Circle()
                        .stroke(Color(hex: "E5E7EB"), lineWidth: 2)
                )
                .padding(.top, 40)

            Text(localized: "bookshelf.empty_title")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "374151"))
                .multilineTextAlignment(.center)
            Spacer(minLength: 24)
            Button {
                guard requireLogin() else { return }
                showingCreateNotebook = true
            } label: {
                Text(localized: "bookshelf.create_journal")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(AppTheme.Colors.primaryColor)
                    )
                    .shadow(color: AppTheme.Colors.shadowColor, radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
    }

    private var addCard: some View {
        VStack {
            Button {
                guard requireLogin() else { return }
                showingCreateNotebook = true
            } label: {
                RoundedRectangle(cornerRadius: 26)
                    .fill(AppTheme.Colors.surfaceColor)
                    .frame(width: 88, height: 140)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.title2.weight(.semibold))
                            .foregroundColor(.secondary)
                    )
                    .shadow(color: AppTheme.Colors.shadowColor, radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }

    /// 列表已由 `loadBooks` 按分类从接口拉取；此处仅做搜索关键字过滤。
    private var filteredNotebooks: [Notebook] {
        let list = viewModel.notebooks
        guard !searchText.isEmpty else { return list }
        return list.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
}

