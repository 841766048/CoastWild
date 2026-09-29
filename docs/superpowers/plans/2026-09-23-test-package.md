# 测试环境对接包名

用户已确认：development 对接包名固定为 test.duckegg.ios；release 使用真实 Bundle ID；签名、安装标识、本地设备身份不变。

## 实施与验证

- [x] 在 IntegrationEnvironmentTests 中先验证不同真实包名下的远程配置匹配；development 匹配测试包名，release 匹配真实包名。
- [x] 执行 `swift test --filter IntegrationEnvironmentTests`，确认新增 development 用例失败。
- [x] IntegrationEnvironment 增加计算属性 `integrationPackageIdentifier: String`，development 返回固定测试包名，release 返回 bundleIdentifier。
- [x] IntegrationRuntimeConfiguration 使用该属性匹配远程字段；AppDelegate 的 RequestContext、归因上报、Web packageName 使用该属性。DeviceIdentityStore 继续使用 bundleIdentifier。
- [x] 执行完整 `swift test`，检查 diff，并构建 iOS 模拟器版本。不改变用户已有签名与图片变更。

验证结果：241 项测试通过；模拟器 Debug 构建成功；git diff --check 通过。更新了 BusinessWebEntryTests 的测试环境远程配置样本以匹配固定包名。本次未安装或重启正在运行的 App，完整真实登录仍需重新运行验证。

本次直接在用户指定的 codex/native-uikit 工作区实施，不自动提交或推送，不引入内购功能。
