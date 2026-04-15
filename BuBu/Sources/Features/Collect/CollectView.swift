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
        // 占位：实际项目中从相机 / 相册 / 文件选择 Data
        let dummyData = Data()
        let template = CheckupTemplate(id: UUID(), name: "孕期检查单模版", config: [:])
        do {
            let record = try await ocrService.analyzeCheckupImage(dummyData, template: template)
            await MainActor.run {
                self.lastCheckupRecord = record
            }
        } catch {
            // TODO: 错误提示
        }
    }
}

struct CollectView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var viewModel: CollectViewModel

    init() {
        _viewModel = StateObject(wrappedValue: CollectViewModel(
            ocrService: StubOCRService(),
            templateEngine: SimpleTemplateEngine()
        ))
    }

    var body: some View {
        NavigationStack {
            List {
                Section("采集方式") {
                    Button {
                        // TODO: 打开相机
                    } label: {
                        Label("拍照采集", systemImage: "camera")
                    }

                    Button {
                        // TODO: 打开相册选择
                    } label: {
                        Label("相册导入", systemImage: "photo.on.rectangle.angled")
                    }

                    Button {
                        // TODO: 文件导入（例如 PDF 检查单）
                    } label: {
                        Label("文件导入", systemImage: "doc.text")
                    }
                }

                Section("智能识别（示例）") {
                    Button {
                        Task {
                            await viewModel.analyzeDummyImage()
                        }
                    } label: {
                        Label("识别示例检查单", systemImage: "wand.and.rays")
                    }

                    if let record = viewModel.lastCheckupRecord {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.title)
                                .font(AppTheme.Fonts.sectionTitle)
                            Text(record.date, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ForEach(record.metrics) { metric in
                                HStack {
                                    Text(metric.name)
                                    Spacer()
                                    Text("\(metric.value)\(metric.unit ?? "")")
                                }
                                .font(.caption)
                            }
                        }
                    }
                }
            }
            .navigationTitle("采集")
        }
    }
}

