import Foundation

/// 册子（一本书）
struct Notebook: Identifiable, Hashable {
    let id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var cover: NotebookCover
    var pages: [NotebookPage]
}

/// 册子页面（可以是照片页或检查单页等）
struct NotebookPage: Identifiable, Hashable {
    enum PageType: Hashable {
        case photo(PhotoAsset)
        case checkup(CheckupRecord)
        case note(String)
    }

    let id: UUID
    var date: Date
    var type: PageType
}

