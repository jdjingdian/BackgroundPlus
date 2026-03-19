## 为什么

当前 `BackgroundPlus` 虽然已有 BTM 管理的基础架构，但应用仍缺少可用的特权执行链路和可操作界面，导致“读取真实系统 BTM 数据”和“后续修改操作”无法落地。现在需要补齐 SMJobBless helper 与设置引导，才能把能力从骨架推进到可运行产品。

## 变更内容

- 新增特权 helper target（`cn.magicdian.BackgroundPlus.helper`），承载获取系统 BTM 数据与后续写操作入口。
- 新增设置页中的 helper 安装引导流程，用于检测、安装、状态反馈与故障提示。
- 将主界面接入真实 dump 数据展示，而不再仅停留在空壳状态。
- 调整 BTM 数据读取路径：优先通过 helper 提供的能力读取并返回给 UI。

## 功能 (Capabilities)

### 新增功能
- `privileged-helper-management`: 定义 helper target 的安装、状态检查、权限边界与调用约束。

### 修改功能
- `btm-entry-management`: 扩展为依赖 helper 的真实数据读取与界面展示要求，明确“可展示 dump 后数据”为最低可交付能力。

## 影响

- 受影响代码：Xcode project targets/build settings、App 端设置与列表 UI、BTM 服务层。
- 系统能力：涉及 SMJobBless/XPC、Launchd helper 生命周期、特权操作安全策略。
- 测试与验证：需要新增 helper 安装状态与数据展示流程的集成验证。
