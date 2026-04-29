import SwiftUI
import Kingfisher

struct ShelfCardView: View {
    let notebook: Notebook
    let styleIndex: Int

    var body: some View {
        VStack(alignment: .center,spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Rectangle().fill(AppTheme.Colors.shadowBlockColor)
                    .frame(width: 100,height: 141)
                    .offset(x: 4,y: 4)
                    .shadow(color: AppTheme.Colors.shadowColor, radius: 10, x: 2, y: 2)
                KFImage.url(URL(string: notebook.cover.image))
                    .placeholder { ProgressView() }
                    .onFailureView {
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    }
                    .fade(duration: 0.2)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 141)
                    .clipped()
            }
            Text(notebook.title.isEmpty ? "未命名" : notebook.title)
                .font(AppTheme.Fonts.headingText)
                .foregroundColor(AppTheme.Colors.titleColor)
                .lineLimit(1)
                .padding([.horizontal, .bottom], 10)
        }
    }
}

