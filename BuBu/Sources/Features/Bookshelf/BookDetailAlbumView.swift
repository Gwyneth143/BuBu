import SwiftUI

/// 翻页相册区域，从 BookDetailView 拆分出来，降低页面复杂度
struct BookDetailAlbumView: View {
    
    // 翻页动画状态
    enum FlipPhase {
        case idle
        case dragging
        case completing
        case cancelling
    }

    let notebook: Notebook      //册子信息
    let photos: [NotebookPage]  //册子的页面集
    @Binding var currentPage: NotebookPage? // 当前展示页

    private let pageWidth: CGFloat = UIScreen.main.bounds.width - 60       //册子宽度
    private let pageHeight: CGFloat = (UIScreen.main.bounds.width - 60)  * 1.414    //册子高度

    @State private var currentIndex: Int = 0        //当前页面index
    @State private var flipIndex: Int = 0             // 当前翻页index
    @State private var flipDirection: Int = 1       // 翻页方向： 1-下一页 -1-上一页
    @State private var flipAngle: Double = 0    // 翻页角度
    @State private var phase: FlipPhase = .idle //翻页状态
    @State private var showBackFace: Bool = false
    @State private var showFullPreview: Bool = false
    
    private var backFaceIndex: Int { currentIndex + flipDirection } //目标页面
    private var pastMidpoint: Bool { abs(flipAngle) > 90 }
    private var safeCurrentIndex: Int { min(max(currentIndex, 0), max(photos.count - 1, 0)) }
    private var safeFlipIndex: Int { min(max(flipIndex, 0), max(photos.count - 1, 0)) }

    private var shadowOpacity: Double {
        let a = abs(flipAngle).truncatingRemainder(dividingBy: 180)
        let t = a <= 90 ? a / 90.0 : (180.0 - a) / 90.0
        return t * 0.38
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                if photos.count > 0 {
                    ZStack {
                        pageStackView
                        // 目标页平放在下面
                        if showBackFace,
                           backFaceIndex >= 0, backFaceIndex < photos.count {
                            if flipDirection == 1 && phase == .completing {
                                AlbumPageView(
                                    photo: photos[backFaceIndex],
                                    pageNumber: backFaceIndex + 1,
                                    total: photos.count
                                )
                                .frame(width: pageWidth, height: pageHeight)
                            } else if safeFlipIndex + 1 < photos.count {
                                AlbumPageView(
                                    photo: photos[safeFlipIndex + 1],
                                    pageNumber: safeFlipIndex + 2,
                                    total: photos.count
                                )
                                .frame(width: pageWidth, height: pageHeight)
                            }
                        }
                        
                        // 翻页中的当前页（正反两面）
                        ZStack {
                            if !photos.isEmpty {
                                AlbumPageView(
                                    photo: photos[safeFlipIndex],
                                    pageNumber: safeFlipIndex + 1,
                                    total: photos.count
                                )
                                .frame(width: pageWidth, height: pageHeight)
                                .opacity(pastMidpoint ? 0 : 1)
                            }
                            
                            if backFaceIndex >= 0, backFaceIndex < photos.count {
                                AlbumPageView(
                                    photo: photos[backFaceIndex],
                                    pageNumber: backFaceIndex + 1,
                                    total: photos.count
                                )
                                .frame(width: pageWidth, height: pageHeight)
                                .rotation3DEffect(
                                    .degrees(180),
                                    axis: (x: 0, y: 1, z: 0),
                                    anchor: .center,
                                    perspective: 0
                                )
                                .opacity(pastMidpoint ? 1 : 0)
                            }
                        }
                        .frame(width: pageWidth, height: pageHeight)
                        .rotation3DEffect(
                            .degrees(flipAngle),
                            axis: (x: 0, y: 1, z: 0),
                            anchor: .leading,
                            perspective: 0.4
                        )
                        
                        if phase != .idle {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.black.opacity(shadowOpacity))
                                .frame(width: pageWidth, height: pageHeight)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(width: pageWidth, height: pageHeight)
                    .contentShape(Rectangle())
                    .gesture(dragGesture)
                    .onTapGesture {
                        showFullPreview = true
                    }
                    
                    if photos.count > 0 {
                        HStack(spacing: 40) {
                            Button { flipToPage(direction: -1) } label: {
                                Label("上一页", systemImage: "chevron.left")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(safeCurrentIndex > 0 && photos.count > 1
                                                     ? Color(red: 0.45, green: 0.30, blue: 0.18)
                                                     : Color(red: 0.75, green: 0.68, blue: 0.60))
                            }
                            .disabled(safeCurrentIndex == 0 || photos.count <= 1 || phase != .idle)
                            
                            Button { flipToPage(direction: 1) } label: {
                                Label("下一页", systemImage: "chevron.right")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(safeCurrentIndex < photos.count - 1
                                                     ? Color(red: 0.45, green: 0.30, blue: 0.18)
                                                     : Color(red: 0.75, green: 0.68, blue: 0.60))
                            }
                            .disabled(safeCurrentIndex >= photos.count - 1 || photos.count <= 1 || phase != .idle)
                        } .padding(.bottom, 16)
//                            .frame(height: 24)
                    }
                }
            }

        }
        .onAppear {
            if !photos.isEmpty {
                if let selectedID = currentPage?.id,
                   let selectedIndex = photos.firstIndex(where: { $0.id == selectedID }) {
                    currentIndex = selectedIndex
                    flipIndex = selectedIndex
                } else {
                    currentPage = photos[currentIndex]
                }
            }
        }
        .onChange(of: currentPage?.id) { pageID in
            guard phase == .idle,
                  let pageID,
                  let targetIndex = photos.firstIndex(where: { $0.id == pageID }),
                  targetIndex != currentIndex else { return }
            currentIndex = targetIndex
            flipIndex = targetIndex
            showBackFace = false
            flipAngle = 0
        }
        .onChange(of: photos.map(\.id)) { _ in
            guard !photos.isEmpty else {
                currentIndex = 0
                flipIndex = 0
                showBackFace = false
                flipAngle = 0
                phase = .idle
                currentPage = nil
                return
            }

            let safeIndex = min(max(currentIndex, 0), photos.count - 1)
            currentIndex = safeIndex
            flipIndex = min(max(flipIndex, 0), photos.count - 1)
            showBackFace = false
            flipAngle = 0
            phase = .idle

            if let selectedID = currentPage?.id,
               let selectedIndex = photos.firstIndex(where: { $0.id == selectedID }) {
                currentIndex = selectedIndex
                flipIndex = selectedIndex
            } else {
                currentPage = photos[safeIndex]
            }
        }
        .fullScreenCover(isPresented: $showFullPreview) {
            ZoomableAlbumPageView(
                photo: photos[currentIndex],
                pageNumber: currentIndex + 1,
                total: photos.count
            )
        }
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                let dx = value.translation.width
                if phase == .idle {
                    let dir = dx < 0 ? 1 : -1
                    let target = currentIndex + dir
                    guard target >= 0 && target < photos.count else { return }

                    flipDirection = dir
                    flipIndex = dir == 1 ? currentIndex : currentIndex - 1
                    showBackFace = true
                    phase = .dragging
                }

                guard phase == .dragging else { return }

                let raw = Double(-dx / pageWidth * 180) * Double(flipDirection)
                if flipDirection == 1 {
                    flipAngle = max(-180, min(0, raw))
                } else {
                    let angle = min(180, max(0, raw))
                    flipAngle = angle - 180
                }
            }
            .onEnded { value in
                guard phase == .dragging else { return }

                let predictedDx = value.predictedEndTranslation.width
                let currentDx = value.translation.width
                let progress = abs(flipAngle) / 180.0
                let predicted = abs(Double(predictedDx) / Double(pageWidth))

                let movingCorrect = flipDirection == 1 ? currentDx < 0 : currentDx > 0
                let shouldCommit = movingCorrect && (progress > 0.30 || predicted > 0.55)
                let velocityMag = abs(value.predictedEndTranslation.width - value.translation.width)

                if shouldCommit {
                    commitFlip(velocityMag: velocityMag)
                } else {
                    cancelFlip(velocityMag: velocityMag)
                }
            }
    }

    // MARK: - Flip helpers

    private func commitFlip(velocityMag: CGFloat) {
        phase = .completing
        let remaining = 180.0 - abs(flipAngle)
        let baseTime = remaining / 180.0 * 0.30
        let velFactor = max(0.35, 1.0 - Double(velocityMag) / Double(pageWidth * 2.5))
        let duration = max(0.08, baseTime * velFactor)

        let target: Double = flipDirection == 1 ? -180 : 0
        let destinationIndex = currentIndex + flipDirection

        withAnimation(.easeOut(duration: duration)) {
            flipAngle = target
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            showBackFace = false
            flipAngle = 0
            currentIndex = destinationIndex
            flipIndex = destinationIndex
            phase = .idle
            guard destinationIndex >= 0 && destinationIndex < photos.count else {
                showBackFace = false
                flipAngle = 0
                phase = .idle
                currentIndex = min(max(currentIndex, 0), max(photos.count - 1, 0))
                flipIndex = currentIndex
                if photos.indices.contains(currentIndex) {
                    currentPage = photos[currentIndex]
                } else {
                    currentPage = nil
                }
                return
            }
            currentPage = photos[destinationIndex]
        }
    }

    private func cancelFlip(velocityMag: CGFloat) {
        phase = .cancelling

        let remaining = abs(flipAngle)
        let baseTime = remaining / 180.0 * 0.26
        let velFactor = max(0.35, 1.0 - Double(velocityMag) / Double(pageWidth * 2.5))
        let duration = max(0.10, baseTime * velFactor)

        withAnimation(.spring(response: max(0.18, duration), dampingFraction: 0.75)) {
            flipAngle = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.08) {
            showBackFace = false
            phase = .idle
        }
    }

    private func flipToPage(direction: Int) {
        guard phase == .idle else { return }
        let destinationIndex = currentIndex + direction
        guard destinationIndex >= 0 && destinationIndex < photos.count else { return }

        flipDirection = direction
        showBackFace = true
        flipIndex = direction == 1 ? currentIndex : destinationIndex
        phase = .completing
        flipAngle = direction == 1 ? 0 : -180

        let half: Double = 0.17
        withAnimation(.easeIn(duration: half)) {
            flipAngle = -90
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + half) {
            withAnimation(.easeOut(duration: half)) {
                flipAngle = direction == 1 ? -180 : 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + half) {
                showBackFace = false
                flipAngle = 0
                guard destinationIndex >= 0 && destinationIndex < photos.count else {
                    phase = .idle
                    currentIndex = min(max(currentIndex, 0), max(photos.count - 1, 0))
                    flipIndex = currentIndex
                    if photos.indices.contains(currentIndex) {
                        currentPage = photos[currentIndex]
                    } else {
                        currentPage = nil
                    }
                    return
                }
                currentIndex = destinationIndex
                flipIndex = destinationIndex
                phase = .idle
                currentPage = photos[currentIndex]
            }
        }
    }

    //剩余的纸张
    private var pageStackView: some View {
        ZStack {
            let remaining = max(0, photos.count - currentIndex - 1)
            ForEach((0..<min(4, remaining)).reversed(), id: \.self) { i in
                RoundedRectangle(cornerRadius: 4)
                    .fill(AppTheme.Colors.shadowBlockColor)
                    .frame(width: pageWidth - CGFloat(i) * 0.5, height: pageHeight)
                    .offset(x: CGFloat(i + 1) * 1.5, y: CGFloat(i) * 0.3)
                    .shadow(color: AppTheme.Colors.shadowColor, radius: 10, x: 2, y: 2)
            }
        }
//        Rectangle()
//            .fill(AppTheme.Colors.shadowBlockColor)
//            .frame(width: pageWidth, height: pageHeight)
//            .offset(x: 4, y: 4)
//            .shadow(color: AppTheme.Colors.shadowColor, radius: 10, x: 2, y: 2)
    }

}

struct AlbumPageView: View {
    let photo: NotebookPage
    let pageNumber: Int
    let total: Int

    var body: some View {
        GeometryReader { _ in
            ZStack {
                Rectangle()
                    .fill(
                        Color.white
                    )
                albumImage
                VStack {
                    HStack {
                        Spacer()
                        Text("\(pageNumber) / \(total)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.top, 14)
                            .padding(.trailing, 16)
                    }
                    Spacer()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    @ViewBuilder
    private var albumImage: some View {
        if let asset = photo.images.first {
            if let uiImage = LocalImageLoader.loadUIImage(from: asset.url) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            } else if let source = asset.sourceIdentifier,
                      let remoteURL = URL(string: source),
                      let scheme = remoteURL.scheme?.lowercased(),
                      scheme == "http" || scheme == "https" {
                AsyncImage(url: remoteURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        AppImagePlaceholderView()
                    }
                }
                .frame(width: 200, height: 200)
            } else if let source = asset.sourceIdentifier, !source.isEmpty {
                Image(source)
                    .resizable()
                    .scaledToFill()
            } else {
                AppImagePlaceholderView()
                    .frame(width: 200, height: 200)
            }
        } else {
            AppImagePlaceholderView()
                .frame(width: 200, height: 200)
        }
    }
}

struct ZoomableAlbumPageView: View {
    let photo: NotebookPage
    let pageNumber: Int
    let total: Int

    @Environment(\.dismiss) private var dismiss
    @State private var baseScale: CGFloat = 1.0
    @State private var gestureScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            if let imageUrl = photo.images.first?.url {
                    ImagePreviewView(imageUrl: imageUrl)
            }
            
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color.gray.opacity(0.2))
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 12)
                }
                Spacer()
            }
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

