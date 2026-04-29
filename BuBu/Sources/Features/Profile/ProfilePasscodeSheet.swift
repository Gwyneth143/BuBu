import SwiftUI

enum ProfilePasscodeFlow {
    case set
    case disable
}

/// 个人中心「密码锁」设置 / 关闭时的全屏 sheet 内容
struct ProfilePasscodeSheet: View {
    let flow: ProfilePasscodeFlow
    @Binding var passcodeInput: String
    @Binding var passcodeConfirmInput: String
    @Binding var errorText: String
    var onSubmit: () -> Void
    var onCancel: () -> Void

    var body: some View {
        ZStack {
            AppTheme.Colors.appBackground
                .ignoresSafeArea()
            CompatibleNavigationStack {
                VStack(alignment: .leading, spacing: 14) {
                if flow == .set {
                    Text(localized: "profile.passcode.set_title")
                        .font(.headline)
                    Text(localized: "profile.passcode.priority_hint")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    SecureField(String.localized("profile.passcode.set_placeholder"), text: $passcodeInput)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .onChange(of: passcodeInput) { _ in limitPasscodeDigits() }
                    SecureField(String.localized("profile.passcode.set_confirm_placeholder"), text: $passcodeConfirmInput)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .onChange(of: passcodeConfirmInput) { _ in limitPasscodeDigits() }
                } else {
                    Text(localized: "profile.passcode.disable_title")
                        .font(.headline)
                    SecureField(String.localized("profile.passcode.disable_placeholder"), text: $passcodeInput)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .onChange(of: passcodeInput) { _ in limitPasscodeDigits() }
                }

                if !errorText.isEmpty {
                    Text(errorText)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Spacer()

                Button(action: onSubmit) {
                    Text(flow == .set
                         ? String.localized("profile.passcode.save")
                         : String.localized("profile.passcode.confirm_disable"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule().fill(AppTheme.Colors.primaryColor)
                        )
                }
                .buttonStyle(.plain)
                }
                .padding(20)
                .navigationTitle(String.localized("profile.passcode"))
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden(true)
                .toolbar {
//                    ToolbarItem(placement: .cancellationAction) {
//                        Button(String.localized("common.cancel"), action: onCancel)
//                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            onCancel()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.black)
                        }
                        .accessibilityLabel(Text(localized: "common.cancel"))
                    }
                }
            }
        }
    }

    private func limitPasscodeDigits() {
        passcodeInput = String(passcodeInput.filter(\.isNumber).prefix(4))
        passcodeConfirmInput = String(passcodeConfirmInput.filter(\.isNumber).prefix(4))
    }
}
