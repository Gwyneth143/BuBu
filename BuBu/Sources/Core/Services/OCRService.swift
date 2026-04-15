import Foundation
import SwiftUI

/// 智能 OCR 与检查单解析服务
protocol OCRService {
    /// 针对「孕期检查单」等模版，识别日期、项目与关键指标
    func analyzeCheckupImage(_ imageData: Data, template: CheckupTemplate) async throws -> CheckupRecord
}

/// 检查单模版（不同医院 / 不同检查类型可自定义）
struct CheckupTemplate: Identifiable, Hashable {
    let id: UUID
    var name: String
    /// 自定义配置，如字段别名、布局提示等，这里先用字典占位
    var config: [String: String]
}

/// 占位实现：不做真实 OCR，仅返回假数据，方便先打通流程
final class StubOCRService: OCRService {
    func analyzeCheckupImage(_ imageData: Data, template: CheckupTemplate) async throws -> CheckupRecord {
        let metric = CheckupMetric(
            id: UUID(),
            name: "胎心率",
            value: "150",
            unit: "次/分",
            reference: "120 - 160 正常范围"
        )
        return CheckupRecord(
            id: UUID(),
            date: Date(),
            title: template.name,
            metrics: [metric],
            rawText: "示例 OCR 文本，仅用于原型演示。"
        )
    }
}

