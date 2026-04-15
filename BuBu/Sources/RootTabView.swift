import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            BookshelfView()
                .tabItem {
                    Label("书架", systemImage: "books.vertical")
                }

            CollectView()
                .tabItem {
                    Label("采集", systemImage: "plus.rectangle.on.folder")
                }

            WorkshopView()
                .tabItem {
                    Label("工坊", systemImage: "paintpalette")
                }

            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.crop.circle")
                }
        }
        .tint(AppTheme.accentColor)
    }
}

