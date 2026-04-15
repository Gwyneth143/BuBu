import SwiftUI

/// 多语言文案 Key，与 Resources/*.lproj/Localizable.strings 对应
enum L10n {
    static func string(_ key: String.LocalizationValue) -> String {
        String(localized: key)
    }
}

extension String {
    /// 使用 Localizable.strings 中的 key 取当前语言文案
    static func localized(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }
}

extension Text {
    /// 使用 Localizable.strings 中的 key 显示本地化文案
    init(localized key: String) {
        self.init(String(localized: String.LocalizationValue(key)))
    }
}

extension Date {
    static func dateString(_ key: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: key)
    }
}
