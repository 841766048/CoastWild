# Native V1 Capability Split Implementation Plan

> Execute using subagent-driven-development with independent review. No commits, merges or pushes are authorized.

**Goal:** 第一版移除业务 Web、JS Bridge、ATT/Adjust、预置 catalog；第二版保留完整能力。

**Architecture:** 保留原生登录及 Firebase 内容/手记链路。第一版无预置内容时使用空内容及明确的异步加载/错误/重试状态，缓存独立保留。第二版独立 worktree 保留 Web/追踪/预置内容/内购，记录未来恢复清单。

**Tech Stack:** Swift、UIKit、SwiftPM core tests、XcodeGen、现有 CocoaPods 与 Firebase。

## Global Constraints

- 主工作区是 codex/native-uikit，有用户未提交修改，不能 reset、清理或全量提交。
- 第二版 worktree 为 .worktrees/native-coin-learning，分支 codex/native-coin-learning。
- 删除本地 JSON 仅指预置业务内容及其兜底；保留云端缓存、JSON 编解码、手记、图片与同步队列、资源元数据。
- 保留隐私协议及课程正文容器。第一版不添加支付。第二版不删除支付。
- 不部署服务、不上传真实私人数据、不发起真实支付、不自动提交/合并/推送。
- 原始工作区快照在 /tmp/coast-v1-split.kqmmla/before.tar.gz；修改前 core 259 tests、1 skipped、0 failures。

## Task 1 — 第一版代码边界和公共内容状态

Files: CoastWild/App/AppDelegate.swift, Catalog.swift, PublicContentService.swift; CoastWild/Core 的业务 Web/Bridge/归因及远程登录相关文件；CoastWild/UI 的主/二级业务 Web 和首页/学习状态；对应 Tests、UITests；Podfile、project.yml、IntegrationConfig.plist、法律文案。

- [x] 增加边界测试，检查生产目录不存在 BusinessWebController、业务 Bridge、Adjust/ATT 以及 catalog.json 预置资源；先运行 `swift test --filter VersionOneBoundaryTests` 记录预期失败。
- [x] 登录成功统一 showMainInterface；移除业务 Web 专用类型、注入、回调、测试入口、归因初始化、上报、ATT 声明和 SDK 依赖。移除仅用于 Web 的策略请求，保留实际配置与认证。
- [x] 删除内置 catalog.json 加载与发布包资源；Catalog 初始化为有效缓存或空值。保留远程同步及手记。
- [x] 公共内容状态支持首次加载、失败、重试、成功空值；有效缓存失败后保留内容。首页/学习响应状态变化；已有功能不因空数组崩溃。
- [x] 更新相关测试，不通过删除有效网络/手记断言掩盖错误。`swift test` 全量验证。
- [x] project.yml 为工程配置源，用 XcodeGen 更新工程并保留当前签名/Firebase/资源变更；验证无 ATT/Adjust 链接。依赖工具限制或失败要如实报告。

## Task 2 — 第二版保留及恢复契约

Files: 第二版 Tests/VersionTwoBoundaryTests.swift、docs/releases/version-1-and-2.md；必要的当前 Web 相关差异文件。

- [x] 比较两版相关能力文件及当前未提交差异，不整覆盖第二版 AppDelegate/工程以免删除内购。
- [x] 第二版增加能力边界测试：业务 Web、Bridge、ATT/Adjust、catalog 及支付入口真实存在且相互调用。
- [x] 对确需的相关修复选择性移植；与移除范围无关的第一版云同步修改不自动整批移植。
- [x] `swift test` 验证第二版，维护未来合并必须保护/恢复的文件清单，不能声称普通 merge 保证恢复。

## Task 3 — 独立审阅与最终验证

- [x] 审阅第一版本次 diff 与第二版能力测试，修正范围和运行时缺陷。
- [x] 两版 core tests；第一版模拟器构建与适用 UI 测试；第二版构建条件不足则报告限制。
- [x] 检查 git status，确认原有修改/暂存内容保留，分支均未自动提交或合并。
- [x] 记录已测/未测、可恢复材料与后续合并步骤。
