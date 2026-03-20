## 1. 协议与能力协商

- [x] 1.1 在 `HelperSupport.swift` 与 helper `main.swift` 中新增写操作请求/响应模型与 `btm/write/v1` 路由定义
- [x] 1.2 扩展 helper capabilities 返回 `supportsWriteOperations` 与 `writeSchemaVersion`
- [x] 1.3 在 app 侧兼容性校验链路接入写能力判定，并形成只读降级状态

## 2. Helper 写执行骨架

- [x] 2.1 新增 helper 写执行入口，统一处理 `toggle` 与 `delete` 两类操作并返回标准错误码
- [x] 2.2 为写执行增加版本与参数校验（标识、mode、enabled）
- [x] 2.3 实现“写能力不可用”阻断与可观测日志

## 3. 单点删除真实写入

- [x] 3.1 将现有删除执行链路从内存适配器切换为 helper 写调用
- [x] 3.2 保持写前备份门禁：备份失败必须阻断删除
- [x] 3.3 实现写后校验与结果映射（success/failed/rolledBack）并回刷 dump

## 4. 行内开关真实写入

- [x] 4.1 将行内开关从 `entryEnabledOverrides` 本地覆盖升级为 helper 真实写入
- [x] 4.2 写成功后刷新列表并与系统状态对齐
- [x] 4.3 写失败时回滚 UI 状态并展示错误信息

## 5. 兼容性与回归验证

- [x] 5.1 补充单测：写能力协商、写路由错误映射、只读降级
- [x] 5.2 补充流程测试：单点删除成功/失败、开关成功/失败
- [x] 5.3 更新发布自测清单，纳入“写能力不可用”与“写后刷新一致性”检查项
