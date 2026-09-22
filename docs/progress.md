# 原生开发进度

- 2026-09-19：已建立独立 ios/ Git 仓库，分支 codex/native-uikit。
- 使用 Figma 电脑 App 查看关键业务画面，11 图片及 28 SVG 原始资源核对通过。
- 数据层和 UIKit 业务页面已实现，23 数据测试通过。
- 静态审查中发现的 P1/P2 已修复，详见 native-app-review.md。
- 专用 iOS 18.6 模拟器 2 项 UI 测试全部通过，详见 verification.md。
- 2026-09-20：按 HF-v1.3 设计稿实现装备清单、提醒、足迹、手记标签与日历。
- Core 新增 CoastGearItem / CoastReminderPlan / CoastTrailStats，新字段全部用可选类型保证旧账本可解码。
- UI 新增 GearController / GearTemplateController / GearItemEditorController / RemindersController / TrailController / JournalCalendarController。
- 新增通知系统权限（UNUserNotificationCenter），为本项目第一个新增权限。
- swift test 50 项通过；新功能原生 UI 测试通过，截图见 screenshots/hf-v1.3。
- 既有两项注册相关 UI 测试在本次改动前即失败，属 iOS 18 模拟器密码自动填充环境问题，详见 ../../docs/新增功能验收记录-v1.3.md。
