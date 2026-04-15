import PhotosUI
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// 相册（PHPicker，兼容 iOS 15）
struct PHPickerSheet: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    /// 相册界面已关掉，开始从系统加载/解码 `UIImage`（大图会较慢）
    var onDecodingStarted: () -> Void = {}
    /// 解码完成；`nil` 表示无法生成图片
    var onPick: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var parent: PHPickerSheet

        init(_ parent: PHPickerSheet) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            DispatchQueue.main.async {
                self.parent.isPresented = false
            }
            guard let result = results.first else { return }
            let provider = result.itemProvider
            guard provider.canLoadObject(ofClass: UIImage.self) else {
                DispatchQueue.main.async { self.parent.onPick(nil) }
                return
            }
            DispatchQueue.main.async {
                self.parent.onDecodingStarted()
            }
            provider.loadObject(ofClass: UIImage.self) { image, _ in
                DispatchQueue.main.async {
                    self.parent.onPick(image as? UIImage)
                }
            }
        }
    }
}
