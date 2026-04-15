import Combine
import Foundation
import SwiftUI

final class CollectViewModel: ObservableObject {
    @Published var selectedTemplate: NotebookPageTemplate?
    @Published var lastCheckupRecord: CheckupRecord?

    private let ocrService: OCRService
    private let templateEngine: TemplateEngine

    init(ocrService: OCRService, templateEngine: TemplateEngine) {
        self.ocrService = ocrService
        self.templateEngine = templateEngine
    }

    func analyzeDummyImage() async {
        let record = CheckupRecord(
            id: UUID(),
            date: Date(),
            title: "孕期检查单模版",
            metrics: [
                CheckupMetric(
                    id: UUID(),
                    name: "胎心率",
                    value: "150",
                    unit: "次/分",
                    reference: "120 - 160 正常范围"
                )
            ],
            rawText: "示例 OCR 文本，仅用于原型演示。"
        )

        await MainActor.run {
            self.lastCheckupRecord = record
        }
    }

    func analyzeImageData(_ imageData: Data) async {
        let template = CheckupTemplate(id: UUID(), name: "孕期检查单模版", config: [:])
        do {
            let record = try await ocrService.analyzeCheckupImage(imageData, template: template)
            await MainActor.run {
                self.lastCheckupRecord = record
            }
        } catch {
            // TODO: 错误提示
        }
    }

    func applyRecognizedRecord(_ record: CheckupRecord) {
        lastCheckupRecord = record
    }
}
