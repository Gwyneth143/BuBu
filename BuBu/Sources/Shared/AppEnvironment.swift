import Foundation

final class AppEnvironment: ObservableObject {
    let documentStore: DocumentStore
    let ocrService: OCRService
    let templateEngine: TemplateEngine
    let coverStore: CoverStore
    let cloudSyncService: CloudSyncService
    let authService: AuthService

    init(
        documentStore: DocumentStore,
        ocrService: OCRService,
        templateEngine: TemplateEngine,
        coverStore: CoverStore,
        cloudSyncService: CloudSyncService,
        authService: AuthService
    ) {
        self.documentStore = documentStore
        self.ocrService = ocrService
        self.templateEngine = templateEngine
        self.coverStore = coverStore
        self.cloudSyncService = cloudSyncService
        self.authService = authService
    }
}

extension AppEnvironment {
    /// 提供一个默认的本地 Stub 环境，方便预览与早期开发
    static func bootstrap() -> AppEnvironment {
        AppEnvironment(
            documentStore: InMemoryDocumentStore(),
            ocrService: StubOCRService(),
            templateEngine: SimpleTemplateEngine(),
            coverStore: DefaultCoverStore(),
            cloudSyncService: StubCloudSyncService(),
            authService: LocalAuthService()
        )
    }
}

