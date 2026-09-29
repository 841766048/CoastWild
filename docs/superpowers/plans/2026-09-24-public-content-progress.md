# 公共内容迁移验收记录

当前分支 codex/native-uikit，工作区保留，不提交/推送。用户照片只在本地；无 Storage、Functions 或计费开通。

## 契约

- Firestore (default)，STANDARD、us-east1、freeTier=true。
- publicCatalog/current 为管理员发布的单个版本快照，含 schemaVersion、version、catalogJSON、images；课程正文、类别与编排均在 catalogJSON 中。
- 认证客户端仅能 get 当前版本，不能 list、写入或访问草稿；私有笔记路径权限不变。
- 公共图片 Hosting 独立白名单构建目录，旧版本路径保留，用户数据和笔记图片不参与打包。
- 客户端全包下载后检查文件长度和 SHA256，成功才原子切换缓存；请求失败保留旧缓存，缓存损坏使用内置资源。前台进入时节流检查更新，不阻塞登录。

## 验证记录

- 核心回归首次 249 项通过；新增发布包契约验证后，PublicContentTests 4 项全部通过。
- Firestore 规则模拟器 3 组通过，包括跨用户笔记拒绝和公共内容未登录/列举/写入拒绝。
- 规则 CLI 发布成功后 MCP 回读已确认远端正确版本。
- iOS 编译 BUILD SUCCEEDED。
- 初次未签名 UI 测试在钥匙串访问处失败；改为仅命令行模拟器 ad-hoc 签名后，testLearningLibraryLoadsWebAndNativeDetails 通过，覆盖列表、H5/原生详情、图片分享和返回状态。工程签名配置没有因此改写。
- 初次代码审查发现图片流读取与缓存写入继承 MainActor，已改为 PublicContentWorker actor；主线程仅应用状态和发送刷新通知。回归验证后台线程以及中途失败保留旧缓存。
- 复审发现发布工具可验证不同环境地址，已固定正式 Hosting origin、拒绝重定向，增加 30 秒超时；发布工具 15 项测试通过。
- 复审发现测试模式注销失败会绕过私有同步开关，已对两个 resume 调用加测试模式保护。相同 signed UI 测试修复前崩溃失败，修复后 1 项通过。

## 发布结果

- 已发布 6 条探索内容、45 篇课程、3 个分类、3 个清单模板及 96 张公共图片。
- Firestore publicCatalog/current 已写入版本 `c47018c040b9c3eafe94a86946d032c2abdf7177baed16b3b40084416d76d4d7`，压缩 catalogJSON 为 147,542 字节，图片共 19,894,469 字节。
- Hosting 发布完成，96 张正式 URL 全部直接 HTTP 200、文件长度和 SHA256 一致，无重定向。
- 真实匿名身份读取的文档与本地发布清单完全一致；未登录读取、集合列举、客户端写入均被拒绝。测试匿名身份已清理；日志中的 PERMISSION_DENIED 是预期拒绝用例。
- 模拟器使用 `--ui-testing --ui-testing-public-content --reset-test-data --accept-privacy --seed-account` 隔离业务测试数据，实际访问 Firebase。其 PublicContent/current.json 已激活上述版本，96 个缓存文件逐一通过长度/hash核验，截图检查首页正常。此模式不允许私有笔记同步。
- 最终 Swift 核心测试 251 项、发布工具 15 项、Firestore 规则 3 组通过；学习 H5/原生/分享 UI 与注销失败 UI 各 1 项通过；带模拟器签名构建通过。
- 最终只读审查通过，无剩余 Important/Critical 问题。既有 Components CGFloat 可选值和 Xcode 工具链警告仍存在，不宣称零警告构建。
- Firebase 环境回读 Billing Enabled: No。未启用 Storage、Functions、内购，未修改业务接口约定。

## 边界与后续

真机弱网/飞行模式、长期离线及私有笔记注销中断仍需上线前验收。当前失败注入覆盖缓存回退，不冒充真机弱网测试。公共内容整包约 20MB，首次下载后台执行；免费配额并非无限。用户笔记照片不会上传，重装/换机不保证恢复。

工程当前保持本地未提交状态。发布步骤见 `tools/firebase-content/README.md`，再次更新课程需运行构建、审核白名单、部署 Hosting、校验并发布文档。
