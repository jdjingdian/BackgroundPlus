## 1. 稳定 toolbar 布局

- [x] 1.1 将 `BackgroundItemDetailView` 与列表共用的 toolbar 包装在一致的 `ToolbarItemGroup` 中，确保左侧始终存在导航占位控件，无论是否显示返回按钮。
- [x] 1.2 在 `BTMEntryListContainerView` 中同步 toolbar 占位的可见性状态，以避免在 detail 还未加载时突然位移。
- [x] 1.3 用 `GeometryReader` 或固定 `Spacer` 检查返回按钮与标题之间的间距，确保与列表状态下的对齐一致。

## 2. 交互与回归验证

- [x] 2.1 增加 UI/快照测试：连续选择不同条目并返回，校验 toolbar 标题的 `x` 位置保持不变。
- [x] 2.2 编写手动验证步骤记录：在 QA 测试文档中说明如何重现标题抖动并确认问题已解决。
