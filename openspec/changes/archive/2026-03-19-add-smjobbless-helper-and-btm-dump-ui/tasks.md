## 1. Helper Target 与工程配置

- [x] 1.1 在 `BackgroundPlus.xcodeproj` 中新增 helper target，Bundle ID 设为 `cn.magicdian.BackgroundPlus.helper`
- [x] 1.2 配置 helper 的 Info.plist、launchd plist、签名与必要 entitlement
- [x] 1.3 在主程序 target 中完成对 helper 的嵌入与引用配置，确保可随主程序构建

## 2. SMJobBless 安装与状态管理

- [x] 2.1 实现 App 端 HelperInstallManager，封装安装、状态检测与错误映射
- [x] 2.2 实现 SMJobBless 安装调用链，并处理未授权/签名异常/通用失败分支
- [x] 2.3 增加 helper 安装状态模型（未安装、安装中、已安装、失败）与状态持久化策略

## 3. 特权通信与 BTM 读取链路

- [x] 3.1 定义 App 与 helper 的通信协议（请求/响应结构、版本字段、错误码）
- [x] 3.2 在 helper 实现 BTM dump 获取接口，并返回可解析的原始输出
- [x] 3.3 在 App 服务层接入 helper dump 读取，复用现有解析器转换为 BTM 条目模型

## 4. UI 集成（设置页 + 列表页）

- [x] 4.1 新增设置界面并接入 helper 安装引导、状态展示与重试操作
- [x] 4.2 在列表页接入真实数据加载流程，展示 loading/empty/error/loaded 状态
- [x] 4.3 当 helper 未安装时，在主界面展示引导提示并提供前往设置入口

## 5. 验证与回归

- [x] 5.1 为 helper 安装状态机与错误映射补充单元测试
- [x] 5.2 为 BTM dump 读取到 UI 展示链路补充集成测试或可替代验证用例
- [x] 5.3 执行构建与基础 UI 回归，更新文档说明已知限制与排错步骤
- [x] 5.4 修复大体积 dump 输出导致 helper 阻塞与主线程加载卡顿问题
