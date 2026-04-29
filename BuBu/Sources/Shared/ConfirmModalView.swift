import SwiftUI

/// 全局通用确认弹框：用于删除、提交、保存等二次确认场景。
struct ConfirmModalView: View {
    var title: String
    var message: String?
    var iconName: String = "questionmark.circle.fill"
    var cancelTitle: String = String.localized("common.cancel")
    var confirmTitle: String = String.localized("common.confirm")
    var confirmColor: Color = AppTheme.Colors.primaryColor
    var onCancel: () -> Void
    var onConfirm: () -> Void

    private let titleColor = Color(hex: "1A1A1A")
    private let messageColor = Color(hex: "5C5C5C")
    private let borderGray = Color(hex: "E0E0E0")
    private let iconBg = AppTheme.Colors.appBackground
    private let iconTint = AppTheme.Colors.primaryColor

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onCancel)

            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(iconBg)
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

                if let message, !message.isEmpty {
                    Text(message)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(messageColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                }

                HStack(spacing: 12) {
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
                                    .fill(confirmColor)
                            )
                    }
                    .buttonStyle(.plain)
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
            .padding(.horizontal, 24)
        }
    }
}
