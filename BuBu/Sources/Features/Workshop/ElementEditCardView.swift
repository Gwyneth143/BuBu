import SwiftUI

// MARK: - 编辑元素卡片（预览画布下方）

struct ElementEditCard: View {
    let itemId: UUID
    @Binding var items: [CanvasItem]
    let onDismiss: () -> Void

    private var index: Int? { items.firstIndex(where: { $0.id == itemId }) }
    private var item: CanvasItem? { index.map { items[$0] } }
//    private var currentColorHex: String {
//        guard let item = item else { return "333333" }
//        switch item.content {
//            case .sticker(let hex, _): return hex
//            case .text(_, _, let hex): return hex ?? "333333"
//            case .frame(_, let hex): return hex ?? "9C7A63"
//        }
//    }

//    private var isTextContent: Bool {
//        guard let item = item else { return false }
//        if case .text = item.content { return true }
//        return false
//    }

//    private var currentTextIsSerif: Bool {
//        guard let item = item, case .text(_, let isSerif, _) = item.content else { return true }
//        return isSerif
//    }

    private let colorOptions: [String] = [
        "DBEAFE", "FED7E2", "E9D5FF", "BBF7D0", "FEF3C7", "FED7AA"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("EDIT ELEMENT")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "374151"))
                    .tracking(0.5)

                Spacer()

                Button("Done") {
                    onDismiss()
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.blue)
                )
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("SIZE")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "6B7280"))
                    .tracking(0.5)
                Slider(value: bindingScale(), in: 0.5...2.0, step: 0.1)
                    .tint(.blue)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("ROTATION")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "6B7280"))
                    .tracking(0.5)
                Slider(value: bindingRotation(), in: 0...360, step: 5)
                    .tint(.blue)
            }

//            if isTextContent {
//                VStack(alignment: .leading, spacing: 6) {
//                    Text("FONT")
//                        .font(.system(size: 11, weight: .medium))
//                        .foregroundColor(Color(hex: "6B7280"))
//                        .tracking(0.5)
//                    HStack(spacing: 12) {
//                        fontOption(title: "Artistic Serif", isSerif: true)
//                        fontOption(title: "Minimalist Mono", isSerif: false)
//                    }
//                }
//            }

//            VStack(alignment: .leading, spacing: 6) {
//                Text("COLOR")
//                    .font(.system(size: 11, weight: .medium))
//                    .foregroundColor(Color(hex: "6B7280"))
//                    .tracking(0.5)
//                HStack(spacing: 12) {
//                    ForEach(colorOptions, id: \.self) { hex in
//                        Button {
//                            setColor(hex)
//                        } label: {
//                            Circle()
//                                .fill(Color(hex: hex))
//                                .frame(width: 40, height: 40)
//                                .overlay(
//                                    Circle()
//                                        .stroke(
//                                            currentColorHex.uppercased() == hex.uppercased() ? Color.blue : Color.clear,
//                                            lineWidth: 2.5
//                                        )
//                                )
//                        }
//                        .buttonStyle(.plain)
//                    }
//                }
//            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
        .padding(.horizontal, 20)
    }

    private func bindingScale() -> Binding<CGFloat> {
        Binding(
            get: { index.map { items[$0].scale } ?? 1 },
            set: { new in guard let i = index else { return }; items[i].scale = new }
        )
    }

    private func bindingRotation() -> Binding<Double> {
        Binding(
            get: { index.map { items[$0].rotationDegrees } ?? 0 },
            set: { new in guard let i = index else { return }; items[i].rotationDegrees = new }
        )
    }

//    private func setColor(_ hex: String) {
//        guard let i = index else { return }
//        switch items[i].content {
//        case .sticker(_, let systemImage):
//            items[i].content = .sticker(color: hex, systemImage: systemImage)
//        case .text(let string, let isSerif, _):
//            items[i].content = .text(string: string, isSerif: isSerif, colorHex: hex)
//        case .frame(let styleId, _):
//            items[i].content = .frame(styleId: styleId, strokeColorHex: hex)
//        }
//    }

//    @ViewBuilder
//    private func fontOption(title: String, isSerif: Bool) -> some View {
//        let isSelected = currentTextIsSerif == isSerif
//        Button {
//            setTextFont(isSerif: isSerif)
//        } label: {
//            Text(title)
//                .font(isSerif ? .system(size: 13, weight: .regular, design: .serif).italic() : .system(size: 13, weight: .medium))
//                .foregroundColor(isSelected ? .white : Color(hex: "6B7280"))
//                .lineLimit(1)
//                .padding(.horizontal, 14)
//                .padding(.vertical, 10)
//                .frame(maxWidth: .infinity)
//                .background(
//                    RoundedRectangle(cornerRadius: 14)
//                        .fill(isSelected ? Color.blue : Color(hex: "F3F4F6"))
//                )
//        }
//        .buttonStyle(.plain)
//    }
//
//    private func setTextFont(isSerif: Bool) {
//        guard let i = index else { return }
//        if case .text(let string, _, let colorHex) = items[i].content {
//            items[i].content = .text(string: string, isSerif: isSerif, colorHex: colorHex)
//        }
//    }
}
