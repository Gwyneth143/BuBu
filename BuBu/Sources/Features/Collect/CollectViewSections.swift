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
                Text(localized: "capture.upload_message")
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
        Text(localized: "capture.title")
            .font(AppTheme.Fonts.navTitle)
            .kerning(0.8)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

struct CollectModeTabsView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.presentLogin) private var presentLogin
    @Binding var selectedMode: CollectCaptureMode

    var body: some View {
        HStack(spacing: 32) {
            ForEach(CollectCaptureMode.allCases, id: \.self) { mode in
                VStack(spacing: 4) {
                    Button {
                        if !env.session.isLoggedIn {
                            presentLogin()
                            return
                        }
                        selectedMode = mode
                    } label: {
                        Text(localized: mode.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(
                                selectedMode == mode
                                    ? AppTheme.Colors.primaryColor
                                    : .secondary
                            )
                    }
                    .buttonStyle(.plain)

                    Rectangle()
                        .fill(selectedMode == mode ? AppTheme.Colors.primaryColor : Color.clear)
                        .frame(height: 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - 中央采集区

struct CollectCameraAreaView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.presentLogin) private var presentLogin
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
                            .foregroundColor(AppTheme.Colors.primaryColor.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 24)

                        HStack(spacing: 16) {
                            Button(action: {
                                if !env.session.isLoggedIn {
                                    presentLogin()
                                    return
                                }
                                onScanTap()
                            }) {
                                Text(selectedMode == .camera ? String.localized("capture.button_scan") : String.localized("capture.button_picture") )
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(AppTheme.Colors.primaryColor)
                                    )
                            }
                            .shadow(color: AppTheme.Colors.shadowColor, radius: 6, x: 4, y: 4)
                            .buttonStyle(.plain)

                            Button(action: {
                                if !env.session.isLoggedIn {
                                    presentLogin()
                                    return
                                }
                                onUploadTap()
                            }) {
                                Text(localized: "capture.button_upload")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(AppTheme.Colors.primaryColor)
                                    )
                            }
                            .shadow(color: AppTheme.Colors.shadowColor, radius: 6, x: 4, y: 4)
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
//    var onDraftTagTap: (NotebookPage) -> Void
    var onDraftTap: (NotebookPage) -> Void
    var onDraftDeleteTap: (NotebookPage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized: "capture.recent_drafts")
                .font(.caption)
                .foregroundColor(.secondary)

            if drafts.isEmpty {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .frame(height: 96)
                    .overlay {
                        Text(localized: "capture.recent_drafts_empty")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(drafts) { draft in
                            CollectDraftCard(
                                draft: draft,
                                onTap: { onDraftTap(draft) },
                                onDeleteTap: { onDraftDeleteTap(draft) }
                            )
                        }
                    }
                    .padding(.trailing, 8)
                }
            }
        }
    }
}

struct CollectDraftCard: View {
    let draft: NotebookPage
    var onTap: () -> Void
    var onDeleteTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Spacer()
                Button(action: onDeleteTap) {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(red: 0.91, green: 0.26, blue: 0.21))
                        .padding(6)
                        .background(
                            Circle().fill(Color(red: 1.0, green: 0.95, blue: 0.95))
                        )
                }
                .buttonStyle(.plain)
            }

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
                Button(action: onTap) {
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
