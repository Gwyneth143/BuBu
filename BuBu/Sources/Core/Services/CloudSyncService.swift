import Foundation
#if canImport(CloudKit)
import CloudKit
#endif

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
    /// 从 iCloud 拉取册子数据并写回本地存储
    func restoreFromCloud(documentStore: DocumentStore) async throws
    /// 清空云端备份数据（CloudKit + iCloud Documents）
    func clearCloudData() async throws
    func fetchStorageInfo() async -> CloudStorageInfo
}

private enum CloudSyncError: LocalizedError {
    case cloudBackupUnavailable
    case cloudKitAccountUnavailable(String)
    case cloudKitWriteFailed(String)

    var errorDescription: String? {
        switch self {
        case .cloudBackupUnavailable:
            return "iCloud 备份不可用（CloudKit 与 iCloud 容器均不可写）"
        case .cloudKitAccountUnavailable(let reason):
            return "CloudKit 账号不可用：\(reason)"
        case .cloudKitWriteFailed(let reason):
            return "CloudKit 写入失败：\(reason)"
        }
    }
}

// MARK: - CloudKit 备份 v2：仅册子 pages；扫描图在 Documents/scans，需单独 CKAsset 记录

private struct CloudPagesBackupManifest: Codable {
    var version: Int = 2
    var entries: [CloudPagesBackupEntry]
}

private struct CloudPagesBackupEntry: Codable {
    var serverBookId: Int?
    var notebookId: UUID
    var pages: [NotebookPageBackup]
}

private struct NotebookPageBackup: Codable {
    var id: UUID
    var notebookID: Int
    var createdAt: Date
    var updatedAt: Date
    var sortIndex: Int
    var images: [PhotoAssetBackup]
    var note: String
    var tag: String
}

private struct PhotoAssetBackup: Codable {
    var id: UUID
    var sourceIdentifier: String?
}

final class StubCloudSyncService: CloudSyncService {
    private let lastSyncKey = "icloud.lastSyncDate"
    private let syncFileName = "notebooks-sync.json"
#if canImport(CloudKit)
    private let backupRecordType = "NotebookBackup"
    private let backupRecordName = "global-backup"
    private let imageRecordType = "NotebookBackupImage"
    /// 与 BuBu.entitlements 中 `com.apple.developer.icloud-container-identifiers` 一致；勿用 `default()` 以免与配置不一致。
    private let cloudKitContainerID = "iCloud.gwyneth.com.BuBu"
    /// CloudKit 单字段非 Asset 上限约 1MB；小于此值直接写入 record，避免 CKAsset 异步上传与临时文件被提前删除的问题。
    private let maxInlinePayloadBytes = 900_000
    private let ckAssetLocalFileName = "cloudkit-notebook-sync-payload.bin"
#endif

    func enableSyncIfNeeded() async throws {
        // 触发一次可用性检查
        _ = FileManager.default.ubiquityIdentityToken
    }

    func syncNow(documentStore: DocumentStore) async throws {
        let notebooks = (try? await documentStore.fetchAllNotebooks()) ?? []
        // 仅同步「有页」的册子；纯后端列表册子无本地 pages 不会进入备份
        let withPages = notebooks.filter { !$0.pages.isEmpty }
        if withPages.isEmpty {
            // 本地暂无可上传 pages 时仅尝试恢复；不将恢复失败上抛为“同步失败”
            try? await restoreFromCloud(documentStore: documentStore)
            return
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let manifest = Self.buildManifest(from: withPages)
        guard let manifestData = try? encoder.encode(manifest) else { return }
        let fm = FileManager.default

#if canImport(CloudKit)
        var cloudKitWriteError: Error?
        do {
            if try await uploadManifestV2ToCloudKit(manifestData: manifestData, notebooks: withPages) {
                // CloudKit 某些环境可能仅成功写入 manifest，图片记录被服务端拒绝（如 CKError 15）。
                // 额外写一份 iCloud Documents（含 scans）作为图片恢复兜底，避免卸载重装后图片丢失。
                if let containerURL = fm.url(forUbiquityContainerIdentifier: nil) {
                    let docs = containerURL.appendingPathComponent("Documents", isDirectory: true)
                    if !fm.fileExists(atPath: docs.path) {
                        try? fm.createDirectory(at: docs, withIntermediateDirectories: true)
                    }
                    try? syncScanImagesToUbiquityDocuments(notebooks: withPages, documentsURL: docs)
                    let url = docs.appendingPathComponent(syncFileName)
                    try? manifestData.write(to: url, options: .atomic)
                }
                UserDefaults.standard.set(Date(), forKey: lastSyncKey)
                return
            }
        } catch {
            cloudKitWriteError = error
        }
#endif
        if let containerURL = fm.url(forUbiquityContainerIdentifier: nil) {
            let docs = containerURL.appendingPathComponent("Documents", isDirectory: true)
            if !fm.fileExists(atPath: docs.path) {
                try fm.createDirectory(at: docs, withIntermediateDirectories: true)
            }
            try? syncScanImagesToUbiquityDocuments(notebooks: withPages, documentsURL: docs)
            let url = docs.appendingPathComponent(syncFileName)
            try manifestData.write(to: url, options: Data.WritingOptions.atomic)
            UserDefaults.standard.set(Date(), forKey: lastSyncKey)
            return
        }

        // 保留本地兜底副本，便于调试，但不计入“已同步”。
        if let url = try? preferredSyncFileURL() {
            try? manifestData.write(to: url, options: Data.WritingOptions.atomic)
        }
#if canImport(CloudKit)
        if let cloudKitWriteError {
            throw cloudKitWriteError
        }
#endif
        throw CloudSyncError.cloudBackupUnavailable
    }

    func restoreFromCloud(documentStore: DocumentStore) async throws {
#if canImport(CloudKit)
        do {
            if try await restoreManifestV2FromCloudKit(documentStore: documentStore) {
                return
            }
            if try await restoreLegacyNotebooksFromCloudKit(documentStore: documentStore) {
                return
            }
        } catch {
            // fall through to file-based restore
        }
#endif
        let fm = FileManager.default
        let sourceURLs = (try? candidateSyncFileURLs()) ?? []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let maxAttempts = 6
        for attempt in 1...maxAttempts {
            for sourceURL in sourceURLs where fm.fileExists(atPath: sourceURL.path) {
                if fm.isUbiquitousItem(at: sourceURL) {
                    try? fm.startDownloadingUbiquitousItem(at: sourceURL)
                }
                guard let data = try? Data(contentsOf: sourceURL) else { continue }
                if let manifest = try? decoder.decode(CloudPagesBackupManifest.self, from: data),
                   manifest.version == 2,
                   !manifest.entries.isEmpty {
                    let map = resolveImageURLsFromFileBackup(manifest: manifest)
                    try? await applyManifestV2(manifest, imageURLMap: map, documentStore: documentStore)
                    UserDefaults.standard.set(Date(), forKey: lastSyncKey)
                    notifyCloudRestoreCompleted()
                    return
                }
                if let notebooks = try? decoder.decode([Notebook].self, from: data), !notebooks.isEmpty {
                    for notebook in notebooks {
                        try? await documentStore.saveNotebook(notebook)
                    }
                    UserDefaults.standard.set(Date(), forKey: lastSyncKey)
                    notifyCloudRestoreCompleted()
                    return
                }
            }
            if attempt < maxAttempts {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
            }
        }
    }

    func clearCloudData() async throws {
        let fm = FileManager.default
#if canImport(CloudKit)
        try? await clearCloudKitBackup()
#endif
        if let containerURL = fm.url(forUbiquityContainerIdentifier: nil) {
            let docs = containerURL.appendingPathComponent("Documents", isDirectory: true)
            let syncURL = docs.appendingPathComponent(syncFileName)
            if fm.fileExists(atPath: syncURL.path) {
                try? fm.removeItem(at: syncURL)
            }
            let scansDir = docs.appendingPathComponent("scans", isDirectory: true)
            if fm.fileExists(atPath: scansDir.path) {
                try? fm.removeItem(at: scansDir)
            }
        }
        UserDefaults.standard.removeObject(forKey: lastSyncKey)
    }

#if canImport(CloudKit)
    private func clearCloudKitBackup() async throws {
        let database = cloudKitContainer.privateCloudDatabase
        let recordID = CKRecord.ID(recordName: backupRecordName)
        var imageRecordIDs: [CKRecord.ID] = []

        if let record = try? await database.record(for: recordID),
           let data = try manifestDataFromMainRecord(record) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let manifest = try? decoder.decode(CloudPagesBackupManifest.self, from: data) {
                let imageIDs = Set(
                    manifest.entries.flatMap { entry in
                        entry.pages.flatMap { page in page.images.map(\.id) }
                    }
                )
                imageRecordIDs = imageIDs.map { CKRecord.ID(recordName: imageRecordName(for: $0)) }
            }
        }

        if !imageRecordIDs.isEmpty {
            _ = try? await database.modifyRecords(saving: [], deleting: imageRecordIDs)
        }
        _ = try? await database.deleteRecord(withID: recordID)
    }

    private var cloudKitContainer: CKContainer {
        CKContainer(identifier: cloudKitContainerID)
    }

    /// 兼容历史版本：旧版本可能使用 default container 写入备份。
    private var cloudKitRestoreContainers: [CKContainer] {
        let preferred = cloudKitContainer
        let fallback = CKContainer.default()
        if preferred.containerIdentifier == fallback.containerIdentifier {
            return [preferred]
        }
        return [preferred, fallback]
    }

    private func cloudKitAssetPersistentURL() throws -> URL {
        let fm = FileManager.default
        let base = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        if !fm.fileExists(atPath: base.path) {
            try fm.createDirectory(at: base, withIntermediateDirectories: true)
        }
        return base.appendingPathComponent(ckAssetLocalFileName)
    }

    private func uploadManifestV2ToCloudKit(manifestData: Data, notebooks: [Notebook]) async throws -> Bool {
        let status = try await cloudKitContainer.accountStatus()
        guard status == .available else {
            let reason: String
            switch status {
            case .noAccount:
                reason = "未登录 iCloud"
            case .restricted:
                reason = "设备受限制（家长控制/企业策略）"
            case .couldNotDetermine:
                reason = "系统暂时无法确定账号状态"
            case .temporarilyUnavailable:
                reason = "iCloud 服务暂时不可用"
            case .available:
                reason = "可用"
            @unknown default:
                reason = "未知状态(\(status.rawValue))"
            }
            throw CloudSyncError.cloudKitAccountUnavailable(reason)
        }

        let database = cloudKitContainer.privateCloudDatabase
        let imageRecords = buildImageRecordsForUpload(notebooks: notebooks)
        do {
            try await cloudKitSaveRecords(imageRecords, database: database)
        } catch {
            // 某些环境未部署 `NotebookBackupImage` schema，会返回 CKError 15。
            // 降级：允许仅上传 manifest（页元数据），图片恢复时可为空 URL。
            if !isServerRejectedRequest(error) {
                throw CloudSyncError.cloudKitWriteFailed(error.localizedDescription)
            }
        }

        let recordID = CKRecord.ID(recordName: backupRecordName)
        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch {
            record = CKRecord(recordType: backupRecordType, recordID: recordID)
        }

        record["manifestV2"] = nil
        record["payloadInline"] = nil
        record["payload"] = nil

        let useLegacyPayloadField = try await prefersLegacyPayloadField(
            for: record,
            database: database,
            manifestData: manifestData
        )
        if useLegacyPayloadField {
            if manifestData.count <= maxInlinePayloadBytes {
                record["payloadInline"] = manifestData as CKRecordValue
            } else {
                let fileURL = try cloudKitAssetPersistentURL()
                try manifestData.write(to: fileURL, options: .atomic)
                record["payload"] = CKAsset(fileURL: fileURL)
            }
        } else {
            if manifestData.count <= maxInlinePayloadBytes {
                record["manifestV2"] = manifestData as CKRecordValue
            } else {
                let fileURL = try cloudKitAssetPersistentURL()
                try manifestData.write(to: fileURL, options: .atomic)
                record["manifestV2"] = CKAsset(fileURL: fileURL)
            }
        }

        do {
            _ = try await database.save(record)
        } catch {
            throw CloudSyncError.cloudKitWriteFailed(error.localizedDescription)
        }
        return true
    }

    private func prefersLegacyPayloadField(
        for record: CKRecord,
        database: CKDatabase,
        manifestData: Data
    ) async throws -> Bool {
        if manifestData.count <= maxInlinePayloadBytes {
            record["manifestV2"] = manifestData as CKRecordValue
        } else {
            let fileURL = try cloudKitAssetPersistentURL()
            try manifestData.write(to: fileURL, options: .atomic)
            record["manifestV2"] = CKAsset(fileURL: fileURL)
        }
        do {
            _ = try await database.save(record)
            return false
        } catch {
            record["manifestV2"] = nil
            return isServerRejectedRequest(error)
        }
    }

    private func isServerRejectedRequest(_ error: Error) -> Bool {
        guard let ck = error as? CKError else { return false }
        return ck.code == .serverRejectedRequest
    }

    private func buildImageRecordsForUpload(notebooks: [Notebook]) -> [CKRecord] {
        var out: [CKRecord] = []
        var seen = Set<UUID>()
        let fm = FileManager.default
        for n in notebooks {
            for p in n.pages {
                for img in p.images {
                    guard seen.insert(img.id).inserted else { continue }
                    guard let url = img.url, url.isFileURL, fm.fileExists(atPath: url.path) else { continue }
                    let rid = CKRecord.ID(recordName: imageRecordName(for: img.id))
                    let rec = CKRecord(recordType: imageRecordType, recordID: rid)
                    rec["asset"] = CKAsset(fileURL: url)
                    out.append(rec)
                }
            }
        }
        return out
    }

    private func imageRecordName(for imageId: UUID) -> String {
        "img-\(imageId.uuidString)"
    }

    private func cloudKitSaveRecords(_ records: [CKRecord], database: CKDatabase) async throws {
        guard !records.isEmpty else { return }
        let chunkSize = 200
        var i = 0
        while i < records.count {
            let end = min(i + chunkSize, records.count)
            let chunk = Array(records[i..<end])
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                let op = CKModifyRecordsOperation(recordsToSave: chunk, recordIDsToDelete: nil)
                op.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        cont.resume()
                    case .failure(let err):
                        cont.resume(throwing: err)
                    }
                }
                database.add(op)
            }
            i = end
        }
    }

    private func restoreManifestV2FromCloudKit(documentStore: DocumentStore) async throws -> Bool {
        let recordID = CKRecord.ID(recordName: backupRecordName)
        for container in cloudKitRestoreContainers {
            let database = container.privateCloudDatabase
            guard let record = try? await database.record(for: recordID) else { continue }
            guard let manifestData = try manifestDataFromMainRecord(record) else { continue }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            guard let manifest = try? decoder.decode(CloudPagesBackupManifest.self, from: manifestData),
                  manifest.version == 2,
                  !manifest.entries.isEmpty else { continue }
            let map = try await downloadImageAssets(for: manifest, database: database)
            try await applyManifestV2(manifest, imageURLMap: map, documentStore: documentStore)
            UserDefaults.standard.set(Date(), forKey: lastSyncKey)
            notifyCloudRestoreCompleted()
            return true
        }
        return false
    }

    private func manifestDataFromMainRecord(_ record: CKRecord) throws -> Data? {
        if let m = record["manifestV2"] as? Data, !m.isEmpty {
            return m
        }
        if let m = record["manifestV2"] as? NSData, m.length > 0 {
            return m as Data
        }
        if let asset = record["manifestV2"] as? CKAsset,
           let url = asset.fileURL,
           let data = try? Data(contentsOf: url),
           !data.isEmpty {
            return data
        }
        // 旧 payloadInline 里可能误存 v2 manifest（或仅 JSON）
        if let inline = record["payloadInline"] as? Data, !inline.isEmpty {
            if (try? JSONDecoder().decode(CloudPagesBackupManifest.self, from: inline)) != nil {
                return inline
            }
        }
        return nil
    }

    private func restoreLegacyNotebooksFromCloudKit(documentStore: DocumentStore) async throws -> Bool {
        let recordID = CKRecord.ID(recordName: backupRecordName)
        for container in cloudKitRestoreContainers {
            let database = container.privateCloudDatabase
            guard let record = try? await database.record(for: recordID) else { continue }
            guard let data = try legacyNotebookDumpData(from: record) else { continue }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            guard let notebooks = try? decoder.decode([Notebook].self, from: data), !notebooks.isEmpty else { continue }
            for notebook in notebooks {
                try await documentStore.saveNotebook(notebook)
            }
            UserDefaults.standard.set(Date(), forKey: lastSyncKey)
            notifyCloudRestoreCompleted()
            return true
        }
        return false
    }

    private func legacyNotebookDumpData(from record: CKRecord) throws -> Data? {
        if record["manifestV2"] as? CKAsset != nil {
            return nil
        }
        if let m = record["manifestV2"] as? Data, !m.isEmpty {
            return nil
        }
        if let inline = record["payloadInline"] as? Data, !inline.isEmpty {
            if (try? JSONDecoder().decode(CloudPagesBackupManifest.self, from: inline)) != nil {
                return nil
            }
            return inline
        }
        if let inline = record["payloadInline"] as? NSData, inline.length > 0 {
            let d = inline as Data
            if (try? JSONDecoder().decode(CloudPagesBackupManifest.self, from: d)) != nil {
                return nil
            }
            return d
        }
        if let asset = record["payload"] as? CKAsset,
           let url = asset.fileURL,
           let data = try? Data(contentsOf: url),
           !data.isEmpty {
            if (try? JSONDecoder().decode(CloudPagesBackupManifest.self, from: data)) != nil {
                return nil
            }
            return data
        }
        return nil
    }

    private func downloadImageAssets(for manifest: CloudPagesBackupManifest, database: CKDatabase) async throws -> [UUID: URL] {
        var ids: [UUID] = []
        for e in manifest.entries {
            for p in e.pages {
                for im in p.images {
                    ids.append(im.id)
                }
            }
        }
        ids = Array(Set(ids))
        guard !ids.isEmpty else { return [:] }

        let scansDir = try scansDirectoryURL()
        let fm = FileManager.default
        if !fm.fileExists(atPath: scansDir.path) {
            try fm.createDirectory(at: scansDir, withIntermediateDirectories: true)
        }

        var map: [UUID: URL] = [:]
        for uuid in ids {
            let rid = CKRecord.ID(recordName: imageRecordName(for: uuid))
            guard let rec = try? await database.record(for: rid) else { continue }
            guard let asset = rec["asset"] as? CKAsset,
                  let src = asset.fileURL,
                  let data = try? Data(contentsOf: src),
                  !data.isEmpty else { continue }
            let dest = scansDir.appendingPathComponent("\(uuid.uuidString).jpg")
            try? data.write(to: dest, options: [.atomic])
            map[uuid] = dest
        }
        return map
    }
#endif

    private func scansDirectoryURL() throws -> URL {
        let docs = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return docs.appendingPathComponent("scans", isDirectory: true)
    }

    private static func buildManifest(from notebooks: [Notebook]) -> CloudPagesBackupManifest {
        CloudPagesBackupManifest(
            entries: notebooks.map { n in
                CloudPagesBackupEntry(
                    serverBookId: n.serverBookId,
                    notebookId: n.id,
                    pages: n.pages.map { pageToBackup($0) }
                )
            }
        )
    }

    private static func pageToBackup(_ p: NotebookPage) -> NotebookPageBackup {
        NotebookPageBackup(
            id: p.id,
            notebookID: p.notebookID,
            createdAt: p.createdAt,
            updatedAt: p.updatedAt,
            sortIndex: p.sortIndex,
            images: p.images.map { PhotoAssetBackup(id: $0.id, sourceIdentifier: $0.sourceIdentifier) },
            note: p.note,
            tag: p.tag
        )
    }

    private func applyManifestV2(
        _ manifest: CloudPagesBackupManifest,
        imageURLMap: [UUID: URL],
        documentStore: DocumentStore
    ) async throws {
        let placeholderCover = NotebookCover(
            id: 0,
            name: "",
            type: 0,
            price: "",
            isMemberExclusive: false,
            imageUrl: "",
            thumbUrl: "",
            creatorUserId: nil,
            createdAt: ""
        )
        let localNotebooks = (try? await documentStore.fetchAllNotebooks()) ?? []
        for entry in manifest.entries {
            let remotePages: [NotebookPage] = entry.pages.map { pb in
                let images: [PhotoAsset] = pb.images.map { im in
                    let resolvedURL = imageURLMap[im.id] ?? resolveAnyScanURLIfExists(imageID: im.id)
                    return PhotoAsset(id: im.id, sourceIdentifier: im.sourceIdentifier, url: resolvedURL)
                }
                return NotebookPage(
                    id: pb.id,
                    notebookID: pb.notebookID,
                    createdAt: pb.createdAt,
                    updatedAt: pb.updatedAt,
                    sortIndex: pb.sortIndex,
                    images: images,
                    note: pb.note,
                    tag: pb.tag
                )
            }
            let local = localNotebook(matching: entry, from: localNotebooks)
            let mergedPages = mergePages(localPages: local?.pages ?? [], remotePages: remotePages)
            let notebook = Notebook(
                id: local?.id ?? entry.notebookId,
                serverBookId: entry.serverBookId,
                title: local?.title ?? "",
                category: local?.category ?? "",
                createdAt: local?.createdAt ?? Date(),
                updatedAt: max(local?.updatedAt ?? .distantPast, Date()),
                cover: local?.cover ?? placeholderCover,
                pages: mergedPages,
                tags: local?.tags ?? []
            )
            try await documentStore.saveNotebook(notebook)
        }
    }

    /// 恢复时优先按稳定本地 notebookId 匹配，再回退 serverBookId，避免仅按 serverBookId 导致匹配失败。
    private func localNotebook(
        matching entry: CloudPagesBackupEntry,
        from localNotebooks: [Notebook]
    ) -> Notebook? {
        if let byNotebookId = localNotebooks.first(where: { $0.id == entry.notebookId }) {
            return byNotebookId
        }
        return localNotebooks.first(where: { $0.serverBookId == entry.serverBookId })
    }

    /// 按 page.id 合并本地与云端页面；冲突时以 updatedAt 更新的一方为准，并重排 sortIndex。
    private func mergePages(localPages: [NotebookPage], remotePages: [NotebookPage]) -> [NotebookPage] {
        var mergedByID: [UUID: NotebookPage] = [:]
        for page in localPages {
            mergedByID[page.id] = page
        }
        for page in remotePages {
            if let existing = mergedByID[page.id] {
                mergedByID[page.id] = page.updatedAt >= existing.updatedAt ? page : existing
            } else {
                mergedByID[page.id] = page
            }
        }
        let sorted = mergedByID.values.sorted {
            if $0.sortIndex == $1.sortIndex {
                return $0.updatedAt < $1.updatedAt
            }
            return $0.sortIndex < $1.sortIndex
        }
        return sorted.enumerated().map { index, page in
            var copy = page
            copy.sortIndex = index
            return copy
        }
    }

    private func resolveLocalScanURLIfExists(imageID: UUID) -> URL? {
        guard let scansDir = try? scansDirectoryURL() else { return nil }
        let url = scansDir.appendingPathComponent("\(imageID.uuidString).jpg")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// 优先本地 scans；若不存在则尝试从 iCloud Documents/scans 下载并回填到本地 scans。
    private func resolveAnyScanURLIfExists(imageID: UUID) -> URL? {
        if let local = resolveLocalScanURLIfExists(imageID: imageID) {
            return local
        }
        let fm = FileManager.default
        guard let localScansDir = try? scansDirectoryURL() else { return nil }
        if !fm.fileExists(atPath: localScansDir.path) {
            try? fm.createDirectory(at: localScansDir, withIntermediateDirectories: true)
        }
        guard let cloudScansDir = fm.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("scans", isDirectory: true) else { return nil }
        let cloudURL = cloudScansDir.appendingPathComponent("\(imageID.uuidString).jpg")
        if fm.isUbiquitousItem(at: cloudURL) {
            try? fm.startDownloadingUbiquitousItem(at: cloudURL)
        }
        guard let data = try? Data(contentsOf: cloudURL), !data.isEmpty else { return nil }
        let localURL = localScansDir.appendingPathComponent("\(imageID.uuidString).jpg")
        try? data.write(to: localURL, options: [.atomic])
        return fm.fileExists(atPath: localURL.path) ? localURL : nil
    }

    private func resolveImageURLsFromFileBackup(manifest: CloudPagesBackupManifest) -> [UUID: URL] {
        var imageIDs: Set<UUID> = []
        for entry in manifest.entries {
            for page in entry.pages {
                for image in page.images {
                    imageIDs.insert(image.id)
                }
            }
        }
        guard !imageIDs.isEmpty else { return [:] }

        let fm = FileManager.default
        guard let localScansDir = try? scansDirectoryURL() else { return [:] }
        if !fm.fileExists(atPath: localScansDir.path) {
            try? fm.createDirectory(at: localScansDir, withIntermediateDirectories: true)
        }

        var result: [UUID: URL] = [:]
        let cloudScansDir = fm.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("scans", isDirectory: true)

        for imageID in imageIDs {
            let localURL = localScansDir.appendingPathComponent("\(imageID.uuidString).jpg")
            if fm.fileExists(atPath: localURL.path) {
                result[imageID] = localURL
                continue
            }
            guard let cloudScansDir else { continue }
            let cloudURL = cloudScansDir.appendingPathComponent("\(imageID.uuidString).jpg")
            if fm.isUbiquitousItem(at: cloudURL) {
                try? fm.startDownloadingUbiquitousItem(at: cloudURL)
            }
            guard let data = try? Data(contentsOf: cloudURL), !data.isEmpty else { continue }
            try? data.write(to: localURL, options: [.atomic])
            if fm.fileExists(atPath: localURL.path) {
                result[imageID] = localURL
            }
        }
        return result
    }

    private func syncScanImagesToUbiquityDocuments(notebooks: [Notebook], documentsURL: URL) throws {
        let fm = FileManager.default
        let scansDir = documentsURL.appendingPathComponent("scans", isDirectory: true)
        if !fm.fileExists(atPath: scansDir.path) {
            try fm.createDirectory(at: scansDir, withIntermediateDirectories: true)
        }

        var seen = Set<UUID>()
        for notebook in notebooks {
            for page in notebook.pages {
                for image in page.images {
                    guard seen.insert(image.id).inserted else { continue }
                    guard let sourceURL = image.url, sourceURL.isFileURL, fm.fileExists(atPath: sourceURL.path) else { continue }
                    let destURL = scansDir.appendingPathComponent("\(image.id.uuidString).jpg")
                    if fm.fileExists(atPath: destURL.path) { continue }
                    try? fm.copyItem(at: sourceURL, to: destURL)
                }
            }
        }
    }

    private func candidateSyncFileURLs() throws -> [URL] {
        var urls: [URL] = []
        let fm = FileManager.default
        if let containerURL = fm.url(forUbiquityContainerIdentifier: nil) {
            urls.append(
                containerURL
                    .appendingPathComponent("Documents", isDirectory: true)
                    .appendingPathComponent(syncFileName)
            )
        }
        let appSupport = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        urls.append(appSupport.appendingPathComponent(syncFileName))
        return urls
    }

    private func preferredSyncFileURL() throws -> URL? {
        let fm = FileManager.default
        if let containerURL = fm.url(forUbiquityContainerIdentifier: nil) {
            let docs = containerURL.appendingPathComponent("Documents", isDirectory: true)
            if !fm.fileExists(atPath: docs.path) {
                try fm.createDirectory(at: docs, withIntermediateDirectories: true)
            }
            return docs.appendingPathComponent(syncFileName)
        }
        let appSupport = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        if !fm.fileExists(atPath: appSupport.path) {
            try fm.createDirectory(at: appSupport, withIntermediateDirectories: true)
        }
        return appSupport.appendingPathComponent(syncFileName)
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

    private func notifyCloudRestoreCompleted() {
        NotificationCenter.default.post(name: .cloudDataDidRestore, object: nil)
    }
}
