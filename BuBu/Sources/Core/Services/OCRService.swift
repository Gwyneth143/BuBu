import Foundation
import SwiftUI
import ImageIO
import Vision

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

/// 基于 Vision 的 OCR 实现，用于将扫描件转成结构化数字档案
final class VisionOCRService: OCRService {
    func analyzeCheckupImage(_ imageData: Data, template: CheckupTemplate) async throws -> CheckupRecord {
        guard let cgImage = makeCGImage(from: imageData) else {
            throw OCRProcessingError.invalidImageData
        }

        let recognizedLines = try await recognizeTextLines(in: cgImage)
        let rawText = recognizedLines.joined(separator: "\n")

        return CheckupRecord(
            id: UUID(),
            date: extractDate(from: rawText) ?? Date(),
            title: inferTitle(from: rawText, template: template),
            metrics: extractMetrics(from: recognizedLines),
            rawText: rawText.isEmpty ? nil : rawText
        )
    }

    private func makeCGImage(from imageData: Data) -> CGImage? {
        guard
            let source = CGImageSourceCreateWithData(imageData as CFData, nil),
            let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            return nil
        }

        return cgImage
    }

    private func recognizeTextLines(in cgImage: CGImage) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations
                    .compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                continuation.resume(returning: lines)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["zh-Hans", "en-US"]

            do {
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func inferTitle(from rawText: String, template: CheckupTemplate) -> String {
        let lines = rawText
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let firstMeaningfulLine = lines.first(where: { $0.count >= 4 }) {
            return firstMeaningfulLine
        }

        return template.name
    }

    private func extractDate(from text: String) -> Date? {
        let patterns = [
            #"\b\d{4}[./-]\d{1,2}[./-]\d{1,2}\b"#,
            #"\b\d{1,2}[./-]\d{1,2}[./-]\d{2,4}\b"#
        ]

        for pattern in patterns {
            guard
                let regex = try? NSRegularExpression(pattern: pattern),
                let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                let range = Range(match.range, in: text)
            else {
                continue
            }

            let candidate = String(text[range])
            for formatter in dateFormatters {
                if let date = formatter.date(from: candidate) {
                    return date
                }
            }
        }

        return nil
    }

    private var dateFormatters: [DateFormatter] {
        let formats = [
            "yyyy-MM-dd",
            "yyyy/MM/dd",
            "yyyy.MM.dd",
            "MM-dd-yyyy",
            "MM/dd/yyyy",
            "MM.dd.yyyy",
            "dd-MM-yyyy",
            "dd/MM/yyyy",
            "dd.MM.yyyy",
            "MM-dd-yy",
            "MM/dd/yy",
            "dd-MM-yy",
            "dd/MM/yy"
        ]

        return formats.map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            return formatter
        }
    }

    private func extractMetrics(from lines: [String]) -> [CheckupMetric] {
        // 1. 更严格的数值行匹配：中文字段/英文缩写 + 数字 + 单位
        let pattern = #"([A-Za-z\u4e00-\u9fa5]{1,20})[：: ]{0,2}([-+]?\d+(?:\.\d+)?)\s*([%A-Za-z\u4e00-\u9fa5/]+)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        // 常见产检/体检关键字段与单位，用来过滤掉明显不相关的匹配
        let importantKeywords: [String] = [
            "胎心率", "心率", "FHR",
            "血压", "收缩压", "舒张压", "BP",
            "体重", "Weight",
            "宫高", "腹围",
            "血糖", "Glucose",
            "血红蛋白", "Hb",
            "BMI",
            "NT", "唐筛"
        ]

        let allowedUnits: [String] = [
            "次/分", "bpm",
            "mmHg",
            "kg", "g", "mg/dL", "mmol/L",
            "cm", "mm",
            "%", "周"
        ]

        func isImportantMetric(name: String, unit: String?, line: String) -> Bool {
            let lowered = name.lowercased()

            if importantKeywords.contains(where: { name.contains($0) || lowered.contains($0.lowercased()) }) {
                return true
            }

            if let unit, allowedUnits.contains(where: { unit.contains($0) }) {
                return true
            }

            // 对于短行（长度 < 18）且带有冒号的「字段:数值」也保留一部分
            if line.count < 18,
               line.contains(":" ) || line.contains("：") {
                return true
            }

            return false
        }

        var metrics: [CheckupMetric] = []
        var seenKeys = Set<String>()

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            let nsRange = NSRange(line.startIndex..., in: line)
            let matches = regex.matches(in: line, range: nsRange)

            for match in matches {
                guard
                    let nameRange = Range(match.range(at: 1), in: line),
                    let valueRange = Range(match.range(at: 2), in: line)
                else {
                    continue
                }

                let name = String(line[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                let value = String(line[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)

                // 极端长的数字一般不是「单一指标」，直接丢弃
                guard value.count <= 8 else { continue }

                let unit: String?
                if let unitRange = Range(match.range(at: 3), in: line) {
                    let parsedUnit = String(line[unitRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    unit = parsedUnit.isEmpty ? nil : parsedUnit
                } else {
                    unit = nil
                }

                guard name.count >= 2 else { continue }
                guard isImportantMetric(name: name, unit: unit, line: line) else { continue }

                let dedupeKey = "\(name)|\(value)|\(unit ?? "")"
                guard seenKeys.insert(dedupeKey).inserted else { continue }

                metrics.append(
                    CheckupMetric(
                        id: UUID(),
                        name: name,
                        value: value,
                        unit: unit,
                        reference: nil
                    )
                )
            }
        }

        // 最多保留 8 个关键指标，避免界面过长
        return Array(metrics.prefix(8))
    }
}

enum OCRProcessingError: LocalizedError {
    case invalidImageData

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            "无法读取扫描图像。"
        }
    }
}

