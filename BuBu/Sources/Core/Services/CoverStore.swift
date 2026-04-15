import Foundation

/// 册子封面皮肤仓库（免费 / 会员 + DIY）
protocol CoverStore {
    func fetchAllCovers() async throws -> [NotebookCover]
}

final class DefaultCoverStore: CoverStore {
    func fetchAllCovers() async throws -> [NotebookCover] {
        [
            NotebookCover(
                id: UUID(),
                name: "温柔粉（免费）",
                isPremium: false,
                configuration: ["color": "pink"]
            ),
            NotebookCover(
                id: UUID(),
                name: "星空蓝（会员）",
                isPremium: true,
                configuration: ["color": "blue"]
            )
        ]
    }
}

