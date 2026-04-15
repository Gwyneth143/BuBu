import Foundation

/// 册子（一本书）
struct Notebook: Identifiable, Hashable, Codable {
    let id: UUID
    /// 服务端 `books.id`（本地创建后由接口回填）
    var serverBookId: Int?
    var title: String
    var category: String
    var createdAt: Date
    var updatedAt: Date
    var cover: NotebookCover
    var pages: [NotebookPage]
    var tags: [String]

    init(
        id: UUID = UUID(),
        serverBookId: Int? = nil,
        title: String,
        category: String,
        createdAt: Date,
        updatedAt: Date,
        cover: NotebookCover,
        pages: [NotebookPage],
        tags: [String]
    ) {
        self.id = id
        self.serverBookId = serverBookId
        self.title = title
        self.category = category
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.cover = cover
        self.pages = pages
        self.tags = tags
    }
}

//enum NotebookCategory: String, Hashable {
//    case travel
//    case family
//    case personal
//    case other
//}

/// 册子页面（可以是照片页或检查单页等）
//struct NotebookPage: Identifiable, Hashable {
//    enum PageType: Hashable {
//        case photo(PhotoAsset)
//        case checkup(CheckupRecord)
//        case note(String)
//    }
//
//    let id: UUID
//    var date: Date
//    var type: PageType
//}

/// 册子页面（可以是照片页或检查单页等）
struct NotebookPage: Identifiable, Hashable, Codable {
    let id: UUID
    var notebookID: Int
    /// 创建时间
    var createdAt: Date
    /// 最后修改时间（合并、增量同步用；新建页可与 `createdAt` 相同）
    var updatedAt: Date
    /// 在所属册子中的顺序，从 0 递增；持久化时与数组顺序对齐
    var sortIndex: Int
    /// 当前页包含的图片组
    var images: [PhotoAsset]
    /// 文本备注
    var note: String
    /// 标签（当册子过多时，用户用于快速定位）
    var tag: String

    enum CodingKeys: String, CodingKey {
        case id, notebookID, createdAt, updatedAt, sortIndex, images, note, tag
    }

    init(
        id: UUID,
        notebookID: Int,
        createdAt: Date,
        updatedAt: Date? = nil,
        sortIndex: Int = 0,
        images: [PhotoAsset],
        note: String,
        tag: String
    ) {
        self.id = id
        self.notebookID = notebookID
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.sortIndex = sortIndex
        self.images = images
        self.note = note
        self.tag = tag
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        notebookID = try c.decode(Int.self, forKey: .notebookID)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        sortIndex = try c.decodeIfPresent(Int.self, forKey: .sortIndex) ?? 0
        images = try c.decode([PhotoAsset].self, forKey: .images)
        note = try c.decode(String.self, forKey: .note)
        tag = try c.decode(String.self, forKey: .tag)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(notebookID, forKey: .notebookID)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(sortIndex, forKey: .sortIndex)
        try c.encode(images, forKey: .images)
        try c.encode(note, forKey: .note)
        try c.encode(tag, forKey: .tag)
    }
}

struct NotebookTag: Identifiable, Hashable, Codable {
    var id:  UUID
    var notebookID: UUID
    var tags: [String]
}
