import SwiftUI

enum AppTheme {
    static let accentColor = Color("AccentColor", bundle: .main)

    struct Fonts {
        static let title = Font.system(size: 24, weight: .bold, design: .rounded)
        static let sectionTitle = Font.system(size: 18, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 15, weight: .regular, design: .rounded)
    }
}

