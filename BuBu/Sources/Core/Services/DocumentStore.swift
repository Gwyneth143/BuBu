import Foundation

// MARK: - 能力说明

struct DocumentStorageCapabilities: Sendable {
    var supportsSyncMetadata: Bool
    var supportsSoftDelete: Bool
}

// MARK: - 协议（整本 `Notebook` 持久化：含 `tags`、`pages`、`cover` 等）

/// 本地/数据库实现：读写的最小单位是 **整本 `Notebook`**（`Codable` 已包含 `tags` 与 `pages`）。
/// - `id` 与本地目录 / SwiftData 主键一致，即 `Notebook.id`（`UUID`）。
protocol DocumentStore {
    /// 按本地主键读取整本册子；不存在则 `nil`。
    func fetchNotebook(id: Int?) async throws -> Notebook?
    /// 仅返回已存在册子的 `id` 列表（不保证调用方会逐本 `fetchNotebook`；用于同步等需枚举的场景）。
//    func listNotebookIDs() async throws -> [UUID]
    func saveNotebook(_ notebook: Notebook) async throws
    func deleteNotebook(_ notebookID: Int) async throws

    func fetchNotebookIDsPendingSync() async throws -> [UUID]
    var storageCapabilities: DocumentStorageCapabilities { get }
}

extension DocumentStore {
    /// 默认实现：从整本册子中取页；需要单独优化时可在具体存储里覆写。
    func fetchPages(for notebookID: Int?) async throws -> [NotebookPage] {
        guard let n = try await fetchNotebook(id: notebookID) else {
            return []
        }
        return n.pages.sorted { $0.sortIndex < $1.sortIndex }
    }

    func fetchNotebookIDsPendingSync() async throws -> [UUID] { [] }

    var storageCapabilities: DocumentStorageCapabilities {
        DocumentStorageCapabilities(supportsSyncMetadata: false, supportsSoftDelete: false)
    }
}

// MARK: - 内存（预览 / 测试）

final class InMemoryDocumentStore: DocumentStore {
    private var notebooks: [Notebook] = []

    func fetchNotebook(id: Int?) async throws -> Notebook? {
        notebooks.first { $0.serverBookId == id }
    }

//    func listNotebookIDs() async throws -> [UUID] {
//        notebooks.map(\.id)
//    }

    func saveNotebook(_ notebook: Notebook) async throws {
        if let i = notebooks.firstIndex(where: { $0.id == notebook.id }) {
            notebooks[i] = notebook
        } else {
            notebooks.append(notebook)
        }
    }

    func deleteNotebook(_ notebookID: Int) async throws {
        notebooks.removeAll { $0.serverBookId == notebookID }
    }
}

// MARK: - 本地 JSON：每本一目录 `books/<Notebook.id>/notebook.json`

/// 目录：`Application Support/BuBu/books/<uuid>/notebook.json`，内容为完整 **`Notebook`**（含 pages、tags）。
actor LocalDocumentStore: DocumentStore {
    private var cache: [String: Notebook] = [:]
    private let booksDir: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(subdirectory: String = "BuBu") {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        booksDir = base.appendingPathComponent(subdirectory, isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)

        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        decoder = dec

        try? fm.createDirectory(at: booksDir, withIntermediateDirectories: true)
//        try? reloadCacheFromDisk()
    }

    func fetchNotebook(id: Int?) async throws -> Notebook? {
        let notebookID = getNotebookID(id: id)
        if let cached = cache[notebookID] {
            return cached
        }
        guard let data = try? dataForNotebookFile(notebookID: notebookID),
              let book = try? decoder.decode(Notebook.self, from: data) else {
            return nil
        }
        cache[notebookID] = book
        return book
    }
    
    func getNotebookID(id: Int?)  ->String{
        id == nil ? "draft" : "\(id!)"
    }

//    func listNotebookIDs() async throws -> [UUID] {
//        let fm = FileManager.default
//        guard fm.fileExists(atPath: booksDir.path) else {
//            return Array(cache.keys)
//        }
//        let items = try fm.contentsOfDirectory(at: booksDir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
//        let ids: [UUID] = items.compactMap { item -> UUID? in
//            guard (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return nil }
//            guard let id = UUID(uuidString: item.lastPathComponent) else { return nil }
//            let json = item.appendingPathComponent("notebook.json")
//            return fm.fileExists(atPath: json.path) ? id : nil
//        }
//        return ids
//    }

    func fetchPages(for id: Int?) async throws -> [NotebookPage] {
        guard let book = try await fetchNotebook(id: id) else {
            return []
        }
        return book.pages.sorted { $0.sortIndex < $1.sortIndex }
    }

    func saveNotebook(_ notebook: Notebook) async throws {
        let persisted = Self.normalizedNotebook(notebook)
        let notebookID = getNotebookID(id: persisted.serverBookId)
        let dir = booksDir.appendingPathComponent(notebookID, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("notebook.json")
        let data = try encoder.encode(persisted)
        try data.write(to: url, options: [.atomic])
        cache[notebookID] = persisted
    }

    func deleteNotebook(_ notebookID: Int) async throws {
        let dir = booksDir.appendingPathComponent("\(notebookID)", isDirectory: true)
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
        cache.removeValue(forKey: "\(notebookID)")
    }

    private func dataForNotebookFile(notebookID: String) throws -> Data {
        let url = booksDir
            .appendingPathComponent(notebookID, isDirectory: true)
            .appendingPathComponent("notebook.json")
        return try Data(contentsOf: url)
    }

//    private func reloadCacheFromDisk() throws {
//        cache.removeAll()
//        let fm = FileManager.default
//        guard fm.fileExists(atPath: booksDir.path) else { return }
//        let items = try fm.contentsOfDirectory(at: booksDir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
//        for item in items {
//            guard (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
//            guard let id = UUID(uuidString: item.lastPathComponent) else { continue }
//            let file = item.appendingPathComponent("notebook.json")
//            guard let data = try? Data(contentsOf: file),
//                  let book = try? decoder.decode(Notebook.self, from: data) else { continue }
//            cache[id] = book
//        }
//    }

    /// 统一页序；若存在 `serverBookId`，同步到每页的 `notebookID`（`NotebookPage` 为 `Int`）。
    private static func normalizedNotebook(_ n: Notebook) -> Notebook {
        var copy = n
        let sid = n.serverBookId
        copy.pages = n.pages.enumerated().map { i, page in
            var p = page
            p.sortIndex = i
            if let sid {
                p.notebookID = sid
            }
            return p
        }
        return copy
    }
}
