import SwiftUI
import Kingfisher
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 解码中遮罩

struct CollectDecodingProgressOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.12)
                .ignoresSafeArea()
                .allowsHitTesting(true)
            ProgressView {
                Text("正在载入照片…")
                    .font(.subheadline)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
    }
}

// MARK: - 标题与模式 Tab

struct CollectTitleSection: View {
    var body: some View {
        Text("Inspiration / Capture")
            .font(AppTheme.Fonts.sectionTitle)
            .kerning(0.8)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

struct CollectModeTabsView: View {
    @Binding var selectedMode: CollectCaptureMode

    var body: some View {
        HStack(spacing: 32) {
            ForEach(CollectCaptureMode.allCases, id: \.self) { mode in
                VStack(spacing: 4) {
                    Button {
                        selectedMode = mode
                    } label: {
                        Text(localized: mode.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(
                                selectedMode == mode
                                    ? AppTheme.Colors.tabHighlight
                                    : .secondary
                            )
                    }
                    .buttonStyle(.plain)

                    Rectangle()
                        .fill(selectedMode == mode ? AppTheme.Colors.tabHighlight : Color.clear)
                        .frame(height: 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - 中央采集区

struct CollectCameraAreaView: View {
    @Binding var selectedMode: CollectCaptureMode
    var onScanTap: () -> Void
    var onUploadTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .foregroundColor(Color(hex: "D1D5DB"))
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.clear)
                )
                .frame(width: 360, height: 360, alignment: .center)
                .overlay {
                    VStack(spacing: 20) {
                        Image(selectedMode == .camera ? "collect_doc" : "collect_photo")
                            .resizable()
                            .frame(width: 140, height: 140, alignment: .center)
                        Text(localized: selectedMode == .camera ? "capture.mode_scan_note" : "capture.mode_photo_note")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(AppTheme.Colors.tabHighlight.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 24)

                        HStack(spacing: 16) {
                            Button(action: onScanTap) {
                                Text(selectedMode == .camera ? "扫描" : "拍照")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color(hex: "FF7EB6"))
                                    )
                            }
                            .buttonStyle(.plain)

                            Button(action: onUploadTap) {
                                Text("上传")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color(hex: "FF7EB6"))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.vertical, 28)
                }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Recent drafts

struct CollectRecentDraftsSection: View {
    let drafts: [NotebookPage]
    var onDraftTagTap: (NotebookPage) -> Void
    var onDraftTap: (NotebookPage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Drafts")
                .font(.caption)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(drafts) { draft in
                        CollectDraftCard(
                            draft: draft,
                            onTap: { onDraftTap(draft) },
                            onTagTap: { onDraftTagTap(draft) }
                        )
                    }

//                    RoundedRectangle(cornerRadius: 20)
//                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
//                        .frame(width: 80, height: 110)
//                        .foregroundColor(AppTheme.Colors.divider)
                }
                .padding(.trailing, 8)
            }
        }
    }
}

struct CollectDraftCard: View {
    let draft: NotebookPage
    var onTap: () -> Void
    var onTagTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
//            RoundedRectangle(cornerRadius: 16)
//                .fill(Color.black.opacity(0.9))
//                .frame(height: 60)
            Group {
                if let uiImage = LocalImageLoader.loadUIImage(from: draft.images.first?.url) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    AppImagePlaceholderView()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .frame(height: 60)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)

            Text("创建：" + Date.dateString(draft.createdAt))
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)

            if draft.tag.count > 0 {
                Button(action: onTagTap) {
                    Text("标签："+draft.tag)
                        .font(.caption)
                        .foregroundColor(.secondary)
//                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        // 需预留约两行 caption 高度，否则固定总高会压成单行并出现尾部省略号
        .frame(width: 140, height: 168)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
    }
}
