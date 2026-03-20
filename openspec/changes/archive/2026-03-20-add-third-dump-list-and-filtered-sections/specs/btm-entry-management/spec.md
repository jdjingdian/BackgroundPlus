## ADDED Requirements

### Requirement: 完整 Dump 数据分组可见
系统 SHALL 在 BTM 管理侧栏新增“完整 Dump 数据”分组，并在主区域展示解析后的完整条目集合；该分组必须不受“分类确认”与“开关开启”过滤限制。

#### Scenario: 查看完整 Dump 数据
- **GIVEN** helper 已安装且系统已获取 dump 结果
- **WHEN** 用户在侧栏选择“完整 Dump 数据”
- **THEN** 系统必须展示当前 dump 解析得到的全部条目

#### Scenario: 完整分组在前两组为空时仍可访问
- **GIVEN** “登录时打开”和“允许在后台”分组经筛选后均为空
- **WHEN** 用户切换到“完整 Dump 数据”
- **THEN** 系统必须仍可展示完整条目，并保持详情跳转与开关交互能力

## MODIFIED Requirements

### Requirement: BTM 条目可视化
系统 SHALL 提供以“侧栏功能分组 + 主区域列表”为结构的 BTM 条目展示。侧栏必须至少包含“登录时打开”“允许在后台”“完整 Dump 数据”三个入口；主区域列表必须仅展示当前入口对应的条目集合，并包含每行的 icon、主标题、副标题、开关状态与行级 `→` 操作入口。当 helper 已安装时，数据源必须来自真实系统 dump 结果而非固定占位数据。

#### Scenario: 进入登录时打开分组
- **WHEN** 用户在侧栏选择“登录时打开”
- **THEN** 系统必须只展示满足“已确认分类为登录时打开且开关为开启状态”的条目

#### Scenario: 进入允许在后台分组
- **WHEN** 用户在侧栏选择“允许在后台”
- **THEN** 系统必须只展示满足“已确认分类为允许在后台且开关为开启状态”的条目

#### Scenario: 分组空状态独立展示
- **GIVEN** 当前分组没有可展示条目
- **WHEN** 用户进入该分组
- **THEN** 系统必须展示该分组的空状态提示，且不得影响另一个分组的可访问性

#### Scenario: 分类不完整时可用优先
- **GIVEN** dumpbtm 输出存在缺字段或格式漂移，导致部分条目分类不确定
- **WHEN** 系统完成解析与分类
- **THEN** 系统必须提示“分类不完整”，并将不确定条目仅保留在“完整 Dump 数据”分组中展示

#### Scenario: helper 未安装
- **WHEN** 用户打开任一 BTM 分组且 helper 尚未安装
- **THEN** 系统必须展示“需先安装 helper”的状态提示和前往设置的引导

#### Scenario: 行内开关与跳转互不干扰
- **GIVEN** 用户位于某条目行
- **WHEN** 用户点击开关或点击 `→` 按钮
- **THEN** 系统必须仅触发对应操作，且不得误触发另一个控件行为

#### Scenario: 进入详情保持上下文
- **GIVEN** 用户点击某行的 `→` 按钮
- **WHEN** `BackgroundItemDetailView` 显示
- **THEN** 系统必须以从右侧滑入的动画呈现详情，并让对应分组列表继续维持当前滚动与选中状态

#### Scenario: 开关必须是 switch 样式
- **WHEN** 用户查看任意条目行中的开关控件
- **THEN** 该控件必须呈现为 macOS switch 风格，且 `accessibilityLabel` 与 `accessibilityValue` 表示当前状态

## REMOVED Requirements
