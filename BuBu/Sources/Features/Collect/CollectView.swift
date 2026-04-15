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
    @State private var image: UIImage?
    @State private var transformation: Transformation?
    @State private var cropInfo: CropInfo?
    @State private var isDecodingLibraryPhoto = false
    @State private var drafts:[NotebookPage] = []

//    private let : [CollectDraft] = [
//        .init(title: "\"The first heartbeat…\"", tag: "READ TEXT"),
//        .init(title: "May 14th – Week 20", tag: "SNAP")
//    ]

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
                        onDraftTagTap: { draft in
                            if draft.tag == "SNAP" {
                                Task { await viewModel.analyzeDummyImage() }
                            }
                        },
                        onDraftTap: { draft in
                            openDraftEditor(draft)
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
                    title: "选择上传方式",
                    subtitle: "你可以从相册或文件中选择要识别的单据。",
                    iconName: "square.and.arrow.up",
                    options: [
                        SelectionModalOption(
                            title: "从相册选取",
                            subtitle: "支持最近拍摄的照片、截图等",
                            systemImageName: "photo.on.rectangle"
                        ),
                        SelectionModalOption(
                            title: "从文件选取",
                            subtitle: "支持文件 App、iCloud Drive 等",
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
        }
        .onAppear {
            if drafts.isEmpty {
                loadDrafts()
            }
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
        .alert("当前设备不支持文档扫描", isPresented: $showingScannerUnavailableAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("请在支持 VisionKit 的真机上使用扫描，或切换到相册 / 文件模式。")
        }
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
        let images = draft.images.compactMap { LocalImageLoader.loadUIImage(from: $0.url) }
        documentScannerPayload = DocumentScannerPayload(
            images: images,
            isScan: false,
            existingPage: draft
        )
    }
    private func handleFileImportResult(_ result: Result<[URL], Error>) {
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
