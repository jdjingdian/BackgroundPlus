# btm-entry-manager

## Why

在 macOS 14+ 的 SMAppService/SMJobBless 开发中，调试构建与 CI 打包构建的安装路径不一致，常导致 BTM 条目并存、代际累积与状态冲突。现有 `sudo sfltool resetbtm` 粒度过粗，会破坏全局环境，不适合开发者做“单目标恢复”。

需要一款开发者工具，支持可视化查看 BTM 条目，并执行精确单点删除；同时具备可追溯备份与强确认机制，降低误删风险。

## What Changes

- 提供 SwiftUI 界面展示 BTM 条目，读路径允许通过 `sfltool dumpbtm` 解析。
- 提供“单目标删除”能力，写路径采用数据库直连方式（非命令行删除）。
- 删除前强制备份系统目标文件；UI 提供“打开备份目录”入口。
- 删除流程引入风险分级与分层确认（一次确认/二次确认/文本挑战）。
- 接入 Swift Testing，补充基础 UI 测试，覆盖解析、计划、风险、确认与结果反馈。
- UI 文案全面使用 Localizable 资源，支持中文与英文，不允许硬编码业务字符串。

## Non-Goals

- 不提供全局 BTM 重置能力。
- 不承诺对 Apple 私有数据结构的长期稳定适配（跨大版本可能需要更新适配层）。
- 不在本变更中实现自动一键恢复系统状态（提供备份与恢复线索即可）。

## Success Criteria

- 能展示 identifier/type/url/generation/parent-child 等关键信息。
- 能对单个目标执行可预览（Dry-Run）的精准删除。
- 任意写入操作均有成功备份，否则阻断执行。
- 高风险删除必须经过强化确认。
- 所有用户可见字符串来自 Localizable（zh-Hans/en），并有测试覆盖。
