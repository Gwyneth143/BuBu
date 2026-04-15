#if canImport(UIKit)
import SwiftUI
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// 单页扫描图片编辑：手动裁剪框、旋转、涂抹遮挡、滤镜（B&W / Photo / Magic）
struct ScanImageEditorView: View {
    enum FilterMode: String, CaseIterable, Identifiable {
        case photo
        case bw
        case magic

        var id: String { rawValue }

        var title: String {
            switch self {
            case .photo: return "全彩"
            case .bw: return "黑白"
            case .magic: return "魔术增强"
            }
        }
    }

    let image: UIImage
    var onCancel: () -> Void
    var onSave: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    // 旋转 & 滤镜
    @State private var rotationSteps: Int = 0
    @State private var filterMode: FilterMode = .photo
    @State private var freeRotation: Angle = .zero
    @State private var rotationGesture: Angle = .zero

    // 缩放（用于两指放大缩小预览）
    @State private var baseScale: CGFloat = 1.0
    @State private var scaleGesture: CGFloat = 1.0

    // 裁剪框（使用相对比例的 rect，0...1）
    @State private var cropRect: CGRect = CGRect(x: 0.08, y: 0.08, width: 0.84, height: 0.84)
    @State private var previewSize: CGSize = .zero

    // 涂抹遮挡
    @State private var isSmudging = false
    @State private var currentStroke: [CGPoint] = []
    @State private var strokes: [[CGPoint]] = []

    private let context = CIContext()

    var body: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                GeometryReader { proxy in
                    let size = proxy.size
                    let pinch = MagnificationGesture()
                        .onChanged { value in
                            guard !isSmudging else { return }
                            scaleGesture = value
                        }
                        .onEnded { value in
                            guard !isSmudging else { return }
                            baseScale = (baseScale * value).clamped(to: 0.5...3.0)
                            scaleGesture = 1.0
                        }

                    let rotate = RotationGesture()
                        .onChanged { angle in
                            guard !isSmudging else { return }
                            rotationGesture = angle
                        }
                        .onEnded { angle in
                            guard !isSmudging else { return }
                            freeRotation = freeRotation + angle
                            rotationGesture = .zero
                        }

                    ZStack {
                        // 更新预览尺寸
                        Color.clear
                            .onAppear { previewSize = size }
                            .onChange(of: size) { newValue in
                                previewSize = newValue
                            }

                        // 原图（只用于定位）
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(baseScale * scaleGesture)
                            .rotationEffect(.degrees(Double(rotationSteps) * 90) + freeRotation + rotationGesture)
                            .frame(width: size.width, height: size.height)

                        // 裁剪框 + 灰色蒙层
                        cropOverlay(in: size)

                        // 涂抹层
                        smudgeLayer(in: size)
                    }
                    .gesture(pinch.simultaneously(with: rotate))
                }

                editorControls
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
        .navigationTitle("编辑扫描")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    onCancel()
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("完成") {
                    let output = generateEditedImage()
                    onSave(output)
                    dismiss()
                }
            }
        }
    }

    // MARK: - 裁剪蒙层

    private func cropOverlay(in size: CGSize) -> some View {
        let rect = CGRect(
            x: cropRect.minX * size.width,
            y: cropRect.minY * size.height,
            width: cropRect.width * size.width,
            height: cropRect.height * size.height
        )

        return ZStack {
            // 外层蒙层 + 裁剪窗口
            Color.black.opacity(0.45)
                .mask(
                    ZStack {
                        Rectangle()
                            .fill(Color.black)
                        Rectangle()
                            .path(in: rect)
                            .fill(Color.clear)
                            .compositingGroup()
                            .blendMode(.destinationOut)
                    }
                )

            // 裁剪框边框 + 拖拽
            Rectangle()
                .path(in: rect)
                .stroke(Color.white, lineWidth: 2)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let dx = value.translation.width / size.width
                            let dy = value.translation.height / size.height
                            cropRect.origin.x = (cropRect.origin.x + dx)
                                .clamped(to: 0...(1 - cropRect.width))
                            cropRect.origin.y = (cropRect.origin.y + dy)
                                .clamped(to: 0...(1 - cropRect.height))
                        }
                        .onEnded { _ in }
                )
        }
    }

    // MARK: - 涂抹层

    private func smudgeLayer(in size: CGSize) -> some View {
        Canvas { context, _ in
            let color = Color.black
            let lineWidth: CGFloat = 24

            func drawStroke(_ stroke: [CGPoint]) {
                guard stroke.count > 1 else { return }
                var path = Path()
                path.move(to: stroke[0])
                for p in stroke.dropFirst() {
                    path.addLine(to: p)
                }
                context.stroke(path, with: .color(color), lineWidth: lineWidth)
            }

            for stroke in strokes {
                drawStroke(stroke)
            }
            drawStroke(currentStroke)
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    guard isSmudging else { return }
                    currentStroke.append(value.location)
                }
                .onEnded { _ in
                    guard isSmudging else { return }
                    strokes.append(currentStroke)
                    currentStroke = []
                }
        )
    }

    // MARK: - 控件区域

    private var editorControls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 16) {
                // 左旋
                Button {
                    withAnimation(.easeInOut) {
                        rotationSteps = (rotationSteps - 1).modulo(4)
                    }
                } label: {
                    Image(systemName: "rotate.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.white.opacity(0.18)))
                }
                .buttonStyle(.plain)

                // 右旋
                Button {
                    withAnimation(.easeInOut) {
                        rotationSteps = (rotationSteps + 1).modulo(4)
                    }
                } label: {
                    Image(systemName: "rotate.right")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.white.opacity(0.18)))
                }
                .buttonStyle(.plain)

                // 涂抹开关
                Button {
                    withAnimation(.easeInOut) {
                        isSmudging.toggle()
                    }
                } label: {
                    Image(systemName: "hand.draw.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isSmudging ? .black : .white.opacity(0.85))
                        .frame(width: 44, height: 44)
                        .background(
                            Circle().fill(isSmudging ? Color.white : Color.white.opacity(0.18))
                        )
                }
                .buttonStyle(.plain)

                Spacer()
            }

            // 滤镜选择
            HStack(spacing: 8) {
                ForEach(FilterMode.allCases) { mode in
                    Button {
                        withAnimation(.easeInOut) {
                            filterMode = mode
                        }
                    } label: {
                        Text(mode.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(filterMode == mode ? .black : .white.opacity(0.8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(filterMode == mode ? Color.white : Color.white.opacity(0.2))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 导出编辑后的图片

    private func generateEditedImage() -> UIImage {
        var base = image

        // 1. 裁剪（按照 cropRect）
        if let cg = base.cgImage {
            let width = CGFloat(cg.width)
            let height = CGFloat(cg.height)
            let crop = CGRect(
                x: cropRect.minX * width,
                y: cropRect.minY * height,
                width: cropRect.width * width,
                height: cropRect.height * height
            ).integral
            if let cropped = cg.cropping(to: crop) {
                base = UIImage(cgImage: cropped, scale: base.scale, orientation: base.imageOrientation)
            }
        }

        // 2. 旋转（90° 步进）
        if let cg = base.cgImage {
            let orientation: UIImage.Orientation
            switch rotationSteps.modulo(4) {
            case 1: orientation = .right
            case 2: orientation = .down
            case 3: orientation = .left
            default: orientation = .up
            }
            base = UIImage(cgImage: cg, scale: base.scale, orientation: orientation)
        }

        // 3. 滤镜
        switch filterMode {
        case .photo:
            break
        case .bw:
            base = applyBWFilter(to: base) ?? base
        case .magic:
            base = applyMagicFilter(to: base) ?? base
        }

        // 4. 涂抹遮挡：将 strokes 画到最终图片上
        if !strokes.isEmpty, previewSize.width > 0, previewSize.height > 0 {
            UIGraphicsBeginImageContextWithOptions(base.size, true, base.scale)
            base.draw(in: CGRect(origin: .zero, size: base.size))

            guard let ctx = UIGraphicsGetCurrentContext() else {
                UIGraphicsEndImageContext()
                return base
            }

            ctx.setLineWidth(32)
            ctx.setLineCap(.round)
            ctx.setStrokeColor(UIColor.black.cgColor)

            let scaleX = base.size.width / previewSize.width
            let scaleY = base.size.height / previewSize.height

            func drawStroke(_ stroke: [CGPoint]) {
                guard stroke.count > 1 else { return }
                ctx.beginPath()
                let first = stroke[0]
                ctx.move(to: CGPoint(x: first.x * scaleX, y: first.y * scaleY))
                for p in stroke.dropFirst() {
                    ctx.addLine(to: CGPoint(x: p.x * scaleX, y: p.y * scaleY))
                }
                ctx.strokePath()
            }

            for stroke in strokes {
                drawStroke(stroke)
            }
            drawStroke(currentStroke)

            if let final = UIGraphicsGetImageFromCurrentImageContext() {
                base = final
            }
            UIGraphicsEndImageContext()
        }

        return base
    }

    // MARK: - 滤镜实现

    private func applyBWFilter(to image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let filter = CIFilter.photoEffectNoir()
        filter.inputImage = ciImage
        guard let output = filter.outputImage,
              let cgImage = context.createCGImage(output, from: output.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    private func applyMagicFilter(to image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        // 轻度提亮 + 增强对比度和饱和度，模拟“魔术增强”
        let exposure = CIFilter.exposureAdjust()
        exposure.inputImage = ciImage
        exposure.ev = 0.4

        let contrasted = CIFilter.colorControls()
        contrasted.inputImage = exposure.outputImage
        contrasted.brightness = 0.02
        contrasted.contrast = 1.18
        contrasted.saturation = 1.08

        guard let output = contrasted.outputImage,
              let cgImage = context.createCGImage(output, from: output.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

private extension Int {
    func modulo(_ n: Int) -> Int {
        let r = self % n
        return r >= 0 ? r : r + n
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

#endif

