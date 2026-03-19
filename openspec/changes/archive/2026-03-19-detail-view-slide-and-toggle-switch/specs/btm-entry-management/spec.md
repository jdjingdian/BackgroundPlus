## MODIFIED Requirements

### Requirement: BTM 条目可视化
系统 SHALL 提供以“侧栏功能切换 + 主区域列表”为结构的 BTM 条目展示。主区域列表必须包含每行的 icon、主标题、副标题、开关状态与行级 `→` 操作入口；当 helper 已安装时，数据源必须来自真实系统 dump 结果而非固定占位数据；在重构后该能力可由独立列表容器模块实现，但展示结果必须保持等价且可操作。每行开关不得复用方框样式；它必须以 macOS switch 风格呈现并暴露辅助标识，确保操作与右侧 `→` 按钮互不干扰。每次点击 `→` 或行内操作进入自定义详情时，detail 视图应以从右侧滑入的过渡显示，并在返回列表时以对应的滑出动画退出，滚动位置与 `selectedEntryID` 状态必须被保留。

#### Scenario: 成功展示条目

- **GIVEN** 系统可获取 dumpbtm 输出
- **WHEN** 用户打开“后台模块”功能页
- **THEN** 用户可以在主区域看到结构化条目列表，以及每行的 icon、基础信息和操作控件

#### Scenario: helper 未安装

- **WHEN** 用户打开“后台模块”功能页且 helper 尚未安装
- **THEN** 系统必须展示“需先安装 helper”的状态提示和前往设置的引导

#### Scenario: 解析不完整

- **GIVEN** dumpbtm 输出存在缺字段或格式漂移
- **WHEN** 系统完成解析
- **THEN** 系统应提示“解析不完整”并继续展示可用条目

#### Scenario: 侧栏仅用于功能切换

- **WHEN** 用户浏览应用侧栏
- **THEN** 侧栏必须展示功能入口而不是完整 BTM 条目明细

#### Scenario: 行内开关与跳转互不干扰

- **GIVEN** 用户位于某条目行
- **WHEN** 用户点击开关或点击 `→` 按钮
- **THEN** 系统必须仅触发对应操作，且不得误触发另一个控件行为

#### Scenario: 进入详情保持上下文

- **GIVEN** 用户点击某行的 `→` 按钮
- **WHEN** `BackgroundItemDetailView` 显示
- **THEN** 系统必须以从右侧滑入的动画呈现详情，并让列表继续维持当前滚动与选中状态

#### Scenario: 开关必须是 switch 样式

- **WHEN** 用户查看任意条目行中的开关控件
- **THEN** 该控件必须呈现为 macOS switch 风格，且 `accessibilityLabel` 与 `accessibilityValue` 表示当前状态

## ADDED Requirements

## REMOVED Requirements
