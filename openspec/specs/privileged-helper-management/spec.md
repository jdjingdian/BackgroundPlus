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
安装中、已安装、安装失败四类状态。

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
