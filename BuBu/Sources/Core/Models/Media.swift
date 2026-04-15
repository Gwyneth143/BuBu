import Foundation

struct PhotoAsset: Identifiable, Hashable, Codable {
    let id: UUID
    /// 原始系统资源标识（例如 PHAsset.localIdentifier），先用 String 占位
    var sourceIdentifier: String?
    var url: URL?
}

struct NotebookCover: Identifiable, Hashable, Codable {
    let id: Int
    var name: String
    var type: Int
    var price: String
    var isMemberExclusive: Bool
    var imageUrl: String
    var thumbUrl: String
    var creatorUserId: Int?
    var createdAt: String
    /// 服务端是否已收藏（`/skins` 等列表接口会返回）
    var isCollected: Bool

    // 兼容现有 UI 调用
    var isPremium: Bool { isMemberExclusive }
    var image: String { thumbUrl.isEmpty ? imageUrl : thumbUrl }

    enum CodingKeys: String, CodingKey {
        case id, name, type, price, isMemberExclusive, imageUrl, thumbUrl, creatorUserId, createdAt, isCollected
    }

    init(
        id: Int,
        name: String,
        type: Int,
        price: String,
        isMemberExclusive: Bool,
        imageUrl: String,
        thumbUrl: String,
        creatorUserId: Int?,
        createdAt: String,
        isCollected: Bool = false
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.price = price
        self.isMemberExclusive = isMemberExclusive
        self.imageUrl = imageUrl
        self.thumbUrl = thumbUrl
        self.creatorUserId = creatorUserId
        self.createdAt = createdAt
        self.isCollected = isCollected
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        type = try c.decode(Int.self, forKey: .type)
        price = try c.decode(String.self, forKey: .price)
        isMemberExclusive = try c.decode(Bool.self, forKey: .isMemberExclusive)
        imageUrl = try c.decode(String.self, forKey: .imageUrl)
        thumbUrl = try c.decode(String.self, forKey: .thumbUrl)
        creatorUserId = try c.decodeIfPresent(Int.self, forKey: .creatorUserId)
        createdAt = try c.decode(String.self, forKey: .createdAt)
        isCollected = try c.decodeIfPresent(Bool.self, forKey: .isCollected) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(type, forKey: .type)
        try c.encode(price, forKey: .price)
        try c.encode(isMemberExclusive, forKey: .isMemberExclusive)
        try c.encode(imageUrl, forKey: .imageUrl)
        try c.encode(thumbUrl, forKey: .thumbUrl)
        try c.encodeIfPresent(creatorUserId, forKey: .creatorUserId)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(isCollected, forKey: .isCollected)
    }

    /// 本地预置封面快速构建（兼容第一版离线素材）
    init(localID: Int, name: String, assetName: String, isMemberExclusive: Bool = false) {
        self.id = localID
        self.name = name
        self.type = 0
        self.price = "0.00"
        self.isMemberExclusive = isMemberExclusive
        self.imageUrl = assetName
        self.thumbUrl = assetName
        self.creatorUserId = nil
        self.createdAt = ISO8601DateFormatter().string(from: Date())
        self.isCollected = false
    }
}

