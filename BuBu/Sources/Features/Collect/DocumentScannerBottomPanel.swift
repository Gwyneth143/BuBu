#if canImport(UIKit) && canImport(VisionKit)
import SwiftUI

struct DocumentScannerBottomPanel: View {
    let notebooks: [Notebook]
    let selectedNotebookID: Int?
    @Binding var noteText: String
    @Binding var tagText: String
    let onTapSelectTarget: () -> Void
    let onSave: () -> Void

    private var isDraftSelected: Bool { selectedNotebookID == nil }
    private var selectedNotebook: Notebook? {
        notebooks.first(where: { $0.serverBookId == selectedNotebookID })
    }

    var body: some View {
        VStack(spacing: 16) {
            tagSection
            noteSection

            HStack(spacing: 8) {
                Image(systemName: "book.closed")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.tabHighlight)
                Text("保存至册子")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "111827"))
                Spacer()
            }

            saveTargetCard

            Button(action: onSave) {
                Text("保存")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(AppTheme.Colors.tabHighlight)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 8)
        )
    }

    private var saveTargetCard: some View {
        Group {
            if notebooks.isEmpty {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(hex: "F9FAFB"))
                    .overlay(
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(hex: "E5E7EB"))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: "tray")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.secondary)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text("当前暂无册子")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(hex: "111827"))
                                Text("扫描内容会暂时保存在草稿箱中，你可以稍后在书架页创建册子并整理。")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    )
            } else {
                Button(action: onTapSelectTarget) {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isDraftSelected ? Color(hex: "F9FAFB") : Color(hex: "FDF2FF"))
                        .overlay(
                            HStack(spacing: 12) {
                                if isDraftSelected {
                                    
                                    draftSelectedContent
                                } else if let current = selectedNotebook {
                                    notebookSelectedContent(current)
                                } else {
                                    invalidSelectionContent
                                }

                                Spacer()

                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(hex: "9CA3AF"))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var draftSelectedContent: some View {
        Group {
            Circle()
                .fill(Color(hex: "EEF2FF"))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "tray.full")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.tabHighlight)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("草稿箱")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "111827"))
                    .lineLimit(1)
                Text("点击切换保存到正式册子")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "6B7280"))
            }
        }
    }

    private func notebookSelectedContent(_ current: Notebook) -> some View {
        Group {
            Circle()
                .fill(Color.white)
                .frame(width: 32, height: 32)
                .overlay(Text("📒").font(.system(size: 18)))

            VStack(alignment: .leading, spacing: 2) {
                Text(current.title.isEmpty ? "Untitled Journal" : current.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "111827"))
                    .lineLimit(1)
                Text("点击切换保存到其他册子或草稿箱")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "6B7280"))
            }
        }
    }

    private var invalidSelectionContent: some View {
        Group {
            Circle()
                .fill(Color(hex: "FEE2E2"))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "DC2626"))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("未找到该册子")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "111827"))
                Text("请重新选择保存位置")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "6B7280"))
            }
        }
    }

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.tabHighlight)
                Text("标签")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "111827"))
                Spacer()
            }

            HStack(spacing: 8) {
                TextField("为当前文件添加一个标签…", text: $tagText)
                    .font(.system(size: 14))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(hex: "F9FAFB"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
                            )
                    )
            }
        }
    }

    private var noteSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "note.text")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.tabHighlight)
                Text("备注")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "111827"))
                Spacer()
            }

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(hex: "F9FAFB"))

                Group {
                    if #available(iOS 16.0, *) {
                        TextEditor(text: $noteText)
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(minHeight: 110)
                    } else {
                        TextEditor(text: $noteText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(minHeight: 110)
                    }
                }

                if noteText.isEmpty {
                    Text("有什么想要备注的呢...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
            }
        }
    }
}
#endif
