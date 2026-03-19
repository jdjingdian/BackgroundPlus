## MODIFIED Requirements

### Requirement: SMJobBless 安装引导
系统 SHALL 在设置界面提供 helper 安装引导，并明确展示未安装、安装中、已安装、安装失败四类状态；在 UI 模块化重构后，该安装引导必须由独立设置容器模块承载，且安装状态来源保持一致。

#### Scenario: 用户主动安装 helper
- **GIVEN** helper 状态为未安装
- **WHEN** 用户在设置界面触发安装
- **THEN** 系统必须发起 SMJobBless 安装流程并在界面实时更新安装状态

#### Scenario: 安装失败反馈
- **WHEN** SMJobBless 返回失败
- **THEN** 系统必须展示可读的失败信息和重试入口
