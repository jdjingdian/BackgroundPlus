# Tasks: btm-entry-manager

## 1. Scope and model

- [x] 1.1 定义领域模型：BTMEntry/EntryGraph/DeletePlan/RiskLevel/OperationRecord
- [x] 1.2 确定 Safe/Advanced 两种删除计划模式
- [x] 1.3 固化必需联动项与孤儿风险判定规则

## 2. Read path

- [x] 2.1 设计 dumpbtm 解析规范与容错策略
- [x] 2.2 构建关系图与展示视图模型
- [x] 2.3 建立解析异常到风险提升的映射

## 3. Write path

- [x] 3.1 设计数据库写入适配层与事务边界
- [x] 3.2 实现删除前 Dry-Run 计划生成
- [x] 3.3 实现写后一致性校验（残留/孤儿）

## 4. Backup and recovery guidance

- [x] 4.1 实现“写入前强制备份”机制
- [x] 4.2 规范备份命名与目录结构
- [x] 4.3 在结果页与历史页展示备份路径
- [x] 4.4 提供“打开备份目录”交互入口
- [x] 4.5 备份失败时阻断写入并提示可操作信息

## 5. UX and safeguards

- [x] 5.1 完成 low/medium/high 风险确认流程
- [x] 5.2 完成高风险文本挑战与延时确认
- [x] 5.3 Advanced 模式手动改动触发高风险升级

## 6. Localization

- [x] 6.1 建立 Localizable 文案键命名规范
- [x] 6.2 提供 zh-Hans 文案
- [x] 6.3 提供 en 文案
- [x] 6.4 移除硬编码业务字符串

## 7. Testing

- [x] 7.1 Swift Testing：解析器 fixture 全覆盖
- [x] 7.2 Swift Testing：DeletePlan/风险/确认门槛覆盖
- [x] 7.3 Swift Testing：备份失败阻断与回滚语义
- [x] 7.4 Swift Testing：Localizable 键完整性检查
- [x] 7.5 UI Testing：列表、确认流程、结果态、双语关键文案

## 8. Release readiness

- [x] 8.1 形成发布前自测清单（自动+手动）
- [x] 8.2 记录已知限制（私有结构变更风险）与应对策略
