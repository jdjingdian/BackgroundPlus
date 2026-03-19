## 为什么
当前“自定义条目详情”在从列表切换时直接替换内容，窗口瞬间切换导致没有空间感；这种跳转在 macOS 上显得突兀，用户看不到“从哪里来”的线索。与此同时，列表行右侧的切换控件虽然使用 `Toggle`，但默认是方框勾选样式，和“可切换”的语义不匹配，不够直观。这个变更的目标是让导航行为和控件视觉都更贴近用户期望：详情像页面从右侧滑入一样呈现，而列表开关则看起来像开关控件，更容易理解状态的变化。

## 变更内容
1. 将主界面的列表与详情之间的切换迁移到带动画的导航流，详情视图从右侧滑入，返回时同步滑出，保持滚动位置和上下文。
2. 将列表中表示启用状态的控件改成开关样式（macOS 风格的 `SwitchToggleStyle`），并在视觉与辅助功能层面强化其切换语义。

## 功能 (Capabilities)
### 新增功能
- `custom-detail-entry-transition`: 定义基于 `NavigationSplitView` / 自定义动画的详情面板呈现逻辑，让 `BackgroundItemDetailView` 在被选中后貌似从右侧滑入，并在返回时滑出，同时维护导航上下文。
- `list-toggle-switch-style`: 规范列表行切换控件使用开关样式（如 `SwitchToggleStyle`），并定义交互、辅助标识与布局约束，确保状态明确、可点击区域舒适。

### 修改功能
- `btm-entry-management`: 由于切换方式和动画行为发生改变，现有的条目管理规范在导航上下文和交互反馈方面需要补充说明。

## 影响
- `BTMShellView` 和 `BTMEntryListContainerView`：需调整 detail 侧内容呈现方式（可能使用 `NavigationStack`、`.transition` 或 `.navigationDestination`）以支持滑动动画与状态管理。
- `BackgroundItemDetailView`：可能要暴露分离的初始化与动画上下文，确保 view update 不会破坏动画体验。
- `BTMEntryListRowView`：切换控件样式变更到 `SwitchToggleStyle`，并可能需新增辅助 Label。
- 其它与选择和滚动控制有关的代码（例如 `ScrollViewReader`/`selectedEntryID`）要保持在动画发生时维持列表上下文。
