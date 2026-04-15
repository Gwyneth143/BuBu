import SwiftUI
import Kingfisher

struct ShelfCardView: View {
    let notebook: Notebook
    let styleIndex: Int

    var body: some View {
        VStack(alignment: .center,spacing: 10) {
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
            .shadow(color: Color.black.opacity(0.5), radius: 10, x: 4, y: 4)
            Text(notebook.title.isEmpty ? "Title" : notebook.title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.black.opacity(0.8))
                .lineLimit(1)
                .padding([.horizontal, .bottom], 10)
        }
    }
}

