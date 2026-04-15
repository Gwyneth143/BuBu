import SwiftUI

final class WorkshopViewModel: ObservableObject {
    @Published var covers: [NotebookCover] = []

    private let coverStore: CoverStore

    init(coverStore: CoverStore) {
        self.coverStore = coverStore
    }

    @MainActor
    func load() async {
        do {
            let data = try await coverStore.fetchAllCovers()
            covers = data
        } catch {
            // TODO: 错误提示
        }
    }
}

struct WorkshopView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var viewModel: WorkshopViewModel

    init() {
        _viewModel = StateObject(wrappedValue: WorkshopViewModel(coverStore: DefaultCoverStore()))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 16)], spacing: 16) {
                    ForEach(viewModel.covers) { cover in
                        VStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(cover.isPremium ? Color.yellow.opacity(0.3) : Color.gray.opacity(0.15))
                                .frame(height: 160)
                                .overlay(
                                    Text(cover.name)
                                        .font(.caption.bold())
                                        .multilineTextAlignment(.center)
                                        .padding(8)
                                )

                            if cover.isPremium {
                                Text("会员")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.yellow.opacity(0.2))
                                    .cornerRadius(6)
                            } else {
                                Text("免费")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    NavigationLink {
                        CoverEditorView()
                    } label: {
                        VStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                                .frame(height: 160)
                                .overlay(
                                    Image(systemName: "plus")
                                        .font(.largeTitle)
                                        .foregroundColor(.secondary)
                                )
                            Text("DIY 封面")
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("工坊")
            .task {
                await viewModel.load()
            }
        }
    }
}

