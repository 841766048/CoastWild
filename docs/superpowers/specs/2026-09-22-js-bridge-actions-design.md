# JS Bridge 全量业务处理设计

## 目标

补齐业务 H5 已注册但尚未执行的原生消息，使 JavaScript 调用能够完成后台登录、导航、系统能力、WebView 状态控制和应用状态同步，同时保留现有来源校验、主 frame 限制与敏感信息保护。

## 范围

本次处理 `BackgroundLogin`、`DidMoveToMainPage`、`OpenAppBrowser`、`OpenLink`、`OpenAppSettings`、`OpenAppStoreReview`、`EnableEdgePan`、`UpdateCoins`、`UpdateLanguage`、`NativeLog`、`openVipService` 和 `recharge`。

既有 `OpenAppPurchase`、`LogPurchase`、`GetProductPrice`、`OpenInternalWeb`、`newTppClose` 和 `Logout` 行为保持不变。`onCreateOrder` 继续按对接契约注册但拒绝执行，不新增另一套建单入口。

本次不修改 IAP 收据格式、Facebook SDK、Associated Domains 或正式环境参数。

## 架构

新增 Foundation 可测试的 `BusinessBridgeAction` 与路由决策层，将 `BridgeMessage` 转换为明确的原生动作。`BusinessWebController` 负责执行只依赖 UIKit/WebKit 的动作，包括 WebView 揭幕、应用内 Safari、外链、设置、评分和边缘手势。`AppDelegate` 通过闭包处理应用级动作，包括后台登录、退出、语言同步和权益刷新。

该边界避免在 `AppDelegate` 中继续添加 topic 判断，并允许单元测试覆盖每个消息是否被映射到正确动作。

## 消息行为

- `BackgroundLogin`：调用现有 `RemoteSessionCoordinator.backgroundLogin`。成功后保留当前 WebView，刷新运行时配置，并调用 `backgroundLoginSuccess(...)`；失败不替换当前页面，由原生展示可恢复错误。
- `DidMoveToMainPage`：标记 H5 已准备好，完成进度并移除启动遮罩。重复调用幂等。
- `OpenAppBrowser`：通过 `SFSafariViewController` 打开已验证的 HTTPS URL。
- `OpenLink`：仅在系统声明可打开时交给 `UIApplication.open`。URL 仍先经过现有 payload 校验与导航策略。
- `OpenAppSettings`：打开 `UIApplication.openSettingsURLString`。
- `OpenAppStoreReview`：优先在当前 `UIWindowScene` 使用 `SKStoreReviewController.requestReview`；没有可用 scene 时不执行，不拼接不受控地址。
- `EnableEdgePan`：控制附着在主 WebView 上的 `UIScreenEdgePanGestureRecognizer`，支持左右边缘；触发时调用 WebView 的 `goBack()`，无历史记录时不动作。
- `UpdateCoins`：请求服务端策略/权益刷新；不在本地伪造余额。
- `UpdateLanguage`：只接受现有解析器验证后的非空语言值，映射为 `en` 或 `zh-Hans` 并持久化；随后让现有根界面刷新。
- `NativeLog`：仅输出固定事件名、消息字符数和截断后的无控制字符摘要；禁止输出 token、完整 URL 查询、收据、JWS、订单号和用户对象。
- `openVipService`、`recharge`：按示例契约调用同名 JavaScript 回调，不引入新的原生页面。

## 安全与错误处理

`BridgeRouter` 现有的 HTTPS host、主 frame 和 payload 类型校验继续作为唯一入口。应用内 Safari 与外部链接不会绕过该校验。JS 执行失败、无法打开 URL、无评分 scene、无后退历史均安全忽略，不崩溃。

后台登录期间复用协调器的并发保护。成功回调必须使用现有 `JavaScriptCallbackEncoder`，不得拼接未经编码的 JSON。日志不得包含认证、支付或设备标识原值。

## 测试

- 单元测试覆盖每个 Bridge topic 到动作的映射以及 `onCreateOrder` 保持不支持。
- 单元测试覆盖语言归一化、NativeLog 脱敏、重复揭幕幂等与边缘手势状态。
- 协调器测试覆盖后台登录成功、失败和并发保护。
- WebView/UI 层通过可注入闭包验证 Safari、外链、设置、评分和 JS 回调分发。
- 最终运行 `swift test` 和 `xcodebuild -workspace CoastWild.xcworkspace -scheme CoastWild -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build`。

## 验收标准

业务 H5 发出的上述 topic 均有明确可观察结果或明确的安全无操作结果；未知、非主 frame、非可信来源和非法 payload 继续被拒绝；现有 IAP、登录、内部 WebView 和退出流程无回归。
