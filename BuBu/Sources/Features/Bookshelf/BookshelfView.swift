import SwiftUI

final class BookshelfViewModel: ObservableObject {
    @Published var notebooks: [Notebook] = []
    @Published var isLoading = false

    private let documentStore: DocumentStore

    init(documentStore: DocumentStore) {
        self.documentStore = documentStore
    }

    @MainActor
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let data = try await documentStore.fetchAllNotebooks()
            notebooks = data
        } catch {
            // TODO: 错误处理与用户提示
        }
    }

    func move(from source: IndexSet, to destination: Int) {
        notebooks.move(fromOffsets: source, toOffset: destination)
        // TODO: 同步顺序到持久化存储
    }

    func delete(at offsets: IndexSet) {
        let ids = offsets.map { notebooks[$0].id }
        notebooks.remove(atOffsets: offsets)
        Task {
            for id in ids {
                try? await documentStore.deleteNotebook(id)
            }
        }
    }
}

struct BookshelfView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var viewModel: BookshelfViewModel

    init() {
        _viewModel = StateObject(wrappedValue: BookshelfViewModel(documentStore: InMemoryDocumentStore()))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.notebooks.isEmpty {
                    ContentUnavailableView(
                        "还没有册子",
                        systemImage: "books.vertical",
                        description: Text("在采集或工坊中创建你的第一本册子。")
                    )
                } else {
                    List {
                        ForEach(viewModel.notebooks) { notebook in
                            NavigationLink {
                                BookDetailView(notebook: notebook)
                            } label: {
                                HStack(spacing: 16) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 48, height: 64)
                                        .overlay(
                                            Text(String(notebook.title.prefix(2)))
                                                .font(.caption.bold())
                                                .foregroundColor(.primary)
                                        )

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(notebook.title)
                                            .font(AppTheme.Fonts.sectionTitle)
                                        Text("共 \(notebook.pages.count) 页")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onMove(perform: viewModel.move)
                        .onDelete(perform: viewModel.delete)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("书架")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // TODO: 新建册子流程（可从工坊选择封面）
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task {
                await viewModel.load()
            }
        }
    }
}

