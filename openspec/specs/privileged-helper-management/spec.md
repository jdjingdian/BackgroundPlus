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

### 需求:受控特权调用边界
系统 SHALL 通过 helper 暴露受控接口执行特权任务，主程序禁止绕过 helper 直接执行 BTM 特权修改；该边界不仅适用于读取 dump，也必须覆盖单点删除与开关写入。系统 MUST 在读取路径中显式区分“权限前置条件未满足”与“解析失败”，并记录可用于诊断的探针结果。

#### 场景:请求读取 BTM dump
- **当** 主程序请求读取 BTM dump 数据
- **那么** 请求必须通过 helper 接口完成并返回结果给主程序

#### 场景:访问前置条件不足时的受控降级
- **当** helper 以 root 运行但访问 BTM 目录返回 `EPERM`
- **那么** helper 必须记录访问探针日志并降级到 `sfltool dumpbtm` 路径，不得直接返回空结果

#### 场景:主程序尝试直连特权写操作
- **当** 主程序代码路径尝试直接执行特权写操作
- **那么** 系统必须拒绝该路径并要求通过 helper 受控接口执行

### 需求:Helper 版本一致性前置校验
系统 MUST 在执行任何高风险 helper 特权调用前完成 app 与 helper 的版本一致性校验；该前置校验必须覆盖写操作调用。

#### 场景:检测到 helper 版本与 app 版本不匹配
- **当** app 完成 helper 握手并发现版本不匹配
- **那么** 系统必须拒绝执行后续特权调用（含写操作）并将状态标记为“需重装 helper”

#### 场景:版本一致后允许写调用
- **当** app 检测到 helper 版本与 app 版本匹配且写能力可用
- **那么** 系统必须允许进入正常 helper 写调用流程

### 需求:稳定的 helper 能力读取接口
helper MUST 提供可读取版本与能力元信息的稳定接口，且该接口在后续版本中禁止移除或破坏兼容；能力元信息必须包含写能力开关与写 schema 版本。helper MUST 将 Full Disk Access（FDA）前置条件纳入读写能力判定。

#### 场景:app 请求读取 helper 能力信息
- **当** app 发起能力读取请求
- **那么** helper 必须返回至少包含 helper 版本、接口版本、写能力标记与写 schema 版本的结果

#### 场景:未开启 FDA
- **当** helper 访问 BTM 存储返回权限受限且判定为未满足系统访问前置条件
- **那么** helper 必须将写能力标记为不可用并向上游返回可诊断状态

#### 场景:开启 FDA 后能力恢复
- **当** 用户在系统设置为应用开启完全磁盘访问且 helper 探针确认可读可写
- **那么** helper 必须将写能力标记为可用，并允许进入直读 BTM 文件路径

### Requirement: 版本不匹配时强提示并引导重装

当系统检测到 helper 版本不匹配或能力读取失败时，系统 MUST 向用户展示高优先级强提示，并提供明确的重装 helper 操作入口。

#### Scenario: 版本不匹配触发强提示

- **WHEN** app 判断 helper 版本不匹配
- **THEN** 系统必须展示强提示，说明风险与“重装 helper”操作

#### Scenario: 能力读取失败触发同级处置

- **WHEN** app 无法成功读取 helper 能力信息
- **THEN** 系统必须按不兼容处理，阻断特权调用并提示用户重装 helper

