# 原生开发版验证记录 · 2026-09-19

## 环境与结果

- Xcode 26.1.1 / Swift 5 模式 / UIKit / iPhone，Deployment Target iOS 17。
- `swift test`：23 项数据层 XCTest，0 失败（日志 `/tmp/coast-core-final.log`）。
- Xcode 原生 UI 测试：专用 `CoastWild QA` iPhone 16、iOS 18.6，2 项，0 失败；测试过程包含应用编译、签名、安装及运行。
- Test result：`build/Logs/Test/Test-CoastWild-2026.09.19_23-33-36-+0800.xcresult`。
- 最终 UI 命令：

```sh
xcodebuild -project CoastWild.xcodeproj -scheme CoastWild \
  -destination 'platform=iOS Simulator,id=5D9E1931-9B36-479E-8448-2CA6F0F1D802' \
  -derivedDataPath build CODE_SIGN_IDENTITY=- test
```

## 已实测

1. 欢迎页 → 登录；未登录无业务 Tab；错误登录保留表单并显示错误。
2. 注册本地测试账号 → 探索 → 创建出游 → 写手记并保存。
3. 编辑已发布手记 → 保留编辑草稿 → 已发布原文仍保持不变。
4. 退出 → 登录界面，业务 Tab 消失 → 重新登录 → 出游仍存在。
5. 数据层：账号隔离／恢复、失败原子写入、日期与字段限制、重复活动、可选时间、删除关系、草稿重启恢复／发布替换、学习完成时间幂等、旧 JSON 兼容、导出。
6. 资产检查：11 张 PNG 与源 WebP 解码后像素一致；28 个 SVG 保持原路径，仅将 currentColor 固定为主题色供 Xcode 导入。
7. 静态审查：已修复审查发现的 P1/P2，包括原文覆盖、空白草稿残留、孤立附件、筛选显示、行程时区与导出失败清理。

## 运行中发现并处理的问题

- 无签名模拟器构建无法访问 Keychain：改为本地 ad-hoc 签名。
- 个人 iOS 26 模拟器密码自动填充干扰 XCTest：保留实际密码表单，使用干净专用 iOS 18.6 模拟器完成最终测试。iOS 26 曾通过基础主流程，但最新完整回归以 iOS 18.6 记录为准。
- 键盘工具栏改变表单可视区：测试在字段切换前点击“完成”收起键盘。

## 未完成验收的范围

- 所有中英文画面的逐像素对照、Dynamic Type 全字号、VoiceOver 全流程。
- 真机、最低 iOS 17 运行、照片选择／删除权限矩阵和系统分享目的地全量实测。
- 真实账号服务器、邮件、云同步、正式地区内容、上架资料与签名。

## 截图

`docs/screenshots/01-Explore.png`、`02-Trip.png`、`03-Journal.png`、`04-Login.png` 均来自最终通过测试的原生 App；出游与手记是测试创建的数据。
