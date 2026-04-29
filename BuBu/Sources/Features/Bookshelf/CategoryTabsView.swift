import SwiftUI

/// 书架分类 Tab 横向滚动条，可作为全局组件复用。
struct CategoryTabsView: View {
    /// 所有可选分类标题（展示文案）
    let categories: [String]
    /// 当前选中的分类，由外部驱动
    @Binding var selection: String
    /// 选中回调（可选）
    var onSelect: ((String) -> Void)?
    /// 若返回 `false` 则不切换分类（用于未登录时拦截）
    var onLoginGate: (() -> Bool)?

    init(
        categories: [String],
        selection: Binding<String>,
        onSelect: ((String) -> Void)? = nil,
        onLoginGate: (() -> Bool)? = nil
    ) {
        // 在传入分类前面自动加上一个 “All”
        var allCategories: [String] = []
        if !categories.contains(String.localized("bookshelf.category.all")) {
            allCategories.append(String.localized("bookshelf.category.all"))
        }
        allCategories.append(contentsOf: categories)

        self.categories = allCategories
        self._selection = selection
        self.onSelect = onSelect
        self.onLoginGate = onLoginGate
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(categories, id: \.self) { category in
                        VStack(spacing: 4) {
                            Button {
                                if let gate = onLoginGate, !gate() { return }
                                selection = category
                                onSelect?(category)
                            } label: {
                                Text(category)
                                    .font(.subheadline.weight(selection == category ? .semibold : .regular))
                                    .foregroundColor(selection == category ? AppTheme.Colors.primaryColor : .secondary)
                            }
                            .buttonStyle(.plain)

                            Rectangle()
                                .fill(selection == category ? AppTheme.Colors.primaryColor : Color.clear)
                                .frame(height: 2)
                        }
                    }
                }
                .padding(.trailing, 20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

//            Rectangle()
//                .fill(AppTheme.Colors.divider)
//                .frame(height: 1)
        }
        .padding(.top, 4)
    }
}
