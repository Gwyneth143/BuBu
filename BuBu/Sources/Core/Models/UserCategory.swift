import Foundation

/// 用户创建的分类（用于展示与选择）
//struct UserCategory: Identifiable, Hashable {
//    let id: UUID
//    var name: String
//
//    init(id: UUID = UUID(), name: String) {
//        self.id = id
//        self.name = name
//    }
//
//    /// 映射到 Notebook 使用的枚举（创建/保存册子时用）
//    func toNotebookCategory() -> NotebookCategory {
//        switch name.lowercased() {
//        case "travel": return .travel
//        case "family": return .family
//        case "personal": return .personal
//        case "other": return .other
//        default: return .other
//        }
//    }
//}
