import SwiftUI

/// 按设计稿的全局输入弹框：圆角白底、顶部图标、标题/副标题、单行输入、取消/确认按钮。
struct InputModalView: View {
    var title: String
    var subtitle: String?
    var inputLabel: String
    var placeholder: String
    @Binding var text: String
    var cancelTitle: String = "Cancel"
    var confirmTitle: String = "Confirm"
    var iconName: String = "folder"
    var confirmDisabled: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var onCancel: () -> Void
    var onConfirm: () -> Void

    @FocusState private var isInputFocused: Bool

//    private let modalPink = Color(hex: "FF5BA8")
//    private let iconCirclePink = Color(hex: "FF5BA8").opacity(0.25)
//    private let iconTint = Color(hex: "E91E63")
//    private let borderGray = Color(hex: "E0E0E0")
//    private let titleColor = Color(hex: "1A1A1A")
//    private let subtitleColor = Color(hex: "5C5C5C")
//    private let labelColor = Color(hex: "8E8E8E")

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    isInputFocused = false
                }

            VStack(spacing: 0) {
                // 顶部图标
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.appBackground)
                        .frame(width: 56, height: 56)
                    Image(systemName: iconName)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundColor(AppTheme.Colors.primaryColor)
                }
                .padding(.top, 28)
                .padding(.bottom, 16)

                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.titleColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                if let subtitle = subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(AppTheme.Colors.subtitleColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                }

                // 输入区
                VStack(alignment: .leading, spacing: 8) {
                    Text(inputLabel.uppercased())
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.Colors.titleColor)
                        .tracking(0.5)

                    HStack(spacing: 8) {
                        TextField(placeholder, text: $text)
                            .font(.system(size: 16, weight: .regular))
                            .focused($isInputFocused)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24)
                                            .stroke(AppTheme.Colors.borderColor, lineWidth: 1)
                                    )
                            )

                        Button {
                            isInputFocused = false
                        } label: {
                            Image(systemName: "keyboard.chevron.compact.down")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(AppTheme.Colors.primaryColor)
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle()
                                        .fill(AppTheme.Colors.appBackground)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("收起键盘")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                // 底部按钮
                HStack(spacing: 12) {
                    Button(action: onCancel) {
                        Text(cancelTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.titleColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24)
                                            .stroke(AppTheme.Colors.borderColor, lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: onConfirm) {
                        Text(confirmTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(AppTheme.Colors.primaryColor)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(confirmDisabled)
                    .opacity(confirmDisabled ? 0.6 : 1)
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 28)
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
    struct PreviewWrapper: View {
        @State private var text = ""
        var body: some View {
            InputModalView(
                title: "Add New Category",
                subtitle: "Organize your thoughts better with a custom category.",
                inputLabel: "Category Name",
                placeholder: "Enter category name...",
                text: $text,
                cancelTitle: "Cancel",
                confirmTitle: "Confirm",
                onCancel: {},
                onConfirm: {}
            )
        }
    }
    return PreviewWrapper()
}
