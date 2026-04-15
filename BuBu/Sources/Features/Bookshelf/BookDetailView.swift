import SwiftUI

/// 册子详情视图：未来可以接入 3D 物理翻页效果和音效
struct BookDetailView: View {
    let notebook: Notebook
    @State private var selectedPage: NotebookPage?

    var body: some View {
        VStack {
            if notebook.pages.isEmpty {
                ContentUnavailableView(
                    "暂无页面",
                    systemImage: "doc.on.doc",
                    description: Text("可以在采集中添加照片或检查单到本册子。")
                )
            } else {
                TabView(selection: $selectedPage) {
                    ForEach(notebook.pages) { page in
                        pageView(for: page)
                            .tag(Optional(page))
                            .padding()
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .animation(.easeInOut, value: selectedPage)
            }
        }
        .navigationTitle(notebook.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if selectedPage == nil {
                selectedPage = notebook.pages.first
            }
        }
    }

    @ViewBuilder
    private func pageView(for page: NotebookPage) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    colors: [Color.white, Color.gray.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(radius: 4)
            .overlay {
                VStack(alignment: .leading, spacing: 8) {
                    Text(page.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    switch page.type {
                    case .photo:
                        ZStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .cornerRadius(12)
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                        }
                    case .checkup(let record):
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.title)
                                .font(AppTheme.Fonts.sectionTitle)
                            ForEach(record.metrics) { metric in
                                HStack {
                                    Text(metric.name)
                                    Spacer()
                                    Text("\(metric.value)\(metric.unit ?? "")")
                                        .foregroundColor(.primary)
                                }
                                .font(.caption)
                            }
                        }
                    case .note(let text):
                        ScrollView {
                            Text(text)
                                .font(AppTheme.Fonts.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    Spacer()
                }
                .padding()
            }
    }
}

