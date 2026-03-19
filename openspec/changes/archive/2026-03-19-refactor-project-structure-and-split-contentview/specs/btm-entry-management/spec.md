## MODIFIED Requirements

### Requirement: 设置入口可达
系统 SHALL 提供可达的设置入口，使用户可以进入 helper 安装与状态管理页面；在 UI 目录重构后，入口路径与可达性必须保持不变，且用户无需感知内部模块拆分。

#### Scenario: 用户打开设置页
- **WHEN** 用户在应用中进入设置
- **THEN** 系统必须展示 helper 安装引导与当前状态信息

### Requirement: BTM 条目可视化
系统 SHALL 提供 BTM 条目列表与详情展示，至少包含 identifier、type、url、generation、parent-child 关系信息；当 helper 已安装时，数据源必须来自真实系统 dump 结果而非固定占位数据；在重构后该能力可由独立列表容器模块实现，但展示结果必须保持等价。

#### Scenario: 成功展示条目
- **GIVEN** 系统可获取 dumpbtm 输出
- **WHEN** 用户打开列表页
- **THEN** 用户可以看到结构化条目与关系信息

#### Scenario: helper 未安装
- **WHEN** 用户打开列表页且 helper 尚未安装
- **THEN** 系统必须展示“需先安装 helper”的状态提示和前往设置的引导
