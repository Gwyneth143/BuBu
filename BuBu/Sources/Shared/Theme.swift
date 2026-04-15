import SwiftUI

enum AppTheme {
    static let accentColor = Color("AccentColor", bundle: .main)

    struct Colors {
        /// 应用通用背景色（如书架页浅米色背景）
        static let appBackground = Color(red: 1.0, green: 0.97, blue: 0.94)
        /// 书架木板颜色
        static let shelfWood = Color(red: 0.93, green: 0.76, blue: 0.63)
        /// 通用卡片 / 搜索框背景
        static let cardBackground = Color.white
        /// Tab 选中高亮（粉色）
        static let tabHighlight = Color.init(hex: "FF7EB6")
        /// 分割线颜色
        static let divider = Color.gray.opacity(0.2)
    }

    struct Fonts {
        static let title = Font.system(size: 24, weight: .bold, design: .rounded)
        static let sectionTitle = Font.system(size: 18, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 15, weight: .regular, design: .rounded)
        static let bookshelfTitle = Font.system(size: 20, weight: .heavy, design: .rounded)
    }

    struct Gradients {
        private static let start = Color(hex: "FFFFFF")

        /// 蓝色
        static let blue = LinearGradient(
            colors: [start, Color(hex: "3994EF")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// 橙色
        static let orange = LinearGradient(
            colors: [start, Color(hex: "FDBA74")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// 绿色薄荷
        static let mint = LinearGradient(
            colors: [start, Color(hex: "6EE7B7")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// 紫色
        static let purple = LinearGradient(
            colors: [start, Color(hex: "C084FC")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// 黄色
        static let yellow = LinearGradient(
            colors: [start, Color(hex: "FFCC00")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// 粉色
        static let pink = LinearGradient(
            colors: [start, Color(hex: "FFD1DC")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// 鲜绿色
        static let green = LinearGradient(
            colors: [start, Color(hex: "33CC00")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let all: [LinearGradient] = [blue, orange, mint, purple, yellow, pink, green]
    }
}

extension Color {
    /// 通过 16 进制字符串创建颜色，例如 "#FFCC00"、"FFCC00"、"0xFFCC00"
    init(hex: String, alpha: Double = 1.0) {
        let cleaned = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "0x", with: "")
            .uppercased()

        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)

        let r, g, b: Double
        switch cleaned.count {
        case 6:
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
        case 3:
            // 像 "F0A" 这种简写
            let r4 = (rgb & 0xF00) >> 8
            let g4 = (rgb & 0x0F0) >> 4
            let b4 = rgb & 0x00F
            r = Double((r4 << 4) | r4) / 255.0
            g = Double((g4 << 4) | g4) / 255.0
            b = Double((b4 << 4) | b4) / 255.0
        default:
            r = 1.0; g = 1.0; b = 1.0
        }

        self.init(red: r, green: g, blue: b, opacity: alpha)
    }
}

// MARK: - 四角圆角

/// iOS 15 下替代 `UnevenRoundedRectangle` 的不对称圆角矩形
private struct AsymmetricRoundedRectangle: Shape {
    var topLeading: CGFloat
    var topTrailing: CGFloat
    var bottomLeading: CGFloat
    var bottomTrailing: CGFloat

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let tl = min(topLeading, w / 2, h / 2)
        let tr = min(topTrailing, w / 2, h / 2)
        let bl = min(bottomLeading, w / 2, h / 2)
        let br = min(bottomTrailing, w / 2, h / 2)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + tr), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - br, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - bl), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addQuadCurve(to: CGPoint(x: rect.minX + tl, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

extension View {
    /// 为四个角分别指定圆角半径（未指定的角为 0）。
    /// - Parameters:
    ///   - topLeading: 左上
    ///   - topTrailing: 右上
    ///   - bottomLeading: 左下
    ///   - bottomTrailing: 右下
    @ViewBuilder
    func cornerRadius(
        topLeading: CGFloat = 0,
        topTrailing: CGFloat = 0,
        bottomLeading: CGFloat = 0,
        bottomTrailing: CGFloat = 0
    ) -> some View {
        if #available(iOS 16.0, *) {
            clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: topLeading,
                    bottomLeadingRadius: bottomLeading,
                    bottomTrailingRadius: bottomTrailing,
                    topTrailingRadius: topTrailing
                )
            )
        } else {
            clipShape(
                AsymmetricRoundedRectangle(
                    topLeading: topLeading,
                    topTrailing: topTrailing,
                    bottomLeading: bottomLeading,
                    bottomTrailing: bottomTrailing
                )
            )
        }
    }
}
