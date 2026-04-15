import Foundation
import SwiftUI
import Combine

final class AppEnvironment: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    let documentStore: DocumentStore
    let ocrService: OCRService
    let templateEngine: TemplateEngine
    let coverStore: CoverStore
    let bookStore: BookStore
    let cloudSyncService: CloudSyncService
    let authService: AuthService
    let session: SessionStore
    let categoryStore: CategoryStore
    
    private var cancellables: Set<AnyCancellable> = []

    init(
        documentStore: DocumentStore,
        ocrService: OCRService,
        templateEngine: TemplateEngine,
        coverStore: CoverStore,
        bookStore: BookStore,
        cloudSyncService: CloudSyncService,
        authService: AuthService,
        session: SessionStore,
        categoryStore: CategoryStore
    ) {
        self.documentStore = documentStore
        self.ocrService = ocrService
        self.templateEngine = templateEngine
        self.coverStore = coverStore
        self.bookStore = bookStore
        self.cloudSyncService = cloudSyncService
        self.authService = authService
        self.session = session
        self.categoryStore = categoryStore
        
        // 让 session 的变化驱动整个环境对象刷新（例如登录态变化需要全局 UI 立即响应）
        session.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}

extension AppEnvironment {
    /// 提供一个默认的本地 Stub 环境，方便预览与早期开发
    static func bootstrap() -> AppEnvironment {
        let session = SessionStore()
        let categoryStore = InMemoryCategoryStore(tokenProvider: { session.accessToken })
        return AppEnvironment(
            documentStore: LocalDocumentStore(),
            ocrService: StubOCRService(),
            templateEngine: SimpleTemplateEngine(),
            coverStore: DefaultCoverStore(tokenProvider: { session.accessToken }),
            bookStore: DefaultBookStore(tokenProvider: { session.accessToken }),
            cloudSyncService: StubCloudSyncService(),
            authService: LocalAuthService(),
            session: session,
            categoryStore: categoryStore
        )
    }
}

