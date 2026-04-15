#if canImport(UIKit) && canImport(VisionKit)
import SwiftUI
import UIKit

struct DocumentScannerPreviewSection: View {
    let scannedImages: [UIImage]
    @Binding var currentPageIndex: Int
    let onTapImage: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if scannedImages.isEmpty {
                EmptyView()
            } else {
                TabView(selection: $currentPageIndex) {
                    ForEach(Array(scannedImages.enumerated()), id: \.offset) { index, image in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(18)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 28))
                            .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 8)
                            .tag(index)
                            .onTapGesture {
                                onTapImage(index)
                            }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: 420)
            }
        }
    }
}
#endif
