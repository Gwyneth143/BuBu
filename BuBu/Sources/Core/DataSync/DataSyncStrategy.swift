import Foundation

// MARK: - 云端同步预留（第一版仅本地，不改变用户可见行为）

/// 下一版接入 REST / CloudKit 时建议遵循的约定，避免再改一次主键与合并语义。
///
/// **标识**
/// - 客户端主键沿用 `UUID`（`Notebook.id`、`NotebookPage.id`），上传时作为 `client_id` 或幂等键。
///
/// **版本与冲突**
/// - `Notebook.updatedAt` / `NotebookPage.updatedAt`：合并时优先比较时间戳（LWW），必要时再结合 `localRevision`。
/// - `localRevision`：每次本地持久化成功递增，用于检测「同一记录是否被多端同时修改」。
/// - `serverRevision`：服务端返回的 etag / 版本号，拉取后写入，用于条件更新。
///
/// **删除**
/// - 硬删除适合仅本地；云端建议 eventually 使用 **tombstone**（`deletedAt` 或 `SyncRecordState.pendingDelete`），再异步清理。
///
/// **分页顺序**
/// - `NotebookPage.sortIndex`：与数组下标一致持久化，避免关系型数据库无序导致页序错乱。
///
/// **二进制资源**
/// - `PhotoAsset.url` 指向沙盒文件时，同步层需单独上传 blob，再在云端替换为 URL；不要整块 JSON 里塞 Data。
enum DataSyncStrategy {
    /// 占位说明类型，避免文件仅含注释被优化掉
    static let clientIdKey = "clientId"
}

/// 记录在同步管道中的状态（持久化在 SwiftData，第一版默认 `.idle`）。
enum SyncRecordState: Int16, Codable, Sendable {
    /// 无待同步操作（或未启用云端）
    case idle = 0
    /// 有待上传的本地修改
    case pendingUpload = 1
    /// 已标记删除，待同步确认后彻底移除
    case pendingDelete = 2
    /// 多端冲突，需业务层解决
    case conflict = 3
}
