import SwiftUI

@main
struct NotebookApp: App {
    @StateObject private var appEnvironment = AppEnvironment.bootstrap()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appEnvironment)
        }
    }
}

