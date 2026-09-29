# 第一版原生 / 第二版完整能力拆分

## 版本范围

| 能力 | codex/native-uikit | codex/native-coin-learning |
|---|---|---|
| 业务 Web 路由及二级业务 Web | 移除 | 保留 |
| 业务 JS Bridge、注入、事件和回调 | 移除 | 保留 |
| ATT、Adjust SDK、归因上报 | 移除 | 保留 |
| 内置 catalog.json 与预置内容兜底 | 移除 | 保留 |
| 隐私协议和课程正文展示 | 保留 | 保留 |
| 内购及金币闭环 | 不包含 | 保留 |
| 云端公共内容缓存、手记/图片保存及同步 | 保留当前实现 | 本轮未整批迁移第一版新增的云同步功能 |

第一版保留必要的 JSON 网络编解码、缓存文件、手记数据和资源目录元数据，不以“删除 JSON”名义清除用户数据。首次没有缓存时显示加载，失败可重试，远程有效空内容显示空状态；已校验缓存不因刷新失败丢失。

## 本地工作区

- 第一版：当前 `ios/CoastWild.xcworkspace`。
- 第二版：`ios/.worktrees/native-coin-learning/CoastWild.xcworkspace`。
- 当前主工作区仍在 `codex/native-uikit`；两版修改均未提交、未合并、未推送。
- 两版使用相同 Bundle ID，不在同一生产/个人模拟器安装以免覆盖数据。本轮使用新建的独立测试模拟器。

## 已修改的关键位置

- `CoastWild/App/AppDelegate.swift`：登录成功与恢复直接显示原生首页，移除 Web/归因依赖；保留已有 Firebase 和手记接线。
- `CoastWild/Core/RemoteSessionCoordinator.swift`：保留配置、OAuth、会话存储与退出竞态保护，移除 Web 专用策略请求。
- `CoastWild/App/PublicContentService.swift`、`Core/PublicContentLoader.swift`、`UI/PublicContentStatus.swift`：公共内容加载、缓存、错误及立即重试。
- `Podfile`、`Podfile.lock`、`project.yml` 与生成工程：不再包含 Adjust/ATT；保留其余锁定 Pods、Firebase、签名团队和用户资源修改。
- 第二版选择性补入测试协议 package 修复：开发环境使用测试 package，正式环境使用实际 Bundle ID，设备钥匙串仍使用实际 Bundle ID；未覆盖购买配置或删除支付功能。

## 测试数据边界

完整公共目录样例仅位于 `Tests/Fixtures/public-catalog.json`，不属于 App target。UI 测试通过自己的测试包读取样例，再以显式测试启动参数和环境变量传入 DEBUG App；Release 不编译该入口，也不包含该样例资源。正常用户启动不使用测试目录兜底。

公共内容发布脚本改为显式接收经过审阅的目录文件路径；可选第二版的预置目录作为发布来源。本轮未修改云端数据库或重新部署内容。

## 构建依赖维护

`project.yml` 明确声明现有 Pods project、xcconfig、聚合 target 和资源复制阶段，确保 XcodeGen 重建应用工程仍能连接剩余 Pods。保留 Firebase 的 `-ObjC`。

本机已有 Pods sandbox 通过 Swift/XcodeProj 做机械清理：移除 Adjust/AdjustSignature target 依赖、链接/搜索参数、复制脚本条目，并与审阅后的 Podfile.lock 一致。未升级其他依赖。干净环境仍需按 Podfile/lock 安装所声明的 Pods；现存未链接的供应商源码缓存不表示它被编入 App。

## 已核实证据

- 修改前第一版 core：259 项，1 项跳过，0 失败。
- 第一版边界测试先失败（16 条预期断言），移除后通过；最终提供现有 COAST_PUBLIC_MANIFEST 后，core 183 项全部通过，无跳过。减少的是被删除功能专用测试，网络/会话/缓存/手记测试保留。
- 内容发布工具：15 项通过。
- 第一版隐私同意、手动/自动登录进原生、内容失败→重试→有效空内容三项 UI 通过。
- 第一版真实测试服务 `getConfig`、`oauth` 请求成功，未发送归因声明；仅使用生成的测试 UUID，不打印/持久化登录令牌。
- 第一版独立模拟器无旧缓存启动，实际从 Firebase 下载公共目录及图片并显示首页；没有上传私人手记。
- 两版 Release 模拟器构建通过。第一版最终构建产物中未找到 catalog.json、测试 Fixtures、DEBUG 目录注入入口、Adjust framework/bundle、ATT 用途声明或相关业务 Web/SDK 符号。
- 第二版 core：286 项通过，保留 19 个 Bridge topic、Web、归因、目录和购买链路的边界测试通过。
- 原先已暂存的隐私图片配置补丁与修改前逐字一致。

第二版签名 Debug UI 在独立 iOS 18.6 模拟器通过：免费学习、购买→消费解锁→阅读→重启余额保留，共两项；支付返回由测试夹具提供，并非真实 Apple 付款。

第一版课程 Web 正文与原生课程详情、出游/手记创建保存及退出 UI 回归均通过；加上前述三项，共五项通过。最终复审确认外部 fixture 仅在 DEBUG 下接收且只编入测试包，版本范围与源码质量没有阻断性问题。不能将 core 或构建成功当作真实支付/归因/H5 全流程证明。

## 未来第二版合并

不能直接依赖普通 merge 自动恢复：第一版删除可能覆盖第二版未修改的祖先代码。当前没有为本轮创建提交或合并历史，因此不保证未经审查的合并结果。

在获得提交/合并授权后，按第二版 `docs/releases/version-1-and-2.md` 的恢复清单选择性恢复 Web、Bridge、归因、目录及共享配置/登录入口，并重新跑第二版购买、金币消费、Web/Bridge 与构建验证。不整文件覆盖共享 AppDelegate/工程，不使用全局 ours 策略。

原始工作区快照和已暂存/未暂存补丁保存在 `.git/recovery/2026-09-29-native-v1-split/`（当前 Git common directory 内）。被删文件同时可从第二版查阅。恢复时先解压到新目录比较，不直接覆盖当前工作区。备份仅本地保存、不编入 App、不上传。

## 验证限制

- 云端发布清单契约检查使用当前本地 `.firebase-content/manifest.json` 通过；不等于重新发布云端数据。
- 未执行真实 Apple 支付、真机 ATT 授权、Adjust 后台接收或远程 H5 全量消息联调。
- 构建存在第三方过时 API/工具链路径等警告，不宣称无警告构建。
- 第二版 UI 初次使用未签名模拟器产物失败（Keychain 缺 entitlement）；随后误用 Release 跑 DEBUG 支付夹具，购买按钮禁用。纠正测试签名和构建配置后再评估 UI 结果，不为这些测试环境问题修改生产支付逻辑。
