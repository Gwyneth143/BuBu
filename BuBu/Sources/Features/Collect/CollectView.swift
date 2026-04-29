import SwiftUI
import Mantis
import PhotosUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif
#if canImport(PDFKit)
import PDFKit
#endif

struct CollectView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.presentLogin) private var presentLogin
    @StateObject private var viewModel: CollectViewModel
    @State private var selectedMode: CollectCaptureMode = .camera
    @State private var showingScanner = false
    @State private var documentScannerPayload: DocumentScannerPayload?
    @State private var showingFileImporter = false
    @State private var showingUploadOptions = false
    @State private var showingPhotoPicker = false
    @State private var showingCropPicker = false
    @State private var selectedFileURL: URL?
    @State private var showingScannerUnavailableAlert = false
    @State private var showingSystemCamera = false
    @State private var image: UIImage?
    @State private var transformation: Transformation?
    @State private var cropInfo: CropInfo?
    @State private var isDecodingLibraryPhoto = false
    @State private var drafts:[NotebookPage] = []
    @State private var showingDraftDeleteConfirm = false
    @State private var deletingDraft: NotebookPage?

    init() {
        _viewModel = StateObject(wrappedValue: CollectViewModel(
            ocrService: VisionOCRService(),
            templateEngine: SimpleTemplateEngine()
        ))
        
    }

    var body: some View {
        ZStack {
            AppTheme.Colors.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    CollectTitleSection()
                    CollectModeTabsView(selectedMode: $selectedMode)
                    CollectCameraAreaView(
                        selectedMode: $selectedMode,
                        onScanTap: handleScanTap,
                        onUploadTap: { showingUploadOptions = true }
                    )
                    CollectRecentDraftsSection(
                        drafts: drafts,
                        onDraftTap: { draft in
                            openDraftEditor(draft)
                        },
                        onDraftDeleteTap: { draft in
                            deletingDraft = draft
                            showingDraftDeleteConfirm = true
                        }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }

            if isDecodingLibraryPhoto {
                CollectDecodingProgressOverlay()
            }

            if showingUploadOptions {
                SelectionModalView(
                    title: String.localized("capture.mode_select_title"),
                    subtitle: String.localized("capture.mode_select_subtitle"),
                    iconName: "square.and.arrow.up",
                    options: [
                        SelectionModalOption(
                            title: String.localized("capture.mode_select_photo_title" ),
                            subtitle: String.localized("capture.mode_select_photo_subtitle"),
                            systemImageName: "photo.on.rectangle"
                        ),
                        SelectionModalOption(
                            title: String.localized("capture.mode_select_file_title"),
                            subtitle: String.localized("capture.mode_select_file_subtitle"),
                            systemImageName: "folder"
                        )
                    ],
                    onCancel: {
                        showingUploadOptions = false
                    },
                    onSelect: { option in
                        showingUploadOptions = false
                        switch option.systemImageName {
                        case "photo.on.rectangle":
                            showingPhotoPicker = true
                        case "folder":
                            showingFileImporter = true
                        default:
                            break
                        }
                    }
                )
            }

            if showingDraftDeleteConfirm {
                ConfirmModalView(
                    title: String.localized("common.delete_confirm_title"),
                    message: String.localized("capture.draft_delete_message"),
                    iconName: "trash.fill",
                    cancelTitle: String.localized("common.cancel"),
                    confirmTitle: String.localized("common.delete"),
                    confirmColor: Color(red: 0.91, green: 0.26, blue: 0.21),
                    onCancel: {
                        showingDraftDeleteConfirm = false
                        deletingDraft = nil
                    },
                    onConfirm: {
                        let target = deletingDraft
                        showingDraftDeleteConfirm = false
                        deletingDraft = nil
                        if let target {
                            deleteDraft(target)
                        }
                    }
                )
            }
        }
        .onAppear {
//            if drafts.isEmpty {
                loadDrafts()
//            }
        }
        .onChange(of: env.session.isLoggedIn) { loggedIn in
            if loggedIn {
                loadDrafts()
            } else {
                drafts = []
                documentScannerPayload = nil
                showingUploadOptions = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .cloudDataDidRestore)) { _ in
            loadDrafts()
        }
        .fullScreenCover(isPresented: $showingScanner) {
            VisionDocumentCameraScanner { images in
                showingScanner = false
                documentScannerPayload = DocumentScannerPayload(images: images, isScan: true)
            } onCancel: {
                showingScanner = false
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(item: $documentScannerPayload, onDismiss: {
            documentScannerPayload = nil
            loadDrafts()
        }) { payload in
            CompatibleNavigationStack {
                DocumentScannerView(
                    initialImages: payload.images,
                    isScan: payload.isScan,
                    existingPage: payload.existingPage,
                    onDismiss: {
                        documentScannerPayload = nil
                        loadDrafts()
                    },
                    onComplete: { _ in
                        documentScannerPayload = nil
                        loadDrafts()
                    }
                )
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.image, .pdf],
            allowsMultipleSelection: false
        ) { result in
            handleFileImportResult(result)
        }
        .sheet(isPresented: $showingPhotoPicker) {
            PHPickerSheet(
                isPresented: $showingPhotoPicker,
                onDecodingStarted: { isDecodingLibraryPhoto = true }
            ) { img in
                isDecodingLibraryPhoto = false
                guard requireLogin() else { return }
                guard let img else { return }
                if selectedMode == .camera {
                    image = img
                    showingCropPicker = true
                } else {
                    documentScannerPayload = DocumentScannerPayload(images: [img], isScan: false)
                }
            }
        }
        .fullScreenCover(isPresented: $showingCropPicker) {
            ImageCropperView(
                image: $image,
                transformation: $transformation,
                cropInfo: $cropInfo,
                onDismiss: {
                    showingCropPicker = false
                },
                onCropCompleted: { status in
                    guard status == .succeeded, let cropped = image else { return }
                    documentScannerPayload = DocumentScannerPayload(images: [cropped], isScan: false)
                }
            )
        }
        .sheet(isPresented: $showingSystemCamera) {
            #if canImport(UIKit)
            SystemCameraPicker { capturedImage in
                showingSystemCamera = false
                guard let capturedImage else { return }
//                if selectedMode == .camera {
//                image = capturedImage
//                showingCropPicker = true
//                } else {
                    documentScannerPayload = DocumentScannerPayload(images: [capturedImage], isScan: false)
//                }
            }
            #else
            EmptyView()
            #endif
        }
        .alert("当前设备不支持文档扫描", isPresented: $showingScannerUnavailableAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("请在支持 VisionKit 的真机上使用扫描，或切换到相册 / 文件模式。")
        }
    }

    private func requireLogin() -> Bool {
        if env.session.isLoggedIn { return true }
        presentLogin()
        return false
    }

    private func loadDrafts() {
        Task {
            let part = try await env.documentStore.fetchNotebook(id: nil)
            await MainActor.run {
                drafts = part?.pages ?? []
            }
        }
    }

    /// 从 Recent Drafts 进入整理台，沿用同一草稿页 id 与备注 / 标签
    private func openDraftEditor(_ draft: NotebookPage) {
        guard requireLogin() else { return }
        let images = draft.images.compactMap { LocalImageLoader.loadUIImage(from: $0.url) }
        documentScannerPayload = DocumentScannerPayload(
            images: images,
            isScan: false,
            existingPage: draft
        )
    }

    private func deleteDraft(_ draft: NotebookPage) {
        Task {
            guard var book = try? await env.documentStore.fetchNotebook(id: nil) else { return }
            book.pages.removeAll { $0.id == draft.id }
            book.pages = book.pages.enumerated().map { index, page in
                var p = page
                p.sortIndex = index
                return p
            }
            book.updatedAt = Date()
            try? await env.documentStore.saveNotebook(book)
            await MainActor.run {
                drafts = book.pages
            }
        }
    }
    private func handleFileImportResult(_ result: Result<[URL], Error>) {
        guard requireLogin() else { return }
        if case .success(let urls) = result, let fileURL = urls.first {
            selectedFileURL = fileURL
            guard let type = UTType(filenameExtension: fileURL.pathExtension) else { return }
            #if canImport(UIKit)
            if type.conforms(to: .image),
               let data = try? Data(contentsOf: fileURL),
               let loaded = UIImage(data: data) {
                documentScannerPayload = DocumentScannerPayload(images: [loaded], isScan: false)
            } else if type == .pdf {
                #if canImport(PDFKit)
                var didStartAccess = false
                if fileURL.startAccessingSecurityScopedResource() {
                    didStartAccess = true
                }
                defer {
                    if didStartAccess {
                        fileURL.stopAccessingSecurityScopedResource()
                    }
                }

                if let document = PDFDocument(url: fileURL) {
                    var images: [UIImage] = []
                    let pageCount = document.pageCount
                    let targetSize = CGSize(width: 1200, height: 1600)
                    for index in 0..<pageCount {
                        guard let page = document.page(at: index) else { continue }
                        images.append(page.thumbnail(of: targetSize, for: .mediaBox))
                    }
                    if !images.isEmpty {
                        if selectedMode == .camera {
                            image = images.first
                            showingCropPicker = true
                        } else {
                            documentScannerPayload = DocumentScannerPayload(images: images, isScan: false)
                        }
                    }
                }
                #endif
            }
            #endif
        }
    }

    private func handleScanTap() {
        if selectedMode == .album {
            #if canImport(UIKit)
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                showingSystemCamera = true
            } else {
                showingScannerUnavailableAlert = true
            }
            #else
            showingScannerUnavailableAlert = true
            #endif
            return
        }
        guard documentScannerSupported else {
            showingScannerUnavailableAlert = true
            return
        }
        showingScanner = true
    }

    private var documentScannerSupported: Bool {
        #if canImport(VisionKit) && canImport(UIKit)
        return true
        #else
        return false
        #endif
    }
}

#if canImport(UIKit)
private struct SystemCameraPicker: UIViewControllerRepresentable {
    let onComplete: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onComplete: (UIImage?) -> Void

        init(onComplete: @escaping (UIImage?) -> Void) {
            self.onComplete = onComplete
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onComplete(nil)
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            let image = info[.originalImage] as? UIImage
            onComplete(image)
        }
    }
}
#endif
