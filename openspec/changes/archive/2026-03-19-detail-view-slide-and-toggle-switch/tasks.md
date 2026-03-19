## 1. 详情过渡

- [x] 1.1 在 `BTMShellView` 的 detail 区域引入 `ZStack` /条件视图组合，确保 `BackgroundItemDetailView` 仅在选中条目时呈现，并为其添加 `.transition(.move(edge: .trailing))` 加动画模块
- [x] 1.2 用 `withAnimation` 控制 `viewModel.customDetailEntry` 的切换，同时保留 `BTMEntryListContainerView` 与 `ScrollViewReader` 的滚动/选中状态以避免跳帧

## 2. 列表开关样式

- [x] 2.1 将 `BTMEntryListRowView` 中的 `Toggle` 显式应用 `SwitchToggleStyle()`，并检查 `padding`/`Spacer` 以避免布局挤压
- [x] 2.2 强化 `Toggle` 的语义：保持 `.accessibilityLabel`、`.accessibilityValue` 和 `.accessibilityIdentifier`，确认与 `Button` 按钮之间有独立热区
