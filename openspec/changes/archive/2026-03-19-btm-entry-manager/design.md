# Design: btm-entry-manager

## Overview

该工具采用“读写分离”：

- 读路径：基于 `sfltool dumpbtm` 解析，服务 UI 展示与关系建模。
- 写路径：数据库直连，执行事务化单点删除。

```text
┌────────────────────────────────────────────┐
│                 SwiftUI App                │
│ 列表/筛选/详情/Dry-Run/确认/结果/备份入口      │
└───────────────────┬────────────────────────┘
                    │
          ┌─────────▼─────────┐
          │   Domain Layer    │
          │ Entry/Risk/Plan   │
          └───────┬─────┬─────┘
                  │     │
          Read Path     Write Path
        (dumpbtm parse) (DB + Txn)
```

## Domain Model

- `BTMEntry`: uuid, identifier, type, disposition, url, generation, bundleID, parentIdentifier
- `EntryGraph`: parent-child 关系图
- `DeletePlan`: 目标条目、联动条目、必需联动标记、摘要
- `RiskLevel`: low/medium/high
- `OperationRecord`: 操作、备份、执行、校验与错误信息

## Read Path

- 数据源：`sfltool dumpbtm`
- 责任：结构化解析、类型标准化、关系图构建、UI 数据投影
- 异常策略：输出格式漂移时标记“解析不完整”，提升风险并提示用户

## Write Path

写入流程（强制）：

```text
[用户确认删除]
      │
      ▼
[创建备份] --失败--> [终止并提示]
      │成功
      ▼
[生成 Dry-Run + 风险分级 + 最终确认]
      │
      ▼
[事务删除]
      │
      ▼
[写后校验 + 记录 + UI提供打开备份目录]
```

### 删除计划策略

- 模式：`Safe`（默认）与 `Advanced`
- `Safe`：自动带上必需联动项，禁止取消必需项
- `Advanced`：允许调整可选联动项；任意手动改动即升为高风险并触发文本挑战确认

### 必需联动规则

- 目标为 app：其 Embedded 子项为必需联动
- 目标为 daemon/agent：默认仅删子项，父项非必需
- 目标为 developer：默认不自动扩展子树
- unknown 类型：不扩展联动，保持高风险

## Risk & Confirmation

- `low` -> 一次确认
- `medium` -> 二次确认 + 影响面预览
- `high` -> 文本挑战（输入标识片段）+ 延时确认按钮

触发高风险的典型条件：

- 计划删除条目数较大（如 >= 3）
- 包含 unknown 类型
- 存在高孤儿风险
- 解析字段缺失导致不确定性
- Advanced 模式下手动调整联动项

## Backup Strategy

- 每次写入前必须复制系统目标文件到备份目录
- 备份命名包含：时间戳 + 操作类型 + 目标标识摘要
- UI 固定提供“打开备份目录”按钮
- 操作记录关联备份路径，支持失误后的人工恢复

## Localization Strategy

- 所有 UI 字符串、风险文案、按钮文案、错误提示必须走 Localizable
- 语言：`zh-Hans` 与 `en`
- 禁止硬编码业务字符串（调试日志除外）
- 文案键应语义化并按模块分组（list/detail/confirm/result/error）

## Testing Strategy

### Swift Testing

- dumpbtm fixture 解析测试（正常、缺字段、格式漂移）
- DeletePlan 生成测试（Safe/Advanced）
- 必需联动与孤儿风险测试
- 风险分级与确认门槛测试
- 备份失败阻断写入测试
- 写后校验结果映射测试
- Localizable 键完整性测试（中英文）

### UI Testing

- 列表渲染与筛选
- Dry-Run 明细展示
- 不同风险级别下确认流程分支
- 删除结果页显示备份路径并可触发“打开备份目录”入口
- 中英文切换后关键文案可见

## Observability

每次操作记录至少包含：

- operationId, timestamp, targetIdentifier, riskLevel
- dryRunSummary, plannedEntries
- backupPath, backupStatus
- executionStatus, postCheckStatus
- errorCode, errorMessage
