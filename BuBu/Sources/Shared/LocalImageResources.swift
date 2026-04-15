import SwiftUI
import UIKit

/// 本地扫描图片等：优先读原始 file URL；若容器迁移导致路径失效，则按文件名回退到当前 `Documents/scans/`。
enum LocalImageLoader {
    static func loadUIImage(from rawURL: URL?) -> UIImage? {
        guard let rawURL else { return nil }

        if let data = try? Data(contentsOf: rawURL),
           let image = UIImage(data: data) {
            return image
        }

        let filename = rawURL.lastPathComponent
        guard !filename.isEmpty,
              let docs = try? FileManager.default.url(
                  for: .documentDirectory,
                  in: .userDomainMask,
                  appropriateFor: nil,
                  create: false
              ) else {
            return nil
        }

        let fallbackURL = docs
            .appendingPathComponent("scans", isDirectory: true)
            .appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: fallbackURL),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }
}

/// 图片加载失败或暂无资源时的占位（与相册、草稿卡片等共用）。
struct AppImagePlaceholderView: View {
    var body: some View {
        ZStack {
            Color.gray.opacity(0.18)
            Image(systemName: "photo")
                .foregroundColor(.secondary)
        }
    }
}
