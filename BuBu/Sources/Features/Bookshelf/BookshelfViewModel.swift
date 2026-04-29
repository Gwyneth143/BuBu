import Foundation
import Combine
import SwiftUI

final class BookshelfViewModel: ObservableObject {
    @Published var notebooks: [Notebook] = []
    @Published var categorys: [String] = []
    @Published var isLoading = false

//    private let documentStore: DocumentStore
    private let categoryStore: CategoryStore
    private let bookStore: BookStore

    init(categoryStore: CategoryStore, bookStore: BookStore) {
//        self.documentStore = documentStore
        self.categoryStore = categoryStore
        self.bookStore = bookStore
    }

    @MainActor
    func load() async {
        await loadBooks(categorySelection: String.localized("bookshelf.category.all"))
        await loadCategories()
    }

    /// 与书架分类 Tab 对应：`categorySelection == "全部"` 时不传 `categoryName`；否则传给 `GET /books`。
    @MainActor
    func loadBooks(categorySelection: String) async {
        isLoading = true
        defer { isLoading = false }

        let trimmed = categorySelection.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiCategoryName: String? = (trimmed == String.localized("bookshelf.category.all")) ? nil : trimmed

        do {
            var merged: [Notebook] = []
            var page = 1
            let pageSize = 100
            while true {
                let part = try await bookStore.fetchBooks(
                    query: BookQuery(page: page, pageSize: pageSize, categoryName: apiCategoryName)
                )
                merged.append(contentsOf: part)
                if part.count < pageSize { break }
                page += 1
                if page > 50 { break }
            }
            notebooks = merged
        } catch {
            notebooks = []
//            let ids = (try? await documentStore.listNotebookIDs()) ?? []
//            var local: [Notebook] = []
//            for id in ids { if let n = try? await documentStore.fetchNotebook(id: id) { local.append(n) } }
//            if apiCategoryName == nil {
//                notebooks = local
//            } else {
//                notebooks = local.filter { $0.category == trimmed }
//            }
        }
    }

    @MainActor
    private func loadCategories() async {
        do {
            let data = try await categoryStore.fetchAllCategory()
            categorys = data
        } catch {}
    }

    func move(from source: IndexSet, to destination: Int) {
        notebooks.move(fromOffsets: source, toOffset: destination)
        // TODO: 同步顺序到持久化存储
    }

    func delete(at offsets: IndexSet) {
//        let ids = offsets.map { notebooks[$0].id }
//        notebooks.remove(atOffsets: offsets)
//        Task {
//            for id in ids {
//                try? await documentStore.deleteNotebook(id)
//            }
//        }
    }
}

