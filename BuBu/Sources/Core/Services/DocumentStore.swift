import Foundation

/// 负责管理册子与页面（本地数据库 / 文件系统 / iCloud 皆可）
protocol DocumentStore {
    func fetchAllNotebooks() async throws -> [Notebook]
    func saveNotebook(_ notebook: Notebook) async throws
    func deleteNotebook(_ notebookID: UUID) async throws
}

/// 简单内存实现，方便预览与原型
final class InMemoryDocumentStore: DocumentStore {
    private var notebooks: [Notebook] = []

    init() {
        // 预置一册 Demo 数据
        let demoCover = NotebookCover(
            id: UUID(),
            name: "孕期记忆册",
            isPremium: false,
            configuration: [:]
        )
        let page = NotebookPage(
            id: UUID(),
            date: Date(),
            type: .note("这是一个示例页面，你可以在这里记录孕期的点滴。")
        )
        let demoNotebook = Notebook(
            id: UUID(),
            title: "我的孕期记忆",
            createdAt: Date(),
            updatedAt: Date(),
            cover: demoCover,
            pages: [page]
        )
        notebooks = [demoNotebook]
    }

    func fetchAllNotebooks() async throws -> [Notebook] {
        notebooks
    }

    func saveNotebook(_ notebook: Notebook) async throws {
        if let index = notebooks.firstIndex(where: { $0.id == notebook.id }) {
            notebooks[index] = notebook
        } else {
            notebooks.append(notebook)
        }
    }

    func deleteNotebook(_ notebookID: UUID) async throws {
        notebooks.removeAll { $0.id == notebookID }
    }
}

