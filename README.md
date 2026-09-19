# Coast & Wild / 海岸与山野 — UIKit

原生 iPhone 开发版本，Swift + UIKit，最低 iOS 17。按已确认的 HF-v1.2 页面与交互契约开发。使用 CocoaPods 管理第三方库，键盘管理采用 IQKeyboardManagerSwift。无 SwiftUI、Flutter 或 WebView。

## 打开与运行

打开 `CoastWild.xcworkspace`，选择 `CoastWild` Scheme 和 iPhone 模拟器，运行。

```sh
./scripts/bootstrap.sh
xcodebuild -workspace CoastWild.xcworkspace -scheme CoastWild \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build CODE_SIGN_IDENTITY=- build
swift test
```

模拟器请保留本地签名（`CODE_SIGN_IDENTITY=-`）；关闭签名会使 Keychain 不可用。真机需在 Signing & Capabilities 选择自己的开发团队；工程未填入团队或签名凭据。

## 使用

首次启动选择语言、内容地区与兴趣，然后注册一个本地测试账号（邮箱＋至少 10 字符的密码）。登录后才能进入探索、学习、出游、手记；退出保留账号数据。不要使用正式账号的密码。

找回密码显示本地演示验证码，10 分钟有效、最多 5 次尝试；不会发送真实邮件。本地身份验证只服务本机演示，不是远程账号系统。

## 功能

- 探索、搜索、类别／时长筛选、专题／目的地／体验详情、收藏。
- 冲浪／徒步／露营学习，步骤进度、首次完成时间、回顾。
- 出游创建／编辑／删除、日期校验、活动添加／移除／上下移动／改天、可选时间、完成／重新打开。
- 手记正文、日期、关联出游／体验，系统照片选择器（最多 12 张），500ms 草稿保存、保存失败保留输入。
- 已发布手记的编辑草稿独立持久化；正式保存才原子替换原文。
- 系统分享、当前账号 JSON＋照片导出、本地内容清除、独立的语言／地区／距离／温度偏好。
- 原始 11 张照片/插画和 28 个 SVG 图标，系统动态字体、滚动表单、键盘工具栏、减少动态效果。

## 结构

- `CoastWild/App`：应用启动、登录前置、Keychain 本地账号、内容解码。
- `CoastWild/Core`：Codable 模型、校验、按账号隔离的原子文件存储。
- `CoastWild/UI`：UIKit 控制器、共用组件、系统照片与分享接口。
- `CoastWild/Resources`：双语原创示例内容、原始图片/矢量图标、应用名称本地化。
- `Tests`：Foundation 数据层 XCTest。
- `UITests`：原生账号、出游、手记、退出与数据保留流程。
- `docs`：实施计划、审查记录、截图与验收说明。

## 设计来源与边界

Figma： https://www.figma.com/design/sekErw6W2S4swqxlC0QPIj

开发时通过 Figma 电脑 App 查看设计，并用同版导入 JSON 核对字号、字重、行高、字距、颜色、间距、图片和原始图标。布局采用 Auto Layout；状态栏、安全区和系统照片选择器随设备及 iOS 变化。主要页面的原生截图与测试记录见 `docs/verification-2026-09-20.md`；全量中英文画面尚未完成逐像素差分验收。

当前无远程服务器、真实邮件、云同步、付费、实时海况或精确导航。美中地区的内置内容仍为同一套原创示例；用户填写的数据不会随切换语言重建。正式发布还需内容核验、真实服务接入、真机及无障碍全量验收。

图片来自本项目原设计资产；原 WebP 无损转换为 PNG，图标直接复用 SVG 路径。AppIcon 暂用原海岸图片裁切，是开发版图标。


## 第三方库（2026-09-20）

- CocoaPods 1.16.2（Gemfile/Gemfile.lock 固定工具版本）。
- IQKeyboardManagerSwift 8.0.3 及其子依赖由 Podfile.lock 固定。
- BRPickerView/DatePicker 3.0.0：出游起止日期、手记日期、活动日期和时刻使用统一的中英文滚轮选择器；支持取消、确认、可选项清空及起止范围约束。
- 首次运行：`bundle install && bundle exec pod install`，随后打开 `CoastWild.xcworkspace`。
- 如需根据 project.yml 重生成工程，运行 `./scripts/bootstrap.sh`，它会在 XcodeGen 后重新集成 Pods。
- UIKit 表单统一由 IQKeyboardManager 管理避让、上一项/下一项/完成和点击空白收起；不再叠加 keyboardLayoutGuide 或手写 inputAccessoryView。
- 业务 Core 的 Package.swift 仅用于独立单元测试，不承担第三方依赖管理。
