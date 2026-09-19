# CocoaPods 与 HF-v1.2 原生视觉对齐 Implementation Plan

> Use subagent-driven-development for bounded screen work and final review.

**Goal:** CocoaPods 管理第三方库，IQKeyboardManagerSwift 统一键盘行为；按已批准 HF-v1.2 校正 UIKit 字体、颜色、布局。
**Architecture:** 保留 UIKit 控制器和数据闭环；调整共用组件与页面结构。设计来源为 Figma sekErw6W2S4swqxlC0QPIj 及同版 design/figma-import/screens JSON。
**Tech Stack:** Swift 5 / UIKit / iOS 17+ / CocoaPods。

## Global Constraints
- Swift + UIKit，原生可操作，不以截图或 WebView 替代界面。
- 登录后才能使用业务内容，账号空间和持久化保持。
- 美国英文 + 中国大陆简体中文；11 张原图和 28 个原始图标沿用。
- Figma 393×852 为基准，实际设备遵循系统安全区；字号不按屏宽缩放。
- 对照设计的字号、字重、颜色、行高、卡片边框、图片高度、按钮和间距；动态内容保持可滚动。
- 只修改 ios 原生工程；不要更改 H5 或 Figma 稿。

## Tasks
- [x] 1. Podfile/lock/workspace + AppDelegate 注册 IQKeyboardManagerSwift；移除手写键盘避让和工具栏冲突。验证 pod install + workspace build。
- [x] 2. Components.swift 共用设计令牌：32/750 标题，16/600 按钮高50，14 表单高48，14标签，20边距；原生自定义导航与 tabs 保持 Figma 几何。
- [x] 3. ExploreController.swift、LearnController.swift 逐项核对 EX01–05、LE01–03，保留搜索、收藏、选出游和学习进度。
- [x] 4. AuthController.swift 按 ON01、AU01–04 改层级、排版、兴趣卡、登录表单；保留所有验证和真实本地行为。
- [x] 5. TripsController.swift、JournalController.swift、ProfileController.swift 对照 TR/JO/ME/SE/AU05，保留数据操作和自动草稿。
- [x] 6. 核验：23 core tests，原有 UI 流程回归，新增键盘切换/遮挡测试，双语页面截图，与同版设计核对，记录不足。

## Task 3 brief
Read ../design/figma-import/screens/en-*.json and zh-*.json selectively, especially EX01–05 and LE01–03. Modify ONLY CoastWild/UI/ExploreController.swift and LearnController.swift. Keep data operations. Match layout and content order (not generic redesign): EX01 title32/750 top then region44, search46, image244, title23bold, subtitle14, section21bold, tiles155 with bottom left14bold. LE01 title32 then section23, subtitle14, category pills40, group21, whole lesson card with image180 first/110 next and title24. Detail photos238, lesson320. Use exact fonts/colors/lineheight from JSON. Shared APIs will retain signatures; root adds sectionTitle, card and link helpers only if communicated. No edits to Components/AppDelegate/project files. Can define local private helpers. Header root navigation will be hidden by parent navigation subclass for four tab roots; use own horizontal heading32 + icon action in root render. Secondary controllers keep system nav for now. Root will centralize 32 headings, row card88×90, 14 fields48 and buttons16/50. Need no build while root installing pods; run Swift parser checks and report. Commit ONLY your two files and write docs/figma-content-report.md with affected IDs and known gaps; return concise status.

## Completion evidence

2026-09-20：bootstrap成功；23 core tests、3 UI tests均通过；23张稳定原生截图已导出；最终源码复审问题全部关闭。实际核验范围与未覆盖的全量逐像素差分见 `docs/verification-2026-09-20.md`。
