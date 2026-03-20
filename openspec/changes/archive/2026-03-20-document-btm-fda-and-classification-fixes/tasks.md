## 1. 访问前置条件与能力探测

- [x] 1.1 增加 helper 访问矩阵探针（stat/access/opendir/FileManager/外部命令）并验证 `EPERM` 来源
- [x] 1.2 在真实机完成 FDA 开关实验，确认“开启完全磁盘访问后 helper 才可访问 BTM 文件”
- [x] 1.3 将 FDA 前置条件纳入 helper 能力判定与只读降级语义

## 2. BTM 直读解析与对比诊断

- [x] 2.1 修复 `CFKeyedArchiverUID` 解析兼容问题，打通 `btm_file` 直读路径
- [x] 2.2 修正 `disposition`/`type` 文本映射，消除“非零即 enabled”误判
- [x] 2.3 增加 `btm_file` 与 `sfltool` 双源统计对比日志（entries/enabled/identifier 差异）

## 3. 分类修正与关系补齐

- [x] 3.1 在 helper 转换中补齐 `container -> Parent Identifier` 回退
- [x] 3.2 调整 App 端分类规则：`Contents/Library/LoginItems/` 与 `identifier=4.*` 优先归入后台项
- [x] 3.3 使用 `4.com.shreklaunch.mouseboostpro` 等样本完成误分类回归验证

## 4. 规范沉淀

- [x] 4.1 更新 `privileged-helper-management` 增量规范，记录 FDA 前置条件与降级诊断要求
- [x] 4.2 更新 `btm-entry-management` 增量规范，记录 LoginItems helper 子项归类修正与对比可观测性要求
- [x] 4.3 完成 proposal/design/tasks 产出并标记本轮工作已完成
