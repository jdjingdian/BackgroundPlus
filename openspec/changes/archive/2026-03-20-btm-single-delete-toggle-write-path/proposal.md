## 为什么

当前应用已经能通过 helper + `sfltool dumpbtm` 读取并展示真实 BTM 数据，但“开关”和“删除”仍停留在 UI 覆盖与内存模拟，无法对系统状态产生可控写入。随着 UI 已稳定，需要尽快补齐受控写链路，支持单点删除与单条开关，避免继续依赖全局 `resetbtm`。

## 变更内容

- 新增 helper 写操作通道（XPC 路由、请求/响应模型、能力声明），统一承载 BTM 高风险写操作。
- 将“单点删除”从模拟删除升级为真实受控写入流程：删除前备份、执行、写后校验、结果回传。
- 将行内开关从本地 UI 状态升级为真实系统写入，写入成功后回刷 dump，失败时回滚 UI 并提示原因。
- 增加“写能力不可用”降级路径：在 helper 不支持当前系统 schema 时强制只读并提供可操作提示。
- 保持现有 Dry-Run、风险分级、确认机制不降级，并与真实写入执行链路对齐。

## 功能 (Capabilities)

### 新增功能

- `btm-write-operations`: 定义 helper 受控写接口、写能力探测、写入降级策略，以及单点开关/删除的执行与回执契约。

### 修改功能

- `btm-entry-management`: 将开关与删除从“仅 UI/模拟写入”升级为“真实系统写入”，并补充失败回滚与刷新一致性要求。
- `privileged-helper-management`: 扩展 helper 能力边界，新增写操作路由、版本/能力协商和不可用时阻断策略。

## 影响

- 受影响代码：
  - `BackgroundPlus/BackgroundPlus/HelperSupport.swift`（App 侧 helper 协议）
  - `BackgroundPlus/BackgroundPlusHelper/main.swift`（helper 路由与写执行入口）
  - `BackgroundPlus/BackgroundPlus/BTMCore.swift`（写入适配边界、错误语义）
  - `BackgroundPlus/BackgroundPlus/BTMViewModel.swift`（开关/删除执行链路与状态回刷）
- 受影响规范：
  - `openspec/specs/btm-entry-management/spec.md`
  - `openspec/specs/privileged-helper-management/spec.md`
- 风险与依赖：
  - 依赖 macOS 私有 BTM 存储结构，需通过 adapter/version 探测隔离版本差异。
  - helper 与 app 版本一致性校验将覆盖写操作前置条件。
