import Foundation

protocol CategoryStore {
    /// 当前已存在的分类列表（供 UI 直接读取）
    var categories: [String] { get }
    /// 异步拉取所有分类（例如未来从磁盘 / CloudKit 读取）
    func fetchAllCategory() async throws -> [String]
    /// 新增一个分类（走后端接口），成功后更新内部列表
    func addCategory(name: String) async throws
}

enum CategoryStoreError: LocalizedError {
    case emptyName
    case missingAccessToken
    case invalidURL
    case httpStatus(Int, String?)
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .emptyName: return "分类名称不能为空"
        case .missingAccessToken: return "未登录或 token 缺失"
        case .invalidURL: return "分类接口地址无效"
        case .httpStatus(let code, let body):
            return "分类请求失败 (\(code))\(body.map { ": \($0)" } ?? "")"
        case .decodeFailed:
            return "分类数据解析失败"
        }
    }
}

/// 管理用户已创建的分类列表，支持新增
final class InMemoryCategoryStore: CategoryStore {
    private(set) var categories: [String] = []
    private let tokenProvider: () -> String?
    private let endpoint = "https://xsmb.world/categories"

    init(tokenProvider: @escaping () -> String? = { nil }) {
        self.tokenProvider = tokenProvider
    }
    
    func fetchAllCategory() async throws -> [String] {
        guard let token = tokenProvider(), !token.isEmpty else {
            throw CategoryStoreError.missingAccessToken
        }
        guard let url = URL(string: endpoint) else {
            throw CategoryStoreError.invalidURL
        }

        struct CategoryItemDTO: Decodable {
            let id: Int?
            let name: String
            let creatorUserId: Int?
            let createdAt: String?
            let updatedAt: String?
        }
        struct CategoryListResponseDTO: Decodable {
            let categories: [CategoryItemDTO]
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CategoryStoreError.httpStatus(-1, nil)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw CategoryStoreError.httpStatus(http.statusCode, String(data: data, encoding: .utf8))
        }

        let decoded: CategoryListResponseDTO
        do {
            decoded = try JSONDecoder().decode(CategoryListResponseDTO.self, from: data)
        } catch {
            throw CategoryStoreError.decodeFailed
        }

        // 去空格、去空值、大小写去重，保持后端返回顺序
        var merged: [String] = []
        for item in decoded.categories {
            let trimmed = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if !merged.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                merged.append(trimmed)
            }
        }

        categories = merged
        return categories
    }

    func addCategory(name: String) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CategoryStoreError.emptyName }
        guard !categories.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }

        guard let token = tokenProvider(), !token.isEmpty else {
            throw CategoryStoreError.missingAccessToken
        }
        guard let url = URL(string: endpoint) else {
            throw CategoryStoreError.invalidURL
        }

        struct Body: Encodable {
            let name: String
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(Body(name: trimmed))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CategoryStoreError.httpStatus(-1, nil)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw CategoryStoreError.httpStatus(http.statusCode, String(data: data, encoding: .utf8))
        }

        categories.append(trimmed)
    }
}
