import Foundation

struct CloudStorageInfo {
    let usedBytes: Int64
    let totalBytes: Int64
    let isICloudAvailable: Bool
    let lastSyncDate: Date?
}

/// 负责 iCloud / CloudKit 等云同步
protocol CloudSyncService {
    func enableSyncIfNeeded() async throws
    func syncNow(documentStore: DocumentStore) async throws
    func fetchStorageInfo() async -> CloudStorageInfo
}

final class StubCloudSyncService: CloudSyncService {
    private let lastSyncKey = "icloud.lastSyncDate"

    func enableSyncIfNeeded() async throws {
        // 触发一次可用性检查
        _ = FileManager.default.ubiquityIdentityToken
    }

    func syncNow(documentStore: DocumentStore) async throws {
        // 拉取本地草稿页并写入 iCloud 容器；若容器不可用则回落本地 App Support
        let draftNotebook = try await documentStore.fetchNotebook(id: nil)
        let notebooks = draftNotebook.map { [$0] } ?? []
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(notebooks)

        let fm = FileManager.default
        var targetURL: URL?
        if let containerURL = fm.url(forUbiquityContainerIdentifier: nil) {
            let docs = containerURL.appendingPathComponent("Documents", isDirectory: true)
            if !fm.fileExists(atPath: docs.path) {
                try fm.createDirectory(at: docs, withIntermediateDirectories: true)
            }
            targetURL = docs.appendingPathComponent("notebooks-sync.json")
        } else {
            let appSupport = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            if !fm.fileExists(atPath: appSupport.path) {
                try fm.createDirectory(at: appSupport, withIntermediateDirectories: true)
            }
            targetURL = appSupport.appendingPathComponent("notebooks-sync.json")
        }

        if let url = targetURL {
            try data.write(to: url, options: Data.WritingOptions.atomic)
            UserDefaults.standard.set(Date(), forKey: lastSyncKey)
        }
    }

    func fetchStorageInfo() async -> CloudStorageInfo {
        let fm = FileManager.default
        let rootURL = URL(fileURLWithPath: NSHomeDirectory())
        let values = try? rootURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
        let total = Int64(values?.volumeTotalCapacity ?? 0)
        let available = Int64(values?.volumeAvailableCapacityForImportantUsage ?? 0)
        let used = max(total - available, 0)
        let lastSync = UserDefaults.standard.object(forKey: lastSyncKey) as? Date

        return CloudStorageInfo(
            usedBytes: used,
            totalBytes: total,
            isICloudAvailable: fm.ubiquityIdentityToken != nil,
            lastSyncDate: lastSync
        )
    }
}

