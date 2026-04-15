import SwiftUI

// MARK: - 画板层

struct CanvasLayer: View {
    let items: [CanvasItem]
    let previewSize: CGSize
    let onPositionChange: (UUID, CGPoint) -> Void
    let onDelete: (UUID) -> Void
    let onLongPress: (UUID) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(items) { item in
                DraggableCanvasItem(
                    item: item,
                    previewSize: previewSize,
                    onPositionChange: onPositionChange,
                    onDelete: onDelete,
                    onLongPress: onLongPress
                )
            }
        }
        .frame(width: previewSize.width, height: previewSize.height)
    }
}

// MARK: - 可拖拽画布元素

struct DraggableCanvasItem: View {
    let item: CanvasItem
    let previewSize: CGSize
    let onPositionChange: (UUID, CGPoint) -> Void
    let onDelete: (UUID) -> Void
    let onLongPress: (UUID) -> Void
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        canvasContent(for: item.content)
            .scaleEffect(item.scale)
            .rotationEffect(.degrees(item.rotationDegrees))
            .position(
                x: item.position.x + dragOffset.width,
                y: item.position.y + dragOffset.height
            )
            .onLongPressGesture {
                onLongPress(item.id)
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        let newX = item.position.x + value.translation.width
                        let newY = item.position.y + value.translation.height
                        let newPosition = CGPoint(x: newX, y: newY)
                        let (halfW, halfH) = halfSize(for: item.content, scale: item.scale)
                        let fullyOut = (newX - halfW > previewSize.width) || (newX + halfW < 0)
                            || (newY - halfH > previewSize.height) || (newY + halfH < 0)
                        if fullyOut {
                            onDelete(item.id)
                        } else {
                            onPositionChange(item.id, newPosition)
                        }
                        dragOffset = .zero
                    }
            )
    }

    private func halfSize(for content: CanvasContent, scale: CGFloat = 1) -> (CGFloat, CGFloat) {
        let base: (CGFloat, CGFloat)
        switch content {
        case .sticker: base = (22, 22)
        case .text: base = (50, 12)
        case .frame: base = (40, 50)
        case .image: base = (22, 22)
        }
        return (base.0 * scale, base.1 * scale)
    }

    @ViewBuilder
    private func canvasContent(for content: CanvasContent) -> some View {
        switch content {
        case .sticker(let colorHex, let systemImage):
            Circle()
                .fill(Color(hex: colorHex))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black.opacity(0.6))
                )
        case .text(let string, let isSerif, let colorHex):
            Text(string)
                .font(isSerif ? .system(size: 16, weight: .regular, design: .serif) : .system(size: 14, weight: .medium))
                .foregroundColor(colorHex.flatMap { Color(hex: $0) } ?? .black.opacity(0.85))
                .lineLimit(2)
        case .frame(let styleId, let strokeColorHex):
            RoundedRectangle(cornerRadius: styleId == 0 ? 12 : 20)
                .stroke(Color(hex: strokeColorHex ?? "9C7A63"), lineWidth: 3)
                .frame(width: 80, height: 100)
        case .image(let imageStr):
            Image(imageStr)
                .frame(width: 36,height: 36)
                .scaledToFill()
        }
    }
}
