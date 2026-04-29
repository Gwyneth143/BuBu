#if canImport(UIKit) && canImport(VisionKit)
import SwiftUI

struct DocumentScannerPickerOverlay: View {
    let notebooks: [Notebook]
    let selectedNotebookID: Int?
    let onClose: () -> Void
    let onSelectDraft: () -> Void
    let onSelectNotebook: (Notebook) -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .transition(.opacity)
                .zIndex(1)

            VStack(spacing: 16) {
                HStack {
                    Text(localized: "scanner.picker_title")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "111827"))
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(6)
                            .background(Circle().fill(Color(hex: "F3F4F6")))
                    }
                    .buttonStyle(.plain)
                }

                ScrollView {
                    VStack(spacing: 10) {
                        Button(action: onSelectDraft) {
                            draftRow(isSelected: selectedNotebookID == nil)
                        }
                        .buttonStyle(.plain)

                        if notebooks.isEmpty {
                            Text(localized: "scanner.picker_empty_hint")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 4)
                        } else {
                            ForEach(notebooks) { notebook in
                                Button {
                                    onSelectNotebook(notebook)
                                } label: {
                                    notebookRow(notebook: notebook, isSelected: notebook.serverBookId == selectedNotebookID)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
            .padding(18)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 8)
            )
            .padding(.horizontal, 24)
            .zIndex(2)
        }
    }

    private func draftRow(isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "EEF2FF"))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "tray.full")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primaryColor)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(localized: "scanner.drafts")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "111827"))
                    .lineLimit(1)
                Text(localized: "scanner.picker_draft_subtitle")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppTheme.Colors.primaryColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? AppTheme.Colors.primaryColor.opacity(0.08) : Color.white)
        )
    }

    private func notebookRow(notebook: Notebook, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "E5E7EB"))
                .frame(width: 32, height: 32)
                .overlay(Text("📒").font(.system(size: 18)))

            VStack(alignment: .leading, spacing: 2) {
                Text(notebook.title.isEmpty ? String.localized("scanner.untitled_notebook") : notebook.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "111827"))
                    .lineLimit(1)
                Text(notebook.category)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppTheme.Colors.primaryColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? AppTheme.Colors.primaryColor.opacity(0.08) : Color.white)
        )
    }
}
#endif
