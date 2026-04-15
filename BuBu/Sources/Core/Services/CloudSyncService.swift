import Foundation

/// 负责 iCloud / CloudKit 等云同步（这里只做接口和 Stub）
protocol CloudSyncService {
    func enableSyncIfNeeded() async throws
    func syncNow() async throws
}

final class StubCloudSyncService: CloudSyncService {
    func enableSyncIfNeeded() async throws {
        // 占位：未来可接入 CloudKit / iCloud Drive
    }

    func syncNow() async throws {
        // 占位：实际实现增量同步
    }
}

