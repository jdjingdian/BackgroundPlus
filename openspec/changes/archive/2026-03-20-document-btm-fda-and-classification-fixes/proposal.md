## 为什么

近期在真实机上验证 helper 读取 BTM 文件时，出现了“helper 进程已是 root 但仍无法读取 `/var/db/com.apple.backgroundtaskmanagement`”的现象，导致读取链路不稳定且行为与 `sfltool dumpbtm` 不一致。排查后确认这是系统访问控制与解析兼容性共同导致的问题，必须把实验结论和已完成修复正式沉淀，避免后续回归。

## 变更内容

- 记录并固化实验结论：仅有 root 身份不足以访问 BTM 存储；当用户在系统设置为应用开启“完全磁盘访问（Full Disk Access）”后，helper 才能稳定枚举并读取 BTM 文件。
- 修正 helper 的 BTM 直读解析兼容性：补齐 `CFKeyedArchiverUID` 解析、`type/disposition` 文本映射，避免“全部 enabled”误判。
- 增加 helper 调试对比能力：在同一次请求中输出 `btm_file` 与 `sfltool` 的统计对比，用于快速定位差异来源。
- 修正分类误差：对 `Contents/Library/LoginItems/*.app` 与 `identifier` 前缀 `4.` 的子项按后台项处理，避免将背景 helper 误归类到“登录时打开”。
- 补齐父子关系来源：当 `parentIdentifier` 缺失时回退使用 `container`，提升后续分类与联动分析准确性。

## 功能 (Capabilities)

### 新增功能
- 无

### 修改功能
- `privileged-helper-management`: 补充 helper 访问 BTM 文件的前置条件与可观测性要求，记录 FDA 前置条件与诊断行为。
- `btm-entry-management`: 调整 BTM 直读解析与分类规则，确保“登录时打开/允许在后台”分组更接近系统真实语义。

## 影响

- 受影响代码：`BackgroundPlusHelper/main.swift`、`BackgroundPlus/BTMCore.swift`。
- 受影响行为：helper 能力探测、BTM dump 来源对比日志、条目启用状态判断、列表分组分类。
- 兼容性说明：该变更不新增外部 API，但会改变部分条目的分组结果与只读/可写判定前提说明。
