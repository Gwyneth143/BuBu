import Foundation

struct PhotoAsset: Identifiable, Hashable {
    let id: UUID
    /// 原始系统资源标识（例如 PHAsset.localIdentifier），先用 String 占位
    var sourceIdentifier: String?
    var url: URL?
}

struct NotebookCover: Identifiable, Hashable {
    let id: UUID
    var name: String
    /// 是否为会员专属
    var isPremium: Bool
    /// 封面配置（颜色、纹理、贴纸布局等），简化为字典占位
    var configuration: [String: String]
}

