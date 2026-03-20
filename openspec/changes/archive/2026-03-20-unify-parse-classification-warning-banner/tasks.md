## 1. 状态聚合模型调整

- [x] 1.1 在 BTM ViewModel 中新增“解析提示聚合状态”，统一表达 parse/classify 两类异常组合
- [x] 1.2 将现有解析结果标志映射到聚合状态，覆盖 none/parseOnly/classifyOnly/parseAndClassify 四种分支

## 2. 顶部 Banner 渲染统一

- [x] 2.1 将 BTM 页面顶部提示改为单条 banner 渲染，任意时刻最多展示一条
- [x] 2.2 复用 `StatusBanner`（或等效统一样式组件）接入 warning 样式与聚合文案 key
- [x] 2.3 删除/替换旧的多提示并列逻辑，避免“解析不完整”和“分类不完整”重复占行

## 3. 文案与回归验证

- [x] 3.1 新增或更新本地化文案 key：解析不完整、分类不完整、组合提示
- [x] 3.2 验证四种状态场景下 banner 显示正确且仅一行（none/parseOnly/classifyOnly/parseAndClassify）
- [x] 3.3 验证与现有 helper 状态提示共存时视觉风格一致且不影响列表交互
