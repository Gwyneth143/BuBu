## Pregnancy Notebook（SwiftUI）

一个使用 **SwiftUI** 搭建的多 Tab 记忆册应用骨架，用于管理「书架 / 采集 / 工坊 / 我的」四大功能。当前仓库侧重于 **项目结构与核心功能封装**，方便在 Xcode 中继续扩展。

- **书架**：展示用户创建的册子（书本），支持添加 / 删除 / 排序，后续可接入 3D 物理翻页特效与翻页音效。
- **采集**：从拍照、相册导入、文件导入中收集素材，针对孕期检查单等场景封装智能 OCR 与结构化抽取接口。
- **工坊**：提供册子封面皮肤（免费 / 会员），以及 DIY 封面编辑接口。
- **我的**：提供 iCloud 数据同步、会员购买入口、生物识别锁（Face ID / Touch ID）能力封装。

### 技术栈与架构

- **UI**：SwiftUI + MVVM 风格，使用 `TabView` 作为四大模块入口。
- **模块划分**
  - `Features/Bookshelf`：书架与册子翻页相关界面与 ViewModel。
  - `Features/Collect`：拍照 / 相册 / 文件导入及 OCR 入口。
  - `Features/Workshop`：封面皮肤列表与 DIY 封面编辑。
  - `Features/Profile`：账号 / 会员 / 隐私与生物识别锁。
  - `Core/Models`：册子、页面、检查单等核心数据模型。
  - `Core/Services`：文档存储、OCR、模版引擎、封面商店、云同步、认证等协议与默认实现。
  - `Shared`：主题、依赖注入容器（`AppEnvironment`）等。

### 使用方式（建议）

1. 在 Xcode 中创建一个 SwiftUI iOS App 工程（例如 `PregnancyNotebookApp`）。
2. 将本仓库 `Sources` 下的代码按目录拷贝到你的 App 工程中。
3. 用这里的 `RootTabView` 作为 `WindowGroup` 的根视图，并通过 `AppEnvironment` 注入所需服务。
4. 按业务需求逐步替换默认的假数据 / Stub 实现（OCR 接第三方 SDK，云同步接 iCloud / CloudKit，支付接 StoreKit 等）。

> 当前代码重点在于 **清晰的模块拆分与服务协议设计**，方便你安全地迭代复杂功能（例如 3D 翻页、智能 OCR、生物识别锁保护敏感册子）。

