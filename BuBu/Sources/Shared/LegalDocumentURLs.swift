import Foundation

/// 《用户须知》与《隐私政策》的线上页面地址。
/// 上线前请将下方占位 URL 替换为你实际托管的页面链接（建议使用 HTTPS）。
enum LegalDocumentURLs {
    static let userNotice: URL? = URL(string: "https://example.com/bubu/user-notice")
    static let privacyPolicy: URL? = URL(string: "https://example.com/bubu/privacy-policy")
}
