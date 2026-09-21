# UGC 与内容安全 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在用户内容对其他人可见时，提供审核、举报、拉黑、下架和封禁能力。

**Architecture:** 原生客户端负责入口和本地过滤，服务端负责最终审核与权限。本地私密手记继续不进入 UGC 流程。

**Tech Stack:** UIKit、Swift Concurrency、XCTest。

## Global Constraints

- 本计划的触发条件是「内容可被其他用户看到」。
- 未通过审核的内容不进入公开列表。
- 拉黑立即影响内容和消息可见性。

---

### Task 1: 范围门禁

**Files:** Create `docs/ugc-scope-decision.md`.

- [ ] 记录是否公开手记、头像、昵称、评论、消息或 AI 结果。
- [ ] 若全部为否，以「不适用」结论关闭本计划。

### Task 2: 内容状态与举报

**Files:** Create `Integration/Moderation/ModerationModels.swift`, `ModerationService.swift`; Test `Tests/ModerationTests.swift`.

- [ ] 先写 pending/approved/rejected 可见性和举报原因测试。
- [ ] 实现举报作品/用户、敏感词预检和审核状态。

### Task 3: 拉黑与管理界面

**Files:** Create `BlockedUserStore.swift`; Modify relevant public-content controllers; Test `ModerationTests.swift` and UI tests.

- [ ] 先写拉黑后内容/消息被过滤、解除后恢复的测试。
- [ ] 实现举报、拉黑、黑名单和联系我们入口。

