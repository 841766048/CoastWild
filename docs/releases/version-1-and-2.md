# 第一版 / 第二版内购分支管理

## 发布边界

- 第一版：`codex/native-uikit`，删除项目自身的支付 API、StoreKit 交易实现、JS 购买及金币消息、恢复购买入口、购买事件上报和购买专用配置。
- 第二版：`codex/native-coin-learning`，保留现有充值、验单、交易恢复、本地金币账本、确认解锁及阅读闭环。
- 这次只修改本地 Git 分支，不推送、不把第二版发布到主分支。
- 原工作目录的未提交隐私资源改动不属于本次版本拆分，不合入本次提交。

## 为什么需要同步删除历史

在主分支删除文件后，仅保留旧功能分支不动，未来普通三方合并可能沿用主分支的删除。为避免这一点，第二版分支先合入第一版删除提交的历史，然后针对本次删除所影响的生产代码和测试恢复第二版已有内容。这样主分支删除提交已经是第二版的祖先，后续合并会把第二版的完整实现带回。

只恢复本次删除涉及的路径，不使用全局 `ours` 策略吞掉其他主分支修改。第一版专用的“无内购”边界测试不进入第二版。两分支都保留工程生成时的签名团队修复：将原主分支 App target 的 `2FXAU7VW4X` 写入 `project.yml`，避免重新生成工程后丢失团队。另保留 `--ui-testing-slow-recovery` 专用夹具从2秒延长至5秒的测试稳定性修复，正常登录不受影响。

## 第二版发布时

先保证工作目录没有未处理修改，在主分支执行正常合并：

```sh
git switch codex/native-uikit
git merge codex/native-coin-learning
```

如果主分支位于另一个 worktree，请在该 worktree 内操作，不要强行重复检出同一分支。后续若主分支又有变更，仍需检查冲突和重跑构建、支付恢复及金币闭环测试；不要重新应用第一版的删除提交，也不要在冲突时批量选择删除内购的一侧。

## 验收方法

1. 第一版：运行核心测试、无内购边界测试、资料页和免费学习 UI 测试，以及 Release 模拟器构建。
2. 第二版：确认 `CoastWild/`（仅允许上述 UI 测试夹具差异）、`Tests/`、`UITests/` 与拆分前 `1e52224` 一致，再运行核心测试；工程配置仅允许签名团队修复及对应再生成差异。所有内购代码必须完全一致。
3. 使用 `git merge-tree --write-tree codex/native-uikit codex/native-coin-learning` 预演普通合并；要求无冲突，结果树的内购代码与第二版一致。
4. 原有本地钱包限制不变，真实 Apple 沙盒支付是否成功仍需独立端到端验证。

## 本次分支验证记录（2026-09-23）

- 第一版删除提交：`131ea8b`（主分支 `codex/native-uikit`）。
- 第二版保护合并：`1397350`，父提交为原第二版 `1e52224` 和第一版 `131ea8b`。
- 核心测试：第一版240项通过；第二版283项通过。
- 第一版 Release 模拟器构建通过；账号页、免费学习、自动登录 UI 分别通过。测试环境问题及修复详见 `docs/superpowers/plans/v1-removal-report.md`，不声称所有首次运行均通过。
- `git diff 1e52224 1397350 -- CoastWild Tests UITests ':!CoastWild/App/UITestRemoteAuthenticationAPI.swift'` 无差异，内购及金币业务代码原样保留。
- `git merge-base --is-ancestor codex/native-uikit codex/native-coin-learning` 成功；首次 `merge-tree` 预演结果与第二版树均为 `b1bb2d2d8dd17f8b9ca35086e35ec1ca5b8403d6`。预演不移动主分支。
- 原工作目录隐私图片配置的暂存区和工作区哈希始终为 `158ab104efbf52c545f7984f8b1d7e05601e0aa1`，未纳入提交。
- 第二版最终 Release 模拟器构建通过（`/tmp/coast-v2-release-preserved.log`）；购买100金币→确认消费30→完整阅读→重启保留的 UI 回归通过（`build/v2-merge-preservation.xcresult`）。该测试使用受控支付返回，不代表真实 Apple 沙盒付款验证。
- 最终独立复审无待修复问题，已复核分支祖先关系、普通合并树一致性和未提交资源保留情况。

## 当前工作目录

- 第一版主分支工程：`ios/.worktrees/v1-no-iap/CoastWild.xcworkspace`。
- 第二版工程：原始 `ios/CoastWild.xcworkspace`，仍在 `codex/native-coin-learning`。
- 两个工程 bundle id 相同，在同一模拟器安装会相互覆盖，请先确认打开的目录。没有推送远端或发布。

## 第三方与服务端边界

历史文档和 Git 历史保留，不代表被编入第一版应用。Adjust SDK 自带 ADJAppStorePurchase 等通用购买/验证类型；本次移除项目自身的购买接线及事件调用，不修改第三方源码，也不擅自删除普通归因功能，因此不声称包内连第三方 SDK 的购买相关符号都不存在。远程 H5 若独立展示支付内容，需要对应服务端页面同步关闭；本地不再注册或执行购买消息。
