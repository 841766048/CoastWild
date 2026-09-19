# 第三方日期选择器 · 2026-09-20

## 实现

通过 CocoaPods 接入 BRPickerView/DatePicker 3.0.0；沿用 Swift + UIKit 和 IQKeyboardManagerSwift。

- 出游起止日期使用滚轮，另一端日期约束可选范围。
- 手记日期必填，确认后继续触发自动草稿保存。
- 活动时刻使用小时/分钟滚轮；已设置日期的出游按实际日期选择活动所属天数。
- 选填项支持清空；取消不改变原值。弹出时收起键盘。
- 中英文标题和按钮、现有主题字体/颜色。标题栏按钮加宽，避免英文 Confirm 截断。
- yyyy-MM-dd / HH:mm 持久化格式不变；Gregorian/UTC 用于日期序列化与天数计算，默认今天按 CN/US 内容地区计算。

## 验证

环境：Xcode 26.1.1，iPhone 16 / iOS 18.6 专用 QA 模拟器，隔离测试账号及数据。

- CocoaPods 安装与 bootstrap 成功；2 个直接依赖、9 个 Pods。
- Core：24 项测试，0 失败，含中美跨日和冬季日期边界。
- 完整 UI 回归：3 项，0 失败，150.1 秒；包含注册登录、日期确认/取消/清空、键盘收起、必填手记日期、活动日期/时间、草稿及退出重登。
- 完整 UI 结果包：`build/Logs/Test/Test-CoastWild-2026.09.20_00-58-23-+0800.xcresult`。
- Core 日志：`/tmp/coast-date-core-final.log`；UI 日志：`/tmp/coast-date-ui-final.log`。
- 独立代码复审的问题已修复，见 `date-picker-review.md`。

中文截图见 `screenshots/date-picker/23-DatePicker.png`、`25-ActivityDatePicker.png`（标题栏加宽前）；英文最终截图与补测记录追加于下方。

保留现有本地账号与数据服务边界；本次不涉及真实服务器或 Figma 稿修改。

## 标题栏修正后补验

- 重新构建并补跑英文 UI 流程：1 项，0 失败（45.1 秒）。
- 结果包：`build/Logs/Test/Test-CoastWild-2026.09.20_01-01-15-+0800.xcresult`。
- 日志：`/tmp/coast-date-header-final.log`。
- 已人工查看 `screenshots/date-picker/24-EnglishDatePicker.png`，Confirm 完整显示，标题与取消按钮无重叠。
