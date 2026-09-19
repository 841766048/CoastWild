# CocoaPods / HF-v1.2 优化验证 · 2026-09-20

## 交付内容

- CocoaPods 1.16.2：Gemfile/lock、Podfile/lock、xcworkspace 与可重复运行的 bootstrap 脚本。
- IQKeyboardManagerSwift 8.0.3：统一输入避让、上一项/下一项/完成、空白区域收起；移除重复手写键盘工具栏与避让。
- Swift + UIKit：认证、探索、学习、出游、手记、个人与设置页面按同版 Figma 数据校正字体、行高、字距、颜色、图片高度、表单、卡片与布局。
- 保留原始11张图片和28个图标；未更改 H5/Figma 稿。
- 保留登录前置、账号隔离、行程操作、关联体验、编辑草稿、学习进度和本地持久化。

## 设计核对方式

Figma 文件：`sekErw6W2S4swqxlC0QPIj`（HF-v1.2）。通过电脑 App 查看，并使用 `../design/figma-import/screens` 的同版中英文导入数据核对尺寸/字体/颜色。Figma MCP 当前席位额度不足，未把调用失败当作视觉证据。

中文使用 PingFang SC；英文使用 SF Pro。CSS 750 按原 Sketch 导入映射为英文 Bold、中文 Semibold。字号不随屏宽缩放；正常字体下以393×852设计为基准，实际设备保留系统安全区。

## 已验证

- `bundle install`、`bundle exec pod install`：成功，1个直接依赖、8个Pods。
- `./scripts/bootstrap.sh`：bundle检查、XcodeGen重生成、Pods重新集成成功。日志 `/tmp/coast-bootstrap-verified.log`。
- `swift test`：23项，0失败。日志 `/tmp/coast-core-verified.log`。
- 最终源码复审：原5项与追加选中态问题均关闭。见 `figma-final-review.md`。

## 原生 UI 回归

工作区编译、签名、安装和原生 UI 测试成功：3项，0失败。截图等待导航稳定后复跑仍为3项、0失败，耗时118.9秒。

- 最终日志：`/tmp/coast-ui-screenshots-final.log`
- 结果包：`build/Logs/Test/Test-CoastWild-2026.09.20_00-38-00-+0800.xcresult`
- 环境：Xcode26.1.1、专用CoastWild QA、iPhone16、iOS18.6。

```sh
xcodebuild -workspace CoastWild.xcworkspace -scheme CoastWild \
  -destination 'platform=iOS Simulator,id=5D9E1931-9B36-479E-8448-2CA6F0F1D802' \
  -derivedDataPath build CODE_SIGN_IDENTITY=- test
```

覆盖：登录前置与错误提示；注册；IQ键盘下一项/单一工具栏/输入框不被遮挡/完成收起；中英文切换；探索/搜索/学习；个人与设置；找回密码目标邮箱；创建出游/添加体验；手记关联体验/保存/编辑草稿；退出、重新登录与数据保留。

测试使用独立 `CoastWildTests` 数据目录和测试Keychain service。专用QA模拟器中的系统密码自动填充已关闭，以避免系统强密码覆盖层干扰XCTest输入；正式App密码输入行为未为测试修改。

## 视觉证据与边界

原生截图导出至 `screenshots/figma-alignment`，共23张，见该目录的 README 索引。测试创建的名称、日期、数量属于动态数据，因此与Figma示例文本不同。

本轮完成主要页面的源码数值核对和代表性中英文截图检查。全量中英文画面的逐像素差分验收、所有Dynamic Type字号、VoiceOver全流程、iOS17及真机矩阵尚未完成；不以编译成功代替这些结论。系统状态栏、导航过渡、照片选择器依照系统行为。
