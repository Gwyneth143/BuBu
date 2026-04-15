import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// 采集页：扫描 / 相册 模式
enum CollectCaptureMode: String, CaseIterable {
    case camera = "capture.mode_scan"
    case album = "capture.mode_photo"
}

/// 用于 `fullScreenCover(item:)`，避免闭包捕获旧图
struct DocumentScannerPayload: Identifiable {
    let id = UUID()
    let images: [UIImage]
    let isScan: Bool
    /// 从草稿箱「重新编辑」进入时传入，保存时沿用同一 `id` 并写回本地
    var existingPage: NotebookPage?

    init(images: [UIImage], isScan: Bool, existingPage: NotebookPage? = nil) {
        self.images = images
        self.isScan = isScan
        self.existingPage = existingPage
    }
}

struct CollectDraft: Identifiable {
    let id = UUID()
    let title: String
    let tag: String
}
