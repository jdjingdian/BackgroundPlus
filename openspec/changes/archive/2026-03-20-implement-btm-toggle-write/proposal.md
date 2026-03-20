## 为什么

当前界面提示“当前写入适配器暂不支持开关操作”不是权限报错，而是开关写入尚未实现导致的能力降级：

- helper capabilities 当前固定返回 `writeSchemaVersion=1`。
- app 侧将 `toggleOperationsSupported` 判定为 `supportsWriteOperations && writeSchemaVersion >= 2`。
- helper 在收到 `toggle` 写请求时直接返回 `write_not_supported / toggle_not_supported_yet`。

这意味着删除路径已落地但开关路径仍是空实现，用户无法用低风险操作验证 BTM 写入链路是否生效，只能依赖删除验证，风险更高。

## 变更内容

- 实现 helper 端 `toggle` 写操作执行路径，去掉 `toggle_not_supported_yet` 占位返回。
- 将开关能力从“版本门禁阻断”升级为真实可执行能力，并在能力协商中按实际支持情况返回 schema 版本。
- 保持现有删除链路不变，以“开关优先”作为写链路有效性的低风险验证路径。
- 明确区分“未实现/能力不可用”与“权限不足（FDA/系统权限）”错误语义，避免用户误判。

## 功能 (Capabilities)

### 修改功能

- `btm-write-operations`: 将“单条开关写操作”从规范目标补齐为可执行实现，要求能力协商与写执行一致。
- `btm-entry-management`: 将开关操作定义为推荐的低风险写验证入口，并强化失败回滚与刷新一致性约束。
- `privileged-helper-management`: 要求 helper 对“能力未实现”和“权限不足”返回可区分错误信号。

## 影响

- 受影响代码：
  - `BackgroundPlus/BackgroundPlusHelper/main.swift`
  - `BackgroundPlus/BackgroundPlus/HelperSupport.swift`
  - `BackgroundPlus/BackgroundPlus/BTMViewModel.swift`
  - `BackgroundPlus/BackgroundPlusTests/BackgroundPlusTests.swift`
- 受影响规范：
  - `openspec/specs/btm-write-operations/spec.md`
  - `openspec/specs/btm-entry-management/spec.md`
  - `openspec/specs/privileged-helper-management/spec.md`
- 风险与依赖：
  - 依赖当前目标系统上的 BTM schema 可稳定支持单条启用状态写入。
  - 需确保失败时 UI 回滚与真实状态回刷不冲突。
