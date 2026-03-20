## 1. Helper 开关写入实现

- [x] 1.1 在 `BackgroundPlusHelper/main.swift` 实现 `.toggle` 的真实写入执行逻辑
- [x] 1.2 移除 `toggle_not_supported_yet` 占位返回，并引入可区分的“能力不支持”错误码
- [x] 1.3 在 helper 日志中增加 toggle 成功/失败的关键诊断字段（identifier、目标状态、错误码）

## 2. 能力协商与客户端映射

- [x] 2.1 调整 helper capabilities 的 `writeSchemaVersion` 计算，使其反映 toggle 实际可用性
- [x] 2.2 校对 app 侧 `toggleOperationsSupported` 判定与 read-only banner 行为
- [x] 2.3 补齐错误码到 `BTMCoreError` 的映射，确保“权限不足”与“未实现/不支持”文案可区分

## 3. 回归与验证

- [x] 3.1 新增/更新单测：toggle 成功、toggle 失败回滚、unsupported 映射、permission_denied 映射
- [x] 3.2 更新发布自测清单：使用“开关操作”作为写入有效性的低风险验证步骤
- [x] 3.3 在真实机验证一次：切换后回刷 dump 状态与 UI 一致

## 4. 开关位语义对齐（新增）

- [x] 4.1 在 helper 端按条目语义选择切换位：login 切 `enabled`，background 切 `allowed`
- [x] 4.2 在 app 侧按同一语义解释条目开关状态，避免“写读位不一致”
- [x] 4.3 新增测试覆盖三类样本：登录项（0x2）、后台服务（0x10）、legacy 后台服务（0x10010）
