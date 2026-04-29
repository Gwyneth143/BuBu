import SwiftUI

// MARK: - 画布元素模型

enum CanvasContent: Equatable {
//    case sticker(color: String, systemImage: String)
//    case text(string: String, isSerif: Bool, colorHex: String?)
//    case frame(styleId: Int, strokeColorHex: String?)
    case sticker(imageStr: String)
    case text(imageStr: String)
//    case image(imageStr: String)
}

struct CanvasItem: Identifiable, Equatable {
    let id: UUID
    var position: CGPoint
    var content: CanvasContent
    var scale: CGFloat
    var rotationDegrees: Double

    init(id: UUID, position: CGPoint, content: CanvasContent, scale: CGFloat = 1, rotationDegrees: Double = 0) {
        self.id = id
        self.position = position
        self.content = content
        self.scale = scale
        self.rotationDegrees = rotationDegrees
    }

    static func == (lhs: CanvasItem, rhs: CanvasItem) -> Bool {
        lhs.id == rhs.id && lhs.position == rhs.position && lhs.content == rhs.content
            && lhs.scale == rhs.scale && lhs.rotationDegrees == rhs.rotationDegrees
    }
}

// MARK: - 预览尺寸常量

enum CoverEditorLayout {
    static let previewWidth: CGFloat = UIScreen.main.bounds.width - 120
    static let previewHeight: CGFloat =  previewWidth*1.414
}
