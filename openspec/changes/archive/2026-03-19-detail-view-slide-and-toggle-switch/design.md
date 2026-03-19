## 上下文
当前 `BTMShellView` 使用 `NavigationSplitView`，detail 区域直接以 `BackgroundItemDetailView` 替换 `BTMEntryListContainerView`，缺乏任何过渡效果。用户在点击列表行后，detail 内容立刻撑满右侧，但没有“页面从右边滑入”的视觉反馈；返回时状态也突然恢复。列表行中的 `Toggle` 目前默认表现为 macOS 的方框勾选风格，和“启用/禁用”的 switch 语义不一致，也影响状态的识别。列表滚动位置和 `selectedEntryID` 需要持续绑定以在动画后保持上下文。

## 目标 / 非目标
**目标：**
- 把详情面板的替换行为调整为从右侧滑入/滑出的“页面转场”，并在切换选中条目、返回列表时保持动画一致和上下文。
- 保持原始的 `NavigationSplitView` 架构及 `ScrollViewReader`/`selectedEntryID` 逻辑，避免复杂重写。
- 把列表上的启用控件呈现为明确的 switch 样式，保持无障碍标识、大小和布局一致。

**非目标：**
- 重构成全新的导航容器或完全替代 `NavigationSplitView`。
- 把 `BackgroundItemDetailView` 改成新的SwiftUI `NavigationStack` 目标（暂时只在 detail 区域做过渡）。

## 决策
- **Detail 过渡**：在 `BTMShellView.detailContent` 里用 `ZStack` 包裹列表与详情，通过 `withAnimation` 切换 `detailEntry` 状态，并为 `BackgroundItemDetailView` 指定 `.transition(.move(edge: .trailing))` 与 `animation(.easeOut(duration: 0.25))`。同一时间确保 `BTMEntryListContainerView` 仍保留在背后（`ZStack` 中两个视图共存但仅一个可见），以便 `NavigationSplitView` 继续管理布局。返回时用 `.transition(.move(edge: .trailing))` 的反向动画再现滑出。
- **状态保持**：保持 `viewModel.selectedEntry` 与 `selectedEntryID` 逻辑，`ScrollViewReader` 继续在 `BTMEntryListContainerView` 中滚动到选中条目。`ZStack` 只在 `detailEntry` 存在时展开 `BackgroundItemDetailView`，并通过 `.id(entry.id)` 让 SwiftUI 区分每次的动画。
- **Toggle 样式**：`BTMEntryListRowView` 为 `Toggle` 明确设置 `.toggleStyle(.switch)`（或自定义 `SwitchToggleStyle()`），并在 `Label`/`.accessibilityLabel` 中强调“启用”与“关闭”的语义，保持 `Toggle` 的 `.labelsHidden()` 以免额外文本干扰布局。
- **辅助反馈**：为滑动动画添加 `accessibilityAddTraits(.isModal)` 或 `accessibilityAction`，让 VoiceOver 用户知道进入了详情；`Toggle` 保持 `.accessibilityIdentifier` 以利自动化测试。

## 风险 / 权衡
- **跨组件动画状态不一致** → 需仔细控制 `ZStack` 中详情的 `id` 与 `transition`；可通过 `withAnimation` 包裹 `viewModel.customDetailEntry` 赋值，避免跳帧。
- **滑动动画与 `NavigationSplitView` 自动布局冲突** → 若动画嵌套期间 SwiftUI 重新布局可能导致闪烁，可先隐藏 `BTMEntryListContainerView` 里的滚动指示器再同步；同时提供 fallback：如果动画失败，仍能瞬间切换。
- **Switch 样式和现有布局冲突** → `SwitchToggleStyle` 比 `ToggleStyle` 更宽，可能压缩按钮区域；需要在 `HStack` 中预留足够空间或用 `.fixedSize()` 避免按钮被挤压。
