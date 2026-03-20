## 上下文

当前实现中，删除路径已通过 helper 执行真实写入，但开关路径仍返回 `toggle_not_supported_yet`。UI 文案会显示“当前写入适配器暂不支持开关操作”，这属于能力未实现，不是权限拒绝。

## 目标 / 非目标

**目标：**

- 打通 `toggle` 的 helper 写执行路径，使其与删除路径同级受控。
- 能力协商结果与真实实现保持一致（支持则放开，不支持则阻断）。
- 开关失败时保持可恢复：UI 回滚 + 明确错误 + 刷新一致性。
- 错误语义可区分：`permission_denied` 与 `toggle_not_supported` 不混淆。

**非目标：**

- 不重构删除链路。
- 不在本次引入批量开关。
- 不扩展超出当前条目模型的跨实体联动写入策略。

## 方案

1. helper 写执行补齐
- 在 `performWrite` 的 `.toggle` 分支实现真实写入，不再返回 `toggle_not_supported_yet`。
- 当运行环境明确不支持 toggle 写时，返回可区分错误码（例如 `toggle_not_supported`），而非权限错误。

1.1 开关位语义分流（新增）
- 登录时打开（`app (0x2)`）优先切换 `enabled` 位（`0x1`）。
- 后台运行（`daemon (0x10)`、`legacy daemon (0x10010)`）优先切换 `allowed` 位（`0x2`）。
- 对无法明确归类的条目，按“背景服务特征（LaunchDaemons/PrivilegedHelperTools/LoginItems helper）优先 `allowed`，否则 `enabled`”兜底。
- app 侧显示状态与 helper 写入语义必须一致，避免“写一个位、读另一个位”造成假状态。
- 真实机补充结论：`legacy daemon (0x10010)` 在不同时刻可能呈现 `enabled=true`（如 `0x3/0x9/0xb`）或 `enabled=false`（如 `0x8/0xa`）；系统设置开关的稳定变化位仍是 `allowed/disallowed`。

2. 能力协商对齐
- helper capabilities 在 toggle 可用时返回 `writeSchemaVersion >= 2`。
- app 侧继续依据 schema 版本决定 `toggleOperationsSupported`，但与 helper 实际能力保持一致。

3. UI 与状态一致性
- 保留当前 optimistic 更新策略。
- 写失败必须回滚 `entryEnabledOverrides`，并展示精确错误。
- 写成功后立即回刷 dump，避免本地状态长期偏离。

4. 错误分类
- `permission_denied`: 权限前置条件未满足（如 FDA/系统权限）。
- `toggle_not_supported`: 能力未实现或当前 schema 不支持。
- `execution_failed`: 运行时异常。

## 验证策略

- 单测：
  - toggle 成功：请求发出、回刷触发、错误清空。
  - toggle 失败：回滚发生、错误映射正确。
  - capability 协商：schema >=2 时开关可用；<2 时只读提示。
- 集成验证：
  - 以开关作为低风险写探针，确认写入后 dump 状态可观测变化。
