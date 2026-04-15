import Foundation

/// 孕期检查单等结构化信息
struct CheckupRecord: Identifiable, Hashable {
    let id: UUID
    var date: Date
    /// 检查项目名称，如 "NT 检查"、"唐筛" 等
    var title: String
    /// 关键指标与数值
    var metrics: [CheckupMetric]
    /// OCR 原始文本（方便后续调试）
    var rawText: String?
}

struct CheckupMetric: Identifiable, Hashable {
    let id: UUID
    var name: String
    var value: String
    var unit: String?
    /// 正常范围等提示
    var reference: String?
}

