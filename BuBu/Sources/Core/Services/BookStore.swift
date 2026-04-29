import Foundation

/// 册子 REST API
protocol BookStore {
    /// `GET /books`，查询参数见 `BookQuery`
    func fetchBooks(query: BookQuery) async throws -> [Notebook]
    /// `POST /books`，成功返回本地 `Notebook`（含 `serverBookId`）
    func createBook(title: String, categoryName: String, skinId: Int) async throws -> Notebook
    /// `POST /books/delete`，请求体 `{ "bookId": Int }`
    func deleteBook(bookId: Int) async throws
}

struct BookQuery: Sendable {
    var page: Int
    /// 与 `limit` 二选一，优先 `pageSize`
    var pageSize: Int?
    var limit: Int?
    /// 不传表示全部分类
    var categoryName: String?

    init(page: Int = 1, pageSize: Int? = 20, limit: Int? = nil, categoryName: String? = nil) {
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
        self.categoryName = categoryName
    }
}

enum BookStoreError: LocalizedError {
    case missingAccessToken
    case invalidURL
    case invalidBookId
    case invalidSkinId
    case httpStatus(Int, String?)
    case decodeFailed
    case invalidBookResponse

    var errorDescription: String? {
        switch self {
        case .missingAccessToken:
            return "未登录或 token 缺失"
        case .invalidURL:
            return "册子接口地址无效"
        case .invalidBookId:
            return "无效的册子 ID"
        case .invalidSkinId:
            return "无效的皮肤 ID"
        case .httpStatus(let code, let body):
            return "册子请求失败 (\(code))\(body.map { ": \($0)" } ?? "")"
        case .decodeFailed:
            return "册子数据解析失败"
        case .invalidBookResponse:
            return "服务端返回的册子数据无效"
        }
    }
}

final class DefaultBookStore: BookStore {
    private let endpoint = "https://xsmb.world/books"
    private let deleteEndpoint = "https://xsmb.world/books/delete"
    private let tokenProvider: () -> String?

    init(tokenProvider: @escaping () -> String? = { nil }) {
        self.tokenProvider = tokenProvider
    }

    func fetchBooks(query: BookQuery) async throws -> [Notebook] {
        guard let token = tokenProvider(), !token.isEmpty else {
            throw BookStoreError.missingAccessToken
        }
        guard var components = URLComponents(string: endpoint) else {
            throw BookStoreError.invalidURL
        }
        var items: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(query.page))
        ]
        if let pageSize = query.pageSize {
            items.append(URLQueryItem(name: "pageSize", value: String(pageSize)))
        } else if let limit = query.limit {
            items.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let name = query.categoryName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            items.append(URLQueryItem(name: "categoryName", value: name))
        }
        components.queryItems = items

        guard let url = components.url else {
            throw BookStoreError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BookStoreError.httpStatus(-1, nil)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw BookStoreError.httpStatus(http.statusCode, String(data: data, encoding: .utf8))
        }

        struct ListEnvelope: Decodable {
            let books: [BookDTO]
            let total: Int?
            let page: Int?
            let pageSize: Int?
            let totalPages: Int?
        }

        let envelope: ListEnvelope
        do {
            envelope = try JSONDecoder().decode(ListEnvelope.self, from: data)
        } catch {
            throw BookStoreError.decodeFailed
        }

        let active = envelope.books.filter { $0.isDelete != true }
        return try active.map { try $0.toNotebook() }
    }

    func createBook(title: String, categoryName: String, skinId: Int) async throws -> Notebook {
        guard let token = tokenProvider(), !token.isEmpty else {
            throw BookStoreError.missingAccessToken
        }
        guard skinId > 0 else {
            throw BookStoreError.invalidSkinId
        }
        guard let url = URL(string: endpoint) else {
            throw BookStoreError.invalidURL
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCategory = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedCategory.isEmpty else {
            throw BookStoreError.invalidBookResponse
        }

        struct Body: Encodable {
            let title: String
            let category_name: String
            let skinId: Int
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            Body(title: trimmedTitle, category_name: trimmedCategory, skinId: skinId)
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BookStoreError.httpStatus(-1, nil)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw BookStoreError.httpStatus(http.statusCode, String(data: data, encoding: .utf8))
        }

        struct Envelope: Decodable {
            let book: BookDTO
        }

        let envelope: Envelope
        do {
            envelope = try JSONDecoder().decode(Envelope.self, from: data)
        } catch {
            throw BookStoreError.decodeFailed
        }

        return try envelope.book.toNotebook()
    }

    func deleteBook(bookId: Int) async throws {
        guard let token = tokenProvider(), !token.isEmpty else {
            throw BookStoreError.missingAccessToken
        }
        guard bookId > 0 else {
            throw BookStoreError.invalidBookId
        }
        guard let url = URL(string: deleteEndpoint) else {
            throw BookStoreError.invalidURL
        }

        struct Body: Encodable {
            let bookId: Int
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(Body(bookId: bookId))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BookStoreError.httpStatus(-1, nil)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw BookStoreError.httpStatus(http.statusCode, String(data: data, encoding: .utf8))
        }
    }
}

// MARK: - DTO

private struct BookDTO: Decodable {
    let id: Int
    let creatorUserId: Int?
    let title: String
    let categoryName: String
    let skinId: Int
    let coverUrl: String
    let coverThumbUrl: String
    let isDelete: Bool?
    let createdAt: String
    let updatedAt: String
    let deletedAt: String?

    func toNotebook() throws -> Notebook {
        guard id > 0, skinId > 0 else {
            throw BookStoreError.invalidBookResponse
        }
        let cover = NotebookCover(
            id: skinId,
            name: title,
            type: 0,
            price: "0.00",
            isMemberExclusive: false,
            imageUrl: coverUrl,
            thumbUrl: coverThumbUrl,
            creatorUserId: creatorUserId,
            createdAt: createdAt,
            isCollected: false
        )
        return Notebook(
            id: BookIdentity.uuid(forServerBookId: id),
            serverBookId: id,
            title: title,
            category: categoryName,
            createdAt: Self.parseDate(createdAt),
            updatedAt: Self.parseDate(updatedAt),
            cover: cover,
            pages: [],
            tags: []
        )
    }

    private static func parseDate(_ string: String) -> Date {
        let withFrac = ISO8601DateFormatter()
        withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFrac.date(from: string) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let d = plain.date(from: string) { return d }
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        if let d = df.date(from: string) { return d }
        return Date()
    }
}
