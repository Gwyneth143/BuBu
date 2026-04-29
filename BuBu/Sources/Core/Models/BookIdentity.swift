import CryptoKit
import Foundation

/// 与 `serverBookId` 一一对应的稳定本地 `Notebook.id`（与后端列表刷新无关）。
enum BookIdentity {
    static func uuid(forServerBookId serverId: Int) -> UUID {
        let input = Data("buub.book.\(serverId)".utf8)
        let digest = SHA256.hash(data: input)
        let b = Array(digest.prefix(16))
        return UUID(uuid: (
            b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
            b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]
        ))
    }
}
