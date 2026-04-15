import SwiftUI

/// 全局选项弹框：样式与 `InputModalView` 保持一致，用于让用户从多个操作中做选择。
struct SelectionModalOption: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var subtitle: String?
    var systemImageName: String
}

struct SelectionModalView: View {
    var title: String
    var subtitle: String?
    var iconName: String = "square.grid.2x2"
    var cancelTitle: String = String.localized("common.cancel")
    var options: [SelectionModalOption]
    var onCancel: () -> Void
    var onSelect: (SelectionModalOption) -> Void

    private let modalPink = Color(hex: "FF5BA8")
    private let iconCirclePink = Color(hex: "FF5BA8").opacity(0.25)
    private let iconTint = Color(hex: "E91E63")
    private let borderGray = Color(hex: "E0E0E0")
    private let titleColor = Color(hex: "1A1A1A")
    private let subtitleColor = Color(hex: "5C5C5C")

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(spacing: 0) {
                // 顶部图标
                ZStack {
                    Circle()
                        .fill(iconCirclePink)
                        .frame(width: 56, height: 56)
                    Image(systemName: iconName)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundColor(iconTint)
                }
                .padding(.top, 28)
                .padding(.bottom, 16)

                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(titleColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                if let subtitle = subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(subtitleColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                }

                // 选项列表
                VStack(spacing: 10) {
                    ForEach(options) { option in
                        Button {
                            onSelect(option)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: option.systemImageName)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(modalPink)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.title)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(titleColor)

                                    if let subtitle = option.subtitle, !subtitle.isEmpty {
                                        Text(subtitle)
                                            .font(.system(size: 13, weight: .regular))
                                            .foregroundColor(subtitleColor)
                                    }
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(borderGray, lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                // 取消按钮
                Button(action: onCancel) {
                    Text(cancelTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(titleColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(borderGray, lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 24)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: 12)
            )
        }
    }
}

#Preview {
    struct SelectionModalPreviewWrapper: View {
        @State private var isShowing = true

        var body: some View {
            ZStack {
                Color.gray.opacity(0.1)
                    .ignoresSafeArea()

                if isShowing {
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
                                subtitle: "支持相册、文件 App、iCloud Drive 等",
                                systemImageName: "folder"
                            )
                        ],
                        onCancel: { isShowing = false },
                        onSelect: { _ in isShowing = false }
                    )
                }
            }
        }
    }

    return SelectionModalPreviewWrapper()
}

