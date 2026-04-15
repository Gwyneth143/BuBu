import SwiftUI

/// DIY 册子封面编辑器（这里只做 UI 骨架）
struct CoverEditorView: View {
    @State private var title: String = "我的新册子"
    @State private var backgroundColor: Color = .pink.opacity(0.4)

    var body: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 16)
                .fill(backgroundColor)
                .frame(height: 220)
                .overlay(
                    Text(title)
                        .font(AppTheme.Fonts.title)
                        .multilineTextAlignment(.center)
                        .padding()
                )
                .shadow(radius: 4)

            Form {
                Section("标题") {
                    TextField("输入册子标题", text: $title)
                }

                Section("颜色") {
                    HStack {
                        ColorPicker("封面颜色", selection: $backgroundColor)
                    }
                }

                Section {
                    Button {
                        // TODO: 保存 DIY 封面配置
                    } label: {
                        Text("保存为封面模版")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding()
        .navigationTitle("DIY 封面")
        .navigationBarTitleDisplayMode(.inline)
    }
}

