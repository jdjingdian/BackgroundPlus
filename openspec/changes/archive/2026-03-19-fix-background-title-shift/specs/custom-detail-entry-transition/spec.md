## MODIFIED Requirements

### Requirement: 自定义条目详情以滑动方式呈现
系统 SHALL 将 `BackgroundItemDetailView` 视为“从右侧滑入”的页面，只有选中某条目时 detail 区域才插入该视图，并且动画期间原列表继续存在于 split view 背景以保持上下文。导航栏必须在主列表与详情之间共享一致的布局区域：即便系统返回按钮在详情中出现，标题文本与工具栏控件也不能发生水平偏移，应该在列表与详情之间保持相同的左侧留白与对齐。

#### 场景: 通过箭头或行点击进入详情
- **当** 用户在列表行点击 `→` 按钮或点击行本身（`onTapGesture`），且该条目可打开自定义详情
- **那么** detail 区域必须以向内滑动的过渡进入 `BackgroundItemDetailView`，并保持 `BTMEntryListContainerView` 的滚动位置与 `selectedEntryID` 状态

#### 场景: 从详情返回列表
- **当** 用户在 toolbar 或其它导航入口触发返回动作
- **那么** `BackgroundItemDetailView` 必须以向外滑动的过渡退出，并让 `BTMEntryListContainerView` 继续可交互（任意 `ScrollViewReader` 位置保持不变）

#### 场景: 切换不同条目
- **当** 当前详情已经显示，用户在列表中选中另一个条目
- **那么** detail 区域必须先以滑出动画卸下旧的 `BackgroundItemDetailView`，随后滑入新的实例，并且 `selectedEntryID` 与 `customDetailEntry` 始终与最新条目保持一致

#### 场景: 详情标题栏保持视觉位置
- **当** 系统展示 `BackgroundItemDetailView`，且 navigation toolbar 需要插入返回按钮
- **那么** 标题“后台项目管理”与其他 toolbar 控件必须保持与列表视图相同的左部留白和水平中心，即便返回按钮可见也不能让文字向右移动，toolbar 需预留返回按钮区域或以恒定占位占据相同宽度
