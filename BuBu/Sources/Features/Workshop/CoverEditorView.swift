import SwiftUI
import UIKit

/// DIY 册子封面编辑器：画板支持 stickers / text / frames / BG，可拖拽
struct CoverEditorView: View {
//    @State private var title: String = "My Journal"
    @State private var selectedTab: EditorTab = .sticker
    @State private var canvasItems: [CanvasItem] = []
    @State private var coverBackground: Color = Color(hex: "D7C8C2")
    @State private var coverBackImage: String?
    @State private var editingItemId: UUID?
    @State private var showingFinishConfirmation = false
    @State private var uploadErrorMessage: String?
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.tabBarHidden) private var tabBarHidden

    private enum EditorTab: String, CaseIterable {
        case sticker = "贴画"
        case text = "文字"
        case bg = "背景"
    }

    var body: some View {
        ZStack {
            AppTheme.Colors.appBackground
                .ignoresSafeArea()

            VStack(spacing: 24) {
                coverPreview
                editorTabs
                editorPanel
                Spacer()
            }
        }
        .overlay(alignment: .top) {
            if let id = editingItemId {
                editCardOverlay(itemId: id)
            }
        }
        .navigationTitle("DIY Cover")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(String.localized("cover.edit.done")) {
                    showingFinishConfirmation = true
                }
            }
        }
        .alert(String.localized("cover.finish_confirm_title"), isPresented: $showingFinishConfirmation) {
            Button(String.localized("common.cancel"), role: .cancel) {}
            Button(String.localized("common.confirm")) {
                Task { await saveCanvasAsImage() }
            }
        } message: {
            Text(String.localized("cover.finish_confirm_message"))
        }
        .alert("上传失败", isPresented: Binding(
            get: { uploadErrorMessage != nil },
            set: { if !$0 { uploadErrorMessage = nil } }
        )) {
            Button("确定", role: .cancel) { uploadErrorMessage = nil }
        } message: {
            Text(uploadErrorMessage ?? "")
        }
        .onAppear {
            tabBarHidden?.wrappedValue = true
        }
        .onDisappear {
            tabBarHidden?.wrappedValue = false
        }
    }

    // MARK: - 编辑卡片遮罩

    private func editCardOverlay(itemId: UUID) -> some View {
        let canvasBlockHeight: CGFloat = CoverEditorLayout.previewHeight + 80

        return ZStack(alignment: .top) {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { }

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: canvasBlockHeight)
                ElementEditCard(
                    itemId: itemId,
                    items: $canvasItems,
                    onDismiss: { withAnimation(.easeInOut(duration: 0.2)) { editingItemId = nil } }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
                Spacer(minLength: 0)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: editingItemId?.uuidString ?? "")
    }

    // MARK: - 预览区

    private var coverPreview: some View {
            VStack(spacing: 8) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 0)
                        .fill(coverBackground)
                        .frame(width: CoverEditorLayout.previewWidth, height: CoverEditorLayout.previewHeight)
                        .shadow(color: Color.black.opacity(0.15), radius: 14, x: 0, y: 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 32)
                                .stroke(Color.black.opacity(0.06), lineWidth: 1)
                        )
                    if let image = coverBackImage {
                        Image(image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: CoverEditorLayout.previewWidth, height: CoverEditorLayout.previewHeight)
                            .clipped()
                    }
                    CanvasLayer(
                        items: canvasItems,
                        previewSize: CGSize(width: CoverEditorLayout.previewWidth, height: CoverEditorLayout.previewHeight),
                        onPositionChange: updateItemPosition,
                        onDelete: removeItem,
                        onLongPress: { id in withAnimation(.easeInOut(duration: 0.25)) { editingItemId = id } }
                    )
                }
                .frame(width: CoverEditorLayout.previewWidth, height: CoverEditorLayout.previewHeight)
                
                Text("LIVE PREVIEW")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .tracking(2)
                
                Text("拖出画布外可删除元素")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.9))
                    .padding(.top, 4)
            }
    }

    // MARK: - 画布数据操作

    private func updateItemPosition(id: UUID, newPosition: CGPoint) {
        guard let i = canvasItems.firstIndex(where: { $0.id == id }) else { return }
        canvasItems[i].position = newPosition
    }

    private func removeItem(id: UUID) {
        canvasItems.removeAll { $0.id == id }
    }
    
    private func addItem(image: String) {
        canvasItems.append(CanvasItem(
            id: UUID(),
            position: CGPoint(x: CoverEditorLayout.previewWidth * 0.5, y: CoverEditorLayout.previewHeight * 0.5),
            content: .image(imageStr: image)
        ))
    }

    private func addSticker(colorHex: String, systemImage: String) {
        canvasItems.append(CanvasItem(
            id: UUID(),
            position: CGPoint(x: CoverEditorLayout.previewWidth * 0.5, y: CoverEditorLayout.previewHeight * 0.5),
            content: .sticker(color: colorHex, systemImage: systemImage)
        ))
    }

    private func addText(string: String, isSerif: Bool) {
        canvasItems.append(CanvasItem(
            id: UUID(),
            position: CGPoint(x: CoverEditorLayout.previewWidth * 0.5, y: CoverEditorLayout.previewHeight * 0.45),
            content: .text(string: string, isSerif: isSerif, colorHex: nil)
        ))
    }

    private func addFrame(styleId: Int) {
        canvasItems.append(CanvasItem(
            id: UUID(),
            position: CGPoint(x: CoverEditorLayout.previewWidth * 0.5, y: CoverEditorLayout.previewHeight * 0.5),
            content: .frame(styleId: styleId, strokeColorHex: nil)
        ))
    }

    private func setBackground(_ image: String) {
        coverBackImage = image
    }

    /// 将预览画布渲染为图片，写入本地 `Documents/covers/`，并 `multipart` 上传至 `POST /skins`
    @MainActor
    private func saveCanvasAsImage() async {
        guard let image = snapshotCanvasUIImage(), let pngData = image.pngData() else { return }

        let fileName = "cover_\(UUID().uuidString).png"
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("covers", isDirectory: true) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let fileURL = dir.appendingPathComponent(fileName)
            try? pngData.write(to: fileURL)
        }

        guard let creatorId = env.session.serverUserId, creatorId > 0 else {
            uploadErrorMessage = CoverStoreError.missingServerUserId.localizedDescription
            return
        }

        do {
            try await env.coverStore.uploadSkinImage(
                fileData: pngData,
                fileName: fileName,
                displayName: "diy skin",
                type: 2,
                creatorUserId: creatorId
            )
            dismiss()
        } catch {
            uploadErrorMessage = error.localizedDescription
        }
    }

    /// iOS 16+ 使用 `ImageRenderer`；更早系统用 `UIHostingController` + 位图渲染
    @MainActor
    private func snapshotCanvasUIImage() -> UIImage? {
        let view = canvasSnapshotView
        if #available(iOS 16.0, *) {
            let renderer = ImageRenderer(content: view)
            renderer.scale = UIScreen.main.scale
            return renderer.uiImage
        } else {
            let hosting = UIHostingController(rootView: view)
            let size = CGSize(width: CoverEditorLayout.previewWidth, height: CoverEditorLayout.previewHeight)
            hosting.view.bounds = CGRect(origin: .zero, size: size)
            hosting.view.backgroundColor = .clear
            let format = UIGraphicsImageRendererFormat()
            format.scale = UIScreen.main.scale
            format.opaque = false
            let bitmap = UIGraphicsImageRenderer(size: size, format: format)
            return bitmap.image { ctx in
                hosting.view.layoutIfNeeded()
                hosting.view.layer.render(in: ctx.cgContext)
            }
        }
    }

    /// 仅用于渲染的画布视图（无手势）
    private var canvasSnapshotView: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 0)
                .fill(coverBackground)
                .frame(width: CoverEditorLayout.previewWidth, height: CoverEditorLayout.previewHeight)
            if let image = coverBackImage {
                Image(image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: CoverEditorLayout.previewWidth, height: CoverEditorLayout.previewHeight)
                    .clipped()
            }
            CanvasLayer(
                items: canvasItems,
                previewSize: CGSize(width: CoverEditorLayout.previewWidth, height: CoverEditorLayout.previewHeight),
                onPositionChange: { _, _ in },
                onDelete: { _ in },
                onLongPress: { _ in }
            )
        }
        .frame(width: CoverEditorLayout.previewWidth, height: CoverEditorLayout.previewHeight)
    }

    // MARK: - 编辑 Tabs

    private var editorTabs: some View {
        HStack(spacing: 0) {
            ForEach(EditorTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(
                            selectedTab == tab
                            ? Color.white
                            : .secondary
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selectedTab == tab ? Color.blue : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.95))
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 32)
    }

    // MARK: - 编辑面板

    private var editorPanel: some View {
        ScrollView {
            VStack(spacing: 12) {
                switch selectedTab {
                case .sticker:
                    stickerGrid
                case .text:
                    textGrid
                case .bg:
                    bgGrid
                }
            }
            .padding(.horizontal, 20)
            // ScrollView 默认按子视图最小宽度排版，不设满宽时 LazyVGrid 不会按屏宽分栏，padding/列间距会失效
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 三列等分，列与列之间 18pt（由 GridItem.spacing 控制）
    private static let textGridColumns: [GridItem] = [
        GridItem(.flexible(), spacing: 18, alignment: .center),
        GridItem(.flexible(), spacing: 18, alignment: .center),
        GridItem(.flexible(), spacing: 0, alignment: .center)
    ]
    
    private var stickerGrid: some View {
        let options = (1...20).map { "skin_sticker_\($0)" }
        let cols: [GridItem] = [
            GridItem(.flexible(), spacing: 18, alignment: .center),
            GridItem(.flexible(), spacing: 18, alignment: .center),
            GridItem(.flexible(), spacing: 18, alignment: .center),
            GridItem(.flexible(), spacing: 0, alignment: .center)
        ]
        return LazyVGrid(columns: cols, alignment: .leading, spacing: 18) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, image in
                Button {
                    addItem(image: image)
                } label: {
                    ZStack {
                        Image(image)
                            .resizable()
                            .scaledToFill()
                    }
                    .padding(16)
                    .aspectRatio(1.0, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 0)
                            .fill(Color.white.opacity(0.9))
                    )
                    .clipped()
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var textGrid: some View {
        let options = (1...10).map { "skin_text_\($0)" }
        return LazyVGrid(columns: Self.textGridColumns, alignment: .leading, spacing: 18) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, image in
                Button {
                    addItem(image: image)
                } label: {
                    ZStack {
                        Image(image)
                            .resizable()
                            .scaledToFill()
                    }
                    .padding(16)
                    .aspectRatio(2.0, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 0)
                            .fill(Color.white.opacity(0.9))
                    )
                    .clipped()
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var bgGrid: some View {
        let options = (1...6).map { "skin_bg_\($0)" }
        return LazyVGrid(columns: Self.textGridColumns, alignment: .leading, spacing: 18) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, image in
                Button {
                    setBackground(image)
                } label: {
                    Image(image)
                        .resizable()
                        .scaledToFill()
                        .aspectRatio(1.0 / 1.414, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipped()
                }
                .buttonStyle(.plain)
            }
        }
    }
}

