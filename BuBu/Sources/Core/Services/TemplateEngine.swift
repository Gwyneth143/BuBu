import Foundation

/// 将照片 + 结构化文字自动排版到仿真页面中的引擎
protocol TemplateEngine {
    /// 根据用户选择的模版，将图片与检查单数据转换为 NotebookPage 列表
    func buildPages(from photoData: Data, checkup: CheckupRecord?, using template: NotebookPageTemplate) -> [NotebookPage]
}

struct NotebookPageTemplate: Identifiable, Hashable {
    let id: UUID
    var name: String
    /// 模版布局配置（例如："layout" : "photoTop_textBottom"）
    var config: [String: String]
}

/// 简单实现：生成一页照片 + 一页摘要文字
final class SimpleTemplateEngine: TemplateEngine {
    func buildPages(from photoData: Data, checkup: CheckupRecord?, using template: NotebookPageTemplate) -> [NotebookPage] {
        var pages: [NotebookPage] = []

        let photoPage = NotebookPage(
            id: UUID(),
            date: Date(),
            type: .photo(PhotoAsset(id: UUID(), sourceIdentifier: nil, url: nil))
        )
        pages.append(photoPage)

        if let checkup {
            let summary = checkup.metrics
                .map { "\($0.name)：\($0.value)\($0.unit ?? "")" }
                .joined(separator: "\n")
            let text = "检查：\(checkup.title)\n日期：\(checkup.date)\n\n\(summary)"
            let summaryPage = NotebookPage(
                id: UUID(),
                date: checkup.date,
                type: .note(text)
            )
            pages.append(summaryPage)
        }

        return pages
    }
}

