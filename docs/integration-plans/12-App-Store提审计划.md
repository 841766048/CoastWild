# App Store 提审 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 使归档包、App Store Connect 配置、隐私声明和审核说明与实际功能一致。

**Architecture:** 自动扫描发现配置和资源错误，人工清单覆盖无法自动证明的 App Store Connect 与 Review Notes 项。

**Tech Stack:** xcodebuild、codesign、PlistBuddy、App Store Connect。

## Global Constraints

- 审核员能看到和测试实际发布功能。
- 不提交测试域名、Mock 标记、调试入口或无用 SDK/权限。
- Review Notes 如实描述账号、支付、UGC 和 AI。

---

### Task 1: 归档扫描

**Files:** Create `scripts/audit_archive.sh`; Create `docs/release-checklist.md`.

- [ ] 扫描 Bundle ID、版本、权限用途文案、SDK、URL Scheme、测试字符串和 ATS。
- [ ] 在干净 archive 上执行并保留报告。

### Task 2: App Store Connect

**Files:** Create `docs/app-store-connect-checklist.md`.

- [ ] 核对隐私标签、加密声明、商品、订阅、截图、支持 URL 和隐私 URL。
- [ ] 验证所有审核用入口可用，且无需隐藏操作。

### Task 3: Review Notes

**Files:** Create `docs/app-review-notes.md`.

- [ ] 写明产品用途、登录流程、注销入口、内购用途、恢复购买、UGC 范围和联系方式。
- [ ] 由产品和法务复核后再提交。

