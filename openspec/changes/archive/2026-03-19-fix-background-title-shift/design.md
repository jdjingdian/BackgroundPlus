## 上下文

当前 `BackgroundItemDetailView` 是由 `split view` 的 detail 区域承载的，在详情激活时 macOS 会自动在 toolbar 左侧插入系统返回按钮。主列表与详情共享同一 toolbar，因此当 detail 展示时，系统会在标题左侧动态创造出一个 `navigationBackButton`，造成“后台项目管理”标题被推向右方并出现抖动。由于 toolbar 的左侧宽度并不固定，该行为削弱了分栏界面的稳定感，并且在用户频繁在列表与详情间切换时尤其明显。

## 目标 / 非目标

**目标：**
- 让 toolbar 标题在列表/详情之间切换时保持固定位置，避免因为返回按钮的出现而产生明显的横向位移。
- 在详情中显示返回按钮的同时保证其他 toolbar 控件（例如刷新、文件、搜索）相对位置不变。
- 最小化对现有 `split view` 结构（`BTMEntryListContainerView`/`BackgroundItemDetailView`）的侵入性改动，仍保持当前的 `NavigationSplitView` 架构。

**非目标：**
- 重新设计整个 toolbar 的视觉风格或将标题移至中央。
- 变更 macOS 默认的返回动画与行为，只需在现有交互下稳定布局。

## 决策

### 1. 在列表视图中为返回按钮预留占位空间
- **理由**：最小侵入。由于 toolbar 本身会动态添加返回按钮，只要在列表视图阶段就保留等价宽度，后续插入不会导致整体宽度变化。
- **替代方案**：拦截系统返回按钮并尝试用自定义按钮替换；但那会破坏系统手势和键盘快捷键（⌘[）。因此选择占位而不是替换。
- **实现**：在 `BackgroundItemDetailView` 的 toolbar 左侧插入 `Spacer` 或透明 `Button`，配合 `toolbarContent` 里的 `ToolbarItem(placement: .navigation)`，使得即便没有返回按钮也存在等宽占位。在 `BTMEntryListContainerView` 初始化时就渲染该占位项，并通过 `isDynamic`/`hidden` 布尔控制可视性，但始终占据空间。

### 2. 将标题与操作按钮以固定间距包裹
- **理由**：确保在 detail 和 list 之间切换时，标题不会因为系统返回按钮插入而改变与右侧操作按钮的距离。
- **实现**：使用根 toolbar 的 `HStack` 封装标题与操作按钮，并在左侧添加 `.overlay` 形式的占位标识符；或者通过 `ToolbarItemGroup` 结合 `conditional` 视图控制 left/right margin 以保持 alignment。必要时使用 `GeometryReader` 读 toolbar 宽度，确保标题在最大宽度内居中而又不受左侧 padding 影响。

### 3. 维持 split view transitions
- **理由**：现有规范要求 detail 以滑动方式出现。新的占位机制必须与动画同步，不能让占位空间在动画执行中闪烁。
- **实现**：在 `NavigationSplitView` 的 detail 视图同步展示时，在 `withAnimation` 中先更新 `isDetailVisible` 状态，确保 toolbar 占位立即启用。通过 `transaction` 设置 `.animation(.none)` 仅对占位，避免与 detail 的 slide animation 发生冲突。

## 风险 / 权衡

- [风险] Toolbar 的占位太宽或太窄，造成标题与按钮间的视觉不协调。
  → 通过现有 toolbar row 的 `Button` 占位测量 (一般 44px) 并用 `minWidth` 约束。验证与主列表中呈现的标题没有偏差。
- [风险] 占位视图在 accessibility 模式或窄窗口中可见，干扰按键顺序。
  → 设置 `accessibilityHidden(true)` 并在 `Button` 上禁止焦点，以免被 VoiceOver 读取。
- [风险] `NavigationSplitView` 在窗口宽度变化时可能重新布局，导致 toolbar 重新渲染时仍 twitch。
  → 通过 `onChange(of: selectedEntryID)` 触发 `toolbarState` 以及 `withAnimation(.easeOut(duration: 0.15))` 使动画平滑，并确保占位始终在 `toolbar` 结构中。

## 迁移计划

1. 在 `BTMEntryListContainerView` 及 `BackgroundItemDetailView` 中统一 toolbar 内容，添加 `toolbar` `Group` 包含固定占位与标题。
2. 同时更新 `BackgroundItemDetailView` 的 `NavigationStack`，确保返回按钮动画期间 toolbar 状态不会复位。
3. 编写 UI 测试/截图验证：在连点不同条目并返回的场景下，使用 `XCTest` 抓取 toolbar 的 `Frame` 变化。
4. 回归旧交互：在 detail 隐藏后确保占位依然存在以避免第一次显示时抖动。

## 未决问题

- 需要明确占位使用的最小宽度（是否直接使用等于系统返回按钮宽度？）。
- 如若无法在 toolbar 内部可靠插入占位，是否需要在 `WindowGroup` 层面对 toolbar 进行一次全量 `ToolbarItem` 重构？
