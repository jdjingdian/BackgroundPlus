# UI Structure Guide

## 1) ContentView 职责盘点

- 壳层布局：应用主界面入口，只负责将根容器挂载到 `WindowGroup` 场景。
- 状态编排：迁移到 `UI/Screens/BTMShellView.swift`，包含页面级 sheet 控制与删除流程触发。
- 可抽取展示区块：列表行、详情字段、缺失 helper 提示、删除确认弹层，均拆分为独立视图。

## 2) 目录映射与迁移落点

- `UI/Screens/`
  - `BTMShellView.swift`: 顶层页面容器，承接业务区块编排。
  - `BTMEntryListContainerView.swift`: 列表区域容器与工具栏事件。
  - `BTMEntryDetailContainerView.swift`: 详情区域容器与状态分支。
  - `Settings/HelperSettingsContainerView.swift`: 设置页容器。
- `UI/Components/`
  - `BTMEntryListRowView.swift`: 列表行纯展示。
  - `BTMDetailRowView.swift`: 详情字段纯展示。
  - `BTMMissingHelperView.swift`: helper 缺失引导展示。
- `UI/Sheets/`
  - `BTMDeleteConfirmSheet.swift`: 删除确认弹层。
- `UI/Support/`
  - `LocalizationSupport.swift`: 共享本地化辅助函数。

## 3) Shared 与 App 内组件边界

- `Shared`（跨 target 共享）
  - 仅放置可复用于 app/helper 的纯模型、纯算法、无 UI 依赖的基础设施。
- `BackgroundPlus/UI/Components`（应用内复用）
  - 放置只在应用 UI 内复用的 SwiftUI 展示组件。
- 升级规则
  - 当组件同时被 app 与 helper 或多个 target 复用，且不依赖 SwiftUI 页面状态时，才提升到 `Shared`。

## 4) 后续增量约定

- 新页面优先落在 `UI/Screens`，不向 `ContentView` 回填业务逻辑。
- 可复用展示组件优先放入 `UI/Components`，容器与展示分离。
- 弹层/确认流程优先放入 `UI/Sheets`，避免散落在多个容器中。
