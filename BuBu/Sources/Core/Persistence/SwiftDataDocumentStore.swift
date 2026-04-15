import Foundation

#if canImport(SwiftData)
import SwiftData

@Model
final class NotebookEntity {
    @Attribute(.unique) var id: UUID
    /// 与 `Notebook.serverBookId` 一致（服务端 `books.id`）
    var serverBookId: Int?
    var title: String
    var category: String
    var createdAt: Date
    var updatedAt: Date
    var tags: [String]
    var cover: NotebookCover
    /// 本地每次成功保存递增，供云端合并与乐观锁
    var localRevision: Int64
    /// 服务端返回的版本号或 etag，首次上传前为 nil
    var serverRevision: String?
    /// 与 `SyncRecordState` 对应；接入同步后由同步层更新
    var syncStateValue: Int16
    @Relationship(deleteRule: .cascade, inverse: \NotebookPageEntity.notebook)
    var pages: [NotebookPageEntity] = []

    init(
        id: UUID,
        serverBookId: Int? = nil,
        title: String,
        category: String,
        createdAt: Date,
        updatedAt: Date,
        tags: [String],
        cover: NotebookCover,
        localRevision: Int64 = 0,
        serverRevision: String? = nil,
        syncStateValue: Int16 = SyncRecordState.idle.rawValue
    ) {
        self.id = id
        self.serverBookId = serverBookId
        self.title = title
        self.category = category
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tags = tags
        self.cover = cover
        self.localRevision = localRevision
        self.serverRevision = serverRevision
        self.syncStateValue = syncStateValue
    }
}

@Model
final class NotebookPageEntity {
    @Attribute(.unique) var id: UUID
    /// 与 `NotebookPage.notebookID` 一致（通常为服务端册子 id）
    var notebookID: Int = 0
    var createdAt: Date
    var updatedAt: Date
    var sortIndex: Int
    var note: String
    var tag: String
    /// 持久化 PhotoAsset 数组的 JSON 编码
    var imagesData: Data?
    @Relationship var notebook: NotebookEntity?

    init(
        id: UUID,
        notebookID: Int,
        createdAt: Date,
        updatedAt: Date,
        sortIndex: Int,
        note: String,
        tag: String,
        imagesData: Data?
    ) {
        self.id = id
        self.notebookID = notebookID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sortIndex = sortIndex
        self.note = note
        self.tag = tag
        self.imagesData = imagesData
    }
}

/// 使用 SwiftData 作为后台存储的 DocumentStore 实现
@available(iOS 17.0, *)
final class SwiftDataDocumentStore: DocumentStore {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init(container: ModelContainer? = nil) {
        if let container {
            self.container = container
        } else {
            // 避免 schema 变更时 `try!` 直接崩溃：首次失败后清理本地库并重建
            self.container = Self.buildResilientContainer()
        }
    }

    private static func buildResilientContainer() -> ModelContainer {
        do {
            return try makeContainer()
        } catch {
            // 兼容第一版到后续版本的模型调整：清理旧库后再尝试一次
            cleanupPersistentStoreFiles()
            do {
                return try makeContainer()
            } catch {
                // 最后兜底为内存容器，避免启动崩溃
                let inMemory = ModelConfiguration(isStoredInMemoryOnly: true)
                return try! ModelContainer(
                    for: NotebookEntity.self,
                    NotebookPageEntity.self,
                    configurations: inMemory
                )
            }
        }
    }

    private static func makeContainer() throws -> ModelContainer {
        let url = persistentStoreURL()
        let configuration = ModelConfiguration(url: url)
        return try ModelContainer(
            for: NotebookEntity.self,
            NotebookPageEntity.self,
            configurations: configuration
        )
    }

    private static func persistentStoreURL() -> URL {
        let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return dir.appendingPathComponent("BuBu-Notebook.store")
    }

    private static func cleanupPersistentStoreFiles() {
        let fm = FileManager.default
        let base = persistentStoreURL()
        let candidates = [
            base,
            URL(fileURLWithPath: base.path + "-wal"),
            URL(fileURLWithPath: base.path + "-shm")
        ]
        for url in candidates where fm.fileExists(atPath: url.path) {
            try? fm.removeItem(at: url)
        }
    }

    // MARK: - DocumentStore

    func fetchNotebook(id: UUID) async throws -> Notebook? {
        try await MainActor.run {
            guard let entity = try fetchEntity(for: id) else { return nil }
            return entity.toNotebook()
        }
    }

    func listNotebookIDs() async throws -> [UUID] {
        try await MainActor.run {
            let descriptor = FetchDescriptor<NotebookEntity>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            let entities = try context.fetch(descriptor)
            return entities.map(\.id)
        }
    }

    func fetchPages(for notebookID: UUID) async throws -> [NotebookPage] {
        try await MainActor.run {
            guard let entity = try fetchEntity(for: notebookID) else { return [] }
            let ordered = entity.pages.sorted { $0.sortIndex < $1.sortIndex }
            return ordered.map { $0.toNotebookPage() }
        }
    }

    func saveNotebook(_ notebook: Notebook) async throws {
        let persisted = Self.normalizedForPersistence(notebook)
        try await MainActor.run {
            if let existing = try fetchEntity(for: persisted.id) {
                existing.serverBookId = persisted.serverBookId
                existing.title = persisted.title
                existing.category = persisted.category
                existing.createdAt = persisted.createdAt
                existing.updatedAt = persisted.updatedAt
                existing.tags = persisted.tags
                existing.cover = persisted.cover
                existing.localRevision += 1
                existing.pages.removeAll()
                let pageEntities = persisted.pages.map { NotebookPageEntity(from: $0) }
                for page in pageEntities {
                    page.notebook = existing
                }
                existing.pages = pageEntities
            } else {
                let entity = NotebookEntity(
                    id: persisted.id,
                    serverBookId: persisted.serverBookId,
                    title: persisted.title,
                    category: persisted.category,
                    createdAt: persisted.createdAt,
                    updatedAt: persisted.updatedAt,
                    tags: persisted.tags,
                    cover: persisted.cover,
                    localRevision: 1,
                    serverRevision: nil,
                    syncStateValue: SyncRecordState.idle.rawValue
                )
                let pageEntities = persisted.pages.map { NotebookPageEntity(from: $0) }
                for page in pageEntities {
                    page.notebook = entity
                }
                entity.pages = pageEntities
                context.insert(entity)
            }

            try context.save()
        }
    }

    func deleteNotebook(_ notebookID: UUID) async throws {
        try await MainActor.run {
            guard let entity = try fetchEntity(for: notebookID) else { return }
            context.delete(entity)
            try context.save()
        }
    }

    var storageCapabilities: DocumentStorageCapabilities {
        DocumentStorageCapabilities(supportsSyncMetadata: true, supportsSoftDelete: false)
    }

    func fetchNotebookIDsPendingSync() async throws -> [UUID] {
        try await MainActor.run {
            // 与 `SyncRecordState.pendingUpload`（rawValue == 1）一致； Predicate 内仅宜用字面量
            let descriptor = FetchDescriptor<NotebookEntity>(
                predicate: #Predicate<NotebookEntity> { $0.syncStateValue == 1 }
            )
            let entities = try context.fetch(descriptor)
            return entities.map(\.id)
        }
    }

    // MARK: - Helpers

    /// 写入前统一页顺序与 `sortIndex`，避免云端/关系库无序
    private static func normalizedForPersistence(_ notebook: Notebook) -> Notebook {
        var n = notebook
        let sid = n.serverBookId
        n.pages = notebook.pages.enumerated().map { offset, page in
            var p = page
            p.sortIndex = offset
            if let sid {
                p.notebookID = sid
            }
            return p
        }
        return n
    }

    private func fetchEntity(for id: UUID) throws -> NotebookEntity? {
        // 某些 SwiftData 版本的 FetchDescriptor 不支持在初始化时直接传 fetchLimit
        let descriptor = FetchDescriptor<NotebookEntity>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }
}

// MARK: - Mapping

private extension NotebookEntity {
    func toNotebook() -> Notebook {
        let category = category
        let ordered = pages.sorted { $0.sortIndex < $1.sortIndex }
        let pagesModels = ordered.map { $0.toNotebookPage() }
        // 直接使用 SwiftData 中持久化的封面信息
        let coverModel = cover
        return Notebook(
            id: id,
            serverBookId: serverBookId,
            title: title,
            category: category,
            createdAt: createdAt,
            updatedAt: updatedAt,
            cover: coverModel,
            pages: pagesModels,
            tags: tags
        )
    }
}

private extension NotebookPageEntity {
    convenience init(from page: NotebookPage) {
        let data = try? JSONEncoder().encode(page.images)
        self.init(
            id: page.id,
            notebookID: page.notebookID,
            createdAt: page.createdAt,
            updatedAt: page.updatedAt,
            sortIndex: page.sortIndex,
            note: page.note,
            tag: page.tag,
            imagesData: data
        )
    }

    func toNotebookPage() -> NotebookPage {
        let images: [PhotoAsset]
        if let data = imagesData, let decoded = try? JSONDecoder().decode([PhotoAsset].self, from: data) {
            images = decoded
        } else {
            images = []
        }

        return NotebookPage(
            id: id,
            notebookID: notebookID,
            createdAt: createdAt,
            updatedAt: updatedAt,
            sortIndex: sortIndex,
            images: images,
            note: note,
            tag: tag
        )
    }
}

#endif

