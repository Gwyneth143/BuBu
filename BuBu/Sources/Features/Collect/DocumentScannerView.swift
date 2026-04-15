#if canImport(UIKit) && canImport(VisionKit)
import SwiftUI
import UIKit
import VisionKit

struct DocumentScannerView: View {
    let initialImages: [UIImage]
    let isScan: Bool
    /// 从草稿重新编辑时非空，保存时替换同 `id` 的页，避免重复条目
    private let existingPage: NotebookPage?
    var onDismiss: (() -> Void)?
    let onComplete: (NotebookPage) -> Void

    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var scannedImages: [UIImage] = []       // 扫描得到的图片数组
    @State private var currentPageIndex = 0                // 当前展示的图片索引
    @State private var editingScan: EditingScan?           // 当前编辑的图片
    @State private var notebooks: [Notebook] = []          // 用户创建的册子
    @State private var selectedNotebookID: Int?            // nil 表示草稿箱
    @State private var noteText: String = ""               // 备注
    @State private var tagText: String = ""                // 新标签输入
    @State private var showingNotebookPicker = false       // 是否显示册子选择弹框
    @State private var showingSaveConfirm = false          // 保存前二次确认
    
    @State private var bookName: String?

    private struct EditingScan: Identifiable {
        let id = UUID()
        let index: Int
    }

    init(
        initialImages: [UIImage] = [],
        isScan: Bool = false,
        existingPage: NotebookPage? = nil,
        onDismiss: (() -> Void)? = nil,
        onComplete: @escaping (NotebookPage) -> Void
    ) {
        self.initialImages = initialImages
        self.isScan = isScan
        self.existingPage = existingPage
        self.onDismiss = onDismiss
        self.onComplete = onComplete
        _scannedImages = State(initialValue: initialImages)
        _noteText = State(initialValue: existingPage?.note ?? "")
        _tagText = State(initialValue: existingPage?.tag ?? "")
        let initialNotebookID: Int? = {
            guard let ep = existingPage else { return nil }
            return ep.notebookID == 0 ? nil : ep.notebookID
        }()
        _selectedNotebookID = State(initialValue: initialNotebookID)
    }

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    DocumentScannerPreviewSection(
                        scannedImages: scannedImages,
                        currentPageIndex: $currentPageIndex,
                        onTapImage: { index in
                            editingScan = EditingScan(index: index)
                        }
                    )
                    DocumentScannerBottomPanel(
                        notebooks: notebooks,
                        selectedNotebookID: selectedNotebookID,
                        noteText: $noteText,
                        tagText: $tagText,
                        onTapSelectTarget: {
                            withAnimation { showingNotebookPicker = true }
                        },
                        onSave: {
                            showingSaveConfirm = true
                        }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
            if showingNotebookPicker {
                DocumentScannerPickerOverlay(
                    notebooks: notebooks,
                    selectedNotebookID: selectedNotebookID,
                    onClose: {
                        showingNotebookPicker = false
                    },
                    onSelectDraft: handleSelectDraft,
                    onSelectNotebook: handleSelectNotebook
                )
            }
            if showingSaveConfirm {
                let message = bookName != nil ? "保存后会写入你当前选择的册子-\(bookName!)" : "保存后会写入草稿箱，你稍后仍可继续编辑"
                ConfirmModalView(
                    title: "确认保存当前页面？",
                    message: message,
                    iconName: "tray.and.arrow.down.fill",
                    cancelTitle: "再看看",
                    confirmTitle: "确认保存",
                    onCancel: {
                        showingSaveConfirm = false
                    },
                    onConfirm: {
                        showingSaveConfirm = false
                        handleSaveTapped()
                    }
                )
            }
        }
        .background(AppTheme.Colors.appBackground.ignoresSafeArea())
        .navigationTitle("整理台")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") {
                    onDismiss?()
                    dismiss()
                }
                .foregroundColor(.black)
            }
        }
        .onAppear {
            if notebooks.isEmpty {
                loadNotebooks()
            }
        }
        .fullScreenCover(item: $editingScan) { scan in
            CompatibleNavigationStack {
                if scan.index < scannedImages.count {
                    ScanImageEditorView(
                        image: scannedImages[scan.index],
                        onCancel: {
                            editingScan = nil
                        },
                        onSave: { updated in
                            scannedImages[scan.index] = updated
                            editingScan = nil
                        }
                    )
                } else {
                    Color.clear
                }
            }
        }
    }

    private func handleSelectDraft() {
        selectedNotebookID = nil
        bookName = nil
        withAnimation {
            showingNotebookPicker = false
        }
    }

    private func handleSelectNotebook(_ notebook: Notebook) {
        selectedNotebookID = notebook.serverBookId
        bookName = notebook.title
        withAnimation {
            showingNotebookPicker = false
        }
    }

    private func handleSaveTapped() {
        let imageAssets = saveImagesToDisk(scannedImages)
        let trimmedNote = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let tagString = tagText.trimmingCharacters(in: .whitespacesAndNewlines)
        let now = Date()
        let page = NotebookPage(
            id: existingPage?.id ?? UUID(),
            notebookID: selectedNotebookID ?? 0,
            createdAt: existingPage?.createdAt ?? now,
            updatedAt: now,
            sortIndex: existingPage?.sortIndex ?? 0,
            images: imageAssets,
            note: trimmedNote,
            tag: tagString
        )

        savePageToNotebook(page)
        onComplete(page)
        dismiss()
    }

    /// 将当前扫描页写入选中的册子或草稿箱；若 `page.id` 已存在则替换
    private func savePageToNotebook(_ page: NotebookPage) {
        if let notebookID = selectedNotebookID {
            Task {
                guard let index = notebooks.firstIndex(where: { $0.serverBookId == notebookID }) else { return }
                var updatedNotebook = notebooks[index]
                let persistedPages = (try? await env.documentStore.fetchPages(for: notebookID)) ?? []
                var mergedPages = persistedPages.isEmpty ? updatedNotebook.pages : persistedPages
                if let i = mergedPages.firstIndex(where: { $0.id == page.id }) {
                    mergedPages[i] = page
                } else {
                    mergedPages.append(page)
                }
                updatedNotebook.pages = mergedPages
                updatedNotebook.updatedAt = Date()

                try? await env.documentStore.saveNotebook(updatedNotebook)

                // 从草稿箱移入册子时，删除草稿中的同 id 页
                if let ep = existingPage, ep.notebookID == 0 {
                    await removePageFromDraftNotebook(pageId: ep.id)
                }

                await MainActor.run {
                    notebooks[index] = updatedNotebook
                }
            }
        } else {
            Task {
                let book = try? await env.documentStore.fetchNotebook(id: nil)
                var pages: [NotebookPage]
                if let book {
                    pages = book.pages
                } else {
                    pages = (try? await env.documentStore.fetchPages(for: nil)) ?? []
                }
                if let i = pages.firstIndex(where: { $0.id == page.id }) {
                    pages[i] = page
                } else {
                    pages.append(page)
                }
                if var existing = book {
                    existing.pages = pages
                    existing.updatedAt = Date()
                    try? await env.documentStore.saveNotebook(existing)
                } else {
                    let note = Notebook(
                        title: "",
                        category: "",
                        createdAt: Date(),
                        updatedAt: Date(),
                        cover: NotebookCover(
                            id: 0,
                            name: "",
                            type: 0,
                            price: "",
                            isMemberExclusive: false,
                            imageUrl: "",
                            thumbUrl: "",
                            creatorUserId: nil,
                            createdAt: ""
                        ),
                        pages: pages,
                        tags: []
                    )
                    try? await env.documentStore.saveNotebook(note)
                }
            }
        }
    }

    private func removePageFromDraftNotebook(pageId: UUID) async {
        guard var book = try? await env.documentStore.fetchNotebook(id: nil) else { return }
        book.pages.removeAll { $0.id == pageId }
        book.updatedAt = Date()
        try? await env.documentStore.saveNotebook(book)
    }

    /// 把扫描 / 上传得到的 UIImage 写入应用沙盒，并返回带本地 URL 的 PhotoAsset 数组
    private func saveImagesToDisk(_ images: [UIImage]) -> [PhotoAsset] {
        guard !images.isEmpty else { return [] }

        var assets: [PhotoAsset] = []
        let fileManager = FileManager.default

        // 保存到 Documents/scans 目录下
        let scansDirectory: URL
        do {
            let docs = try fileManager.url(for: .documentDirectory,
                                           in: .userDomainMask,
                                           appropriateFor: nil,
                                           create: true)
            scansDirectory = docs.appendingPathComponent("scans", isDirectory: true)
            if !fileManager.fileExists(atPath: scansDirectory.path) {
                try fileManager.createDirectory(at: scansDirectory, withIntermediateDirectories: true)
            }
        } catch {
            return []
        }

        for image in images {
            let id = UUID()
            let filename = id.uuidString + ".jpg"
            let url = scansDirectory.appendingPathComponent(filename)

            if let data = image.jpegData(compressionQuality: 0.9) {
                do {
                    try data.write(to: url, options: [.atomic])
                    let asset = PhotoAsset(id: id, sourceIdentifier: nil, url: url)
                    assets.append(asset)
                } catch {
                    continue
                }
            }
        }

        return assets
    }

    /// 从服务端 `GET /books` 拉取册子列表（与书架「全部」一致，不传 categoryName）
    private func loadNotebooks() {
        Task {
            do {
                var merged: [Notebook] = []
                var page = 1
                let pageSize = 100
                while true {
                    let part = try await env.bookStore.fetchBooks(
                        query: BookQuery(page: page, pageSize: pageSize, categoryName: nil)
                    )
                    merged.append(contentsOf: part)
                    if part.count < pageSize { break }
                    page += 1
                    if page > 50 { break }
                }
                await MainActor.run {
                    notebooks = merged.sorted(by: { $0.updatedAt > $1.updatedAt })
                    if let ep = existingPage {
                        if ep.notebookID == 0 {
                            selectedNotebookID = nil
                            bookName = nil
                        } else {
                            selectedNotebookID = ep.notebookID
                            bookName = notebooks.first(where: { $0.serverBookId == ep.notebookID })?.title
                        }
                        return
                    }
                    if selectedNotebookID == nil ||
                        !notebooks.contains(where: { $0.serverBookId == selectedNotebookID }) {
                        selectedNotebookID = notebooks.first?.serverBookId
                    }
                }
            } catch {
                await MainActor.run {
                    notebooks = []
                    selectedNotebookID = nil
                }
            }
        }
    }

}
#else
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DocumentScannerView: View {
    let onComplete: (NotebookPage) -> Void

    init(
        initialImages: [UIImage] = [],
        isScan: Bool = false,
        existingPage: NotebookPage? = nil,
        onDismiss: (() -> Void)? = nil,
        onComplete: @escaping (NotebookPage) -> Void
    ) {
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("当前平台不支持 VisionKit 文档扫描。")
                .font(.headline)
            Text("请在 iPhone 或 iPad 真机上使用该功能。")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(24)
    }
}
#endif
