import SwiftUI

/// iOS 15 使用 `NavigationView`（栈式），iOS 16+ 使用 `NavigationStack`
struct CompatibleNavigationStack<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack { content() }
            } else {
                NavigationView { content() }
                    .navigationViewStyle(.stack)
            }
        }
    }
}

extension View {
    /// `scrollDismissesKeyboard` 仅在 iOS 16+ 可用
    @ViewBuilder
    func scrollDismissesKeyboardIfAvailable() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollDismissesKeyboard(.interactively)
        } else {
            self
        }
    }
}
