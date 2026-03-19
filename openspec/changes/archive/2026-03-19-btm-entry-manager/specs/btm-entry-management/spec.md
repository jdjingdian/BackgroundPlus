# btm-entry-management Specification

## ADDED Requirements

### Requirement: BTM 条目可视化

系统 SHALL 提供 BTM 条目列表与详情展示，至少包含 identifier、type、url、generation、parent-child 关系信息。

#### Scenario: 成功展示条目

- **GIVEN** 系统可获取 dumpbtm 输出
- **WHEN** 用户打开列表页
- **THEN** 用户可以看到结构化条目与关系信息

#### Scenario: 解析不完整

- **GIVEN** dumpbtm 输出存在缺字段或格式漂移
- **WHEN** 系统完成解析
- **THEN** 系统应提示“解析不完整”并继续展示可用条目

### Requirement: 单点删除与 Dry-Run

系统 SHALL 在执行写入前生成 Dry-Run 删除计划，展示目标条目与联动条目，并要求用户确认。

#### Scenario: 删除前预览

- **GIVEN** 用户选择一个目标条目
- **WHEN** 用户进入删除流程
- **THEN** 系统展示 Dry-Run 清单与影响摘要

### Requirement: 写入前强制备份

系统 SHALL 在每次写入前完成系统目标文件备份；备份失败时 SHALL 阻断写入。

#### Scenario: 备份成功后执行写入

- **GIVEN** 用户确认删除
- **WHEN** 备份成功
- **THEN** 系统才可执行写入事务

#### Scenario: 备份失败阻断

- **GIVEN** 用户确认删除
- **WHEN** 备份失败
- **THEN** 系统必须停止写入并展示错误提示

### Requirement: 风险分级确认

系统 SHALL 根据删除计划和不确定性进行风险分级，并应用对应确认门槛。

#### Scenario: 低风险

- **GIVEN** 风险等级为 low
- **WHEN** 用户执行删除
- **THEN** 系统要求一次确认

#### Scenario: 中风险

- **GIVEN** 风险等级为 medium
- **WHEN** 用户执行删除
- **THEN** 系统要求二次确认并显示影响面

#### Scenario: 高风险

- **GIVEN** 风险等级为 high
- **WHEN** 用户执行删除
- **THEN** 系统要求文本挑战确认与延时确认按钮

### Requirement: 备份路径可达

系统 SHALL 在 UI 中提供“打开备份目录”能力，并在操作结果中展示本次备份路径。

#### Scenario: 删除完成后查看备份

- **GIVEN** 删除流程已结束
- **WHEN** 用户点击“打开备份目录”
- **THEN** 系统打开对应备份位置供用户恢复参考

### Requirement: 本地化支持

系统 SHALL 使用 Localizable 资源管理 UI 字符串，支持中文和英文，且不允许硬编码业务字符串。

#### Scenario: 中文展示

- **GIVEN** 系统语言为中文
- **WHEN** 用户浏览界面
- **THEN** 关键 UI 文案显示中文

#### Scenario: 英文展示

- **GIVEN** 系统语言为英文
- **WHEN** 用户浏览界面
- **THEN** 关键 UI 文案显示英文
