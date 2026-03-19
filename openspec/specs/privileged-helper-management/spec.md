# privileged-helper-management 规范

## 目的
定义特权 helper 的身份约束、安装引导与受控调用边界，确保
BTM 特权链路可控、可观测、可恢复。

## 需求
### Requirement: Helper Target 与身份约束

系统 SHALL 提供独立的特权 helper target，且其包标识必须为
`cn.magicdian.BackgroundPlus.helper`，用于承载 BTM 相关特权任务。

#### Scenario: 构建产物包含 helper target

- **WHEN** 开发者执行工程构建
- **THEN** 构建产物中必须包含 `cn.magicdian.BackgroundPlus.helper`
  对应 target 且可被主程序引用

### Requirement: SMJobBless 安装引导

系统 SHALL 在设置界面提供 helper 安装引导，并明确展示未安装、
安装中、已安装、安装失败四类状态；在 UI 模块化重构后，该安装
引导必须由独立设置容器模块承载，且安装状态来源保持一致。

#### Scenario: 用户主动安装 helper

- **GIVEN** helper 状态为未安装
- **WHEN** 用户在设置界面触发安装
- **THEN** 系统必须发起 SMJobBless 安装流程并在界面实时更新
  安装状态

#### Scenario: 安装失败反馈

- **WHEN** SMJobBless 返回失败
- **THEN** 系统必须展示可读的失败信息和重试入口

### Requirement: 受控特权调用边界

系统 SHALL 通过 helper 暴露受控接口执行特权任务，主程序禁止绕过
helper 直接执行 BTM 特权修改。

#### Scenario: 请求读取 BTM dump

- **WHEN** 主程序请求读取 BTM dump 数据
- **THEN** 请求必须通过 helper 接口完成并返回结果给主程序

#### Scenario: 主程序尝试直连特权写操作

- **WHEN** 主程序代码路径尝试直接执行特权写操作
- **THEN** 系统必须拒绝该路径并要求通过 helper 受控接口执行

### Requirement: Helper 版本一致性前置校验

系统 MUST 在执行任何高风险 helper 特权调用前完成 app 与 helper 的版本一致性校验；当版本不匹配时，系统必须阻断后续特权调用。

#### Scenario: 检测到 helper 版本与 app 版本不匹配

- **WHEN** app 完成 helper 握手并发现版本不匹配
- **THEN** 系统必须拒绝执行后续特权调用，并将状态标记为“需重装 helper”

#### Scenario: 版本一致后允许继续调用

- **WHEN** app 检测到 helper 版本与 app 版本匹配
- **THEN** 系统必须允许进入正常 helper 调用流程

### Requirement: 稳定的 helper 能力读取接口

helper MUST 提供可读取版本与能力元信息的稳定接口，且该接口在后续版本中禁止移除或破坏兼容。

#### Scenario: app 请求读取 helper 能力信息

- **WHEN** app 发起能力读取请求
- **THEN** helper 必须返回至少包含 helper 版本与接口版本的结果

#### Scenario: helper 升级后保持能力读取接口可用

- **WHEN** helper 升级到后续版本
- **THEN** app 仍必须能够通过同一能力读取接口完成兼容性判断

### Requirement: 版本不匹配时强提示并引导重装

当系统检测到 helper 版本不匹配或能力读取失败时，系统 MUST 向用户展示高优先级强提示，并提供明确的重装 helper 操作入口。

#### Scenario: 版本不匹配触发强提示

- **WHEN** app 判断 helper 版本不匹配
- **THEN** 系统必须展示强提示，说明风险与“重装 helper”操作

#### Scenario: 能力读取失败触发同级处置

- **WHEN** app 无法成功读取 helper 能力信息
- **THEN** 系统必须按不兼容处理，阻断特权调用并提示用户重装 helper
