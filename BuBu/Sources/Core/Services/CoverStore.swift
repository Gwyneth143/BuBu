import Foundation

/// 册子封面皮肤仓库（免费 / 会员 + DIY）
protocol CoverStore {
    func fetchAllCovers(query: CoverQuery) async throws -> [NotebookCover]
    func fetchSystemCovers(type: Int?) async throws -> [NotebookCover]
    func fetchMyCovers(query: CoverQuery) async throws -> [NotebookCover]
    
    /// 收藏皮肤到「我的」：`POST /my/skins`，body `{ "skinId": <id> }`
    func addSkinToMyCollection(skinId: Int) async throws
    /// DIY 封面上传：`POST /skins`，`multipart/form-data`（file、name、type、creatorUserId）
    func uploadSkinImage(
        fileData: Data,
        fileName: String,
        displayName: String,
        type: Int,
        creatorUserId: Int
    ) async throws
    /// 删除皮肤：`POST /skins/delete`，body `{ "skinId": <id> }`（对应 `skins.id`）
    func deleteSkin(skinId: Int) async throws
}

struct CoverQuery: Sendable {
    var type: Int?
    /// 页码，从 1 开始
    var page: Int
    /// 每页条数（1...100）
    var pageSize: Int?
    /// 与 pageSize 二选一，后端兼容字段
    var limit: Int?
    /// 筛选指定创建者的皮肤（`GET /skins` 查询参数）
    var creatorUserId: Int?

    init(type: Int? = nil, page: Int = 1, pageSize: Int? = 20, limit: Int? = nil, creatorUserId: Int? = nil) {
        self.type = type
        self.page = max(1, page)
        if let size = pageSize {
            self.pageSize = min(max(size, 1), 100)
        } else {
            self.pageSize = nil
        }
        if let l = limit {
            self.limit = min(max(l, 1), 100)
        } else {
            self.limit = nil
        }
        self.creatorUserId = creatorUserId
    }
}

extension CoverStore {
    func fetchAllCovers() async throws -> [NotebookCover] {
        try await fetchAllCovers(query: CoverQuery(type: 1))
    }
}

enum CoverStoreError: LocalizedError {
    case invalidURL
    case missingAccessToken
    case missingServerUserId
    case invalidSkinId
    case httpStatus(Int, String?)
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "皮肤接口地址无效"
        case .missingAccessToken:
            return "未登录或 token 缺失"
        case .missingServerUserId:
            return "缺少用户 ID，请重新登录"
        case .invalidSkinId:
            return "无效的皮肤 ID"
        case .httpStatus(let code, let body):
            return "皮肤请求失败 (\(code))\(body.map { ": \($0)" } ?? "")"
        case .decodeFailed:
            return "皮肤数据解析失败"
        }
    }
}

final class DefaultCoverStore: CoverStore {
    private let endpoint = "https://xsmb.world/skins"
    private let deleteEndpoint = "https://xsmb.world/skins/delete"
    private let systemEndpoint = "https://xsmb.world/skins/system"
    private let myEndpoint = "https://xsmb.world/my/skins"
    private let tokenProvider: () -> String?

    init(tokenProvider: @escaping () -> String? = { nil }) {
        self.tokenProvider = tokenProvider
    }

    func fetchAllCovers(query: CoverQuery) async throws -> [NotebookCover] {
//        guard let token = tokenProvider(), !token.isEmpty else {
//            throw CoverStoreError.missingAccessToken
//        }
        let token = tokenProvider()
        guard var components = URLComponents(string: endpoint) else {
            throw CoverStoreError.invalidURL
        }
        var items: [URLQueryItem] = []
        if let type = query.type {
            items.append(URLQueryItem(name: "type", value: String(type)))
        }
        if let creatorUserId = query.creatorUserId {
            items.append(URLQueryItem(name: "creatorUserId", value: String(creatorUserId)))
        }
        items.append(URLQueryItem(name: "page", value: String(max(1, query.page))))
        if let pageSize = query.pageSize {
            items.append(URLQueryItem(name: "pageSize", value: String(pageSize)))
        }
        if let limit = query.limit {
            items.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        components.queryItems = items.isEmpty ? nil : items

        guard let url = components.url else {
            throw CoverStoreError.invalidURL
        }

        struct SkinListResponseDTO: Decodable {
            let skins: [NotebookCover]
            let total: Int?
            let page: Int?
            let pageSize: Int?
            let totalPages: Int?
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let t = token,!t.isEmpty {
            request.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CoverStoreError.httpStatus(-1, nil)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw CoverStoreError.httpStatus(http.statusCode, String(data: data, encoding: .utf8))
        }

        let decoded: SkinListResponseDTO
        do {
            decoded = try JSONDecoder().decode(SkinListResponseDTO.self, from: data)
        } catch {
            throw CoverStoreError.decodeFailed
        }

        return decoded.skins
    }

    func fetchSystemCovers(type: Int? = nil) async throws -> [NotebookCover] {
        guard var components = URLComponents(string: systemEndpoint) else {
            throw CoverStoreError.invalidURL
        }
        if let type {
            components.queryItems = [URLQueryItem(name: "type", value: String(type))]
        }
        guard let url = components.url else {
            throw CoverStoreError.invalidURL
        }

        struct SkinListResponseDTO: Decodable {
            let skins: [NotebookCover]
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CoverStoreError.httpStatus(-1, nil)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw CoverStoreError.httpStatus(http.statusCode, String(data: data, encoding: .utf8))
        }

        do {
            return try JSONDecoder().decode(SkinListResponseDTO.self, from: data).skins
        } catch {
            throw CoverStoreError.decodeFailed
        }
    }

    func fetchMyCovers(query: CoverQuery) async throws -> [NotebookCover] {
        guard let token = tokenProvider(), !token.isEmpty else {
            throw CoverStoreError.missingAccessToken
        }
        guard var components = URLComponents(string: myEndpoint) else {
            throw CoverStoreError.invalidURL
        }
        var items: [URLQueryItem] = [URLQueryItem(name: "page", value: String(max(1, query.page)))]
        if let type = query.type {
            items.append(URLQueryItem(name: "type", value: String(type)))
        }
        if let pageSize = query.pageSize {
            items.append(URLQueryItem(name: "pageSize", value: String(pageSize)))
        }
        if let limit = query.limit {
            items.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        components.queryItems = items
        guard let url = components.url else {
            throw CoverStoreError.invalidURL
        }

        struct MySkinDTO: Decodable {
            let userSkinId: Int
            let addedAt: String
            let id: Int
            let name: String
            let type: Int
            let price: String
            let isMemberExclusive: Bool
            let imageUrl: String
            let thumbUrl: String
            let creatorUserId: Int?
            let createdAt: String
            let isCollected: Bool?
        }
        struct MySkinListResponseDTO: Decodable {
            let skins: [MySkinDTO]
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CoverStoreError.httpStatus(-1, nil)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw CoverStoreError.httpStatus(http.statusCode, String(data: data, encoding: .utf8))
        }

        let decoded: MySkinListResponseDTO
        do {
            decoded = try JSONDecoder().decode(MySkinListResponseDTO.self, from: data)
        } catch {
            throw CoverStoreError.decodeFailed
        }

        return decoded.skins.map { item in
            NotebookCover(
                id: item.id,
                name: item.name,
                type: item.type,
                price: item.price,
                isMemberExclusive: item.isMemberExclusive,
                imageUrl: item.imageUrl,
                thumbUrl: item.thumbUrl,
                creatorUserId: item.creatorUserId,
                createdAt: item.createdAt,
                isCollected: item.isCollected ?? true
            )
        }
    }

    func addSkinToMyCollection(skinId: Int) async throws {
        guard let token = tokenProvider(), !token.isEmpty else {
            throw CoverStoreError.missingAccessToken
        }
        guard let url = URL(string: myEndpoint) else {
            throw CoverStoreError.invalidURL
        }
        struct Body: Encodable { let skinId: Int }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(Body(skinId: skinId))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CoverStoreError.httpStatus(-1, nil)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw CoverStoreError.httpStatus(http.statusCode, String(data: data, encoding: .utf8))
        }
    }

    func uploadSkinImage(
        fileData: Data,
        fileName: String,
        displayName: String,
        type: Int,
        creatorUserId: Int
    ) async throws {
        guard let token = tokenProvider(), !token.isEmpty else {
            throw CoverStoreError.missingAccessToken
        }
        guard creatorUserId > 0 else {
            throw CoverStoreError.missingServerUserId
        }
        guard let url = URL(string: endpoint) else {
            throw CoverStoreError.invalidURL
        }

        let boundary = "Boundary-\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        var body = Data()

        func appendField(_ name: String, _ value: String) {
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8))
            body.append(Data(value.utf8))
            body.append(Data("\r\n".utf8))
        }

        let safeName = displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "DIY Cover"
            : displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeFileName = fileName.replacingOccurrences(of: "\"", with: "_")

        appendField("name", safeName)
        appendField("type", String(type))
        appendField("creatorUserId", String(creatorUserId))

        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(safeFileName)\"\r\n".utf8))
        body.append(Data("Content-Type: image/png\r\n\r\n".utf8))
        body.append(fileData)
        body.append(Data("\r\n".utf8))
        body.append(Data("--\(boundary)--\r\n".utf8))

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CoverStoreError.httpStatus(-1, nil)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw CoverStoreError.httpStatus(http.statusCode, String(data: data, encoding: .utf8))
        }
    }

    func deleteSkin(skinId: Int) async throws {
        guard let token = tokenProvider(), !token.isEmpty else {
            throw CoverStoreError.missingAccessToken
        }
        guard skinId > 0 else {
            throw CoverStoreError.invalidSkinId
        }
        guard let url = URL(string: deleteEndpoint) else {
            throw CoverStoreError.invalidURL
        }
        struct Body: Encodable { let skinId: Int }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(Body(skinId: skinId))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CoverStoreError.httpStatus(-1, nil)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw CoverStoreError.httpStatus(http.statusCode, String(data: data, encoding: .utf8))
        }
    }
}

