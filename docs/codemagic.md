# Codemagic：第一版构建与手动 IPA

仓库根目录就是 iOS 工程目录，不要在工作流中再次 `cd ios`。`main` 与 `codex/native-uikit` 使用同一份 `codemagic.yaml`；第二版分支不在这次配置范围内。

## 两条工作流

| ID | 分支 | 触发 | 产物 |
|---|---|---|---|
| `dev-checks` | `codex/native-uikit` | Git push，或手动启动 | 测试日志、未签名模拟器 App |
| `main-ipa` | `main` | 仅手动启动 | App Store 签名 IPA、dSYM、构建日志 |

**当前 IPA 明确连接测试后端，不代表正式上线准备完成。** 当前配置保持 `development`、`https://test-app.bigegg.work`、Bundle ID `com.huankecontact.test`。不自动上传 TestFlight、不提交审核、不发布 App Store。

`main-ipa` 使用 App Store 类型签名，该 IPA 不能像 Ad Hoc 包一样直接安装到普通设备。当前阶段先验证归档和导出；后续若需要直接安装测试，需明确选择 Ad Hoc 并配置测试设备，不能只改文件后缀。

## 你已经添加仓库，还需配置签名

在 Codemagic **Team settings → codemagic.yaml settings → Code signing identities**：

1. **iOS certificates**：添加有效的 Apple Distribution 证书（`.p12`，包含私钥），填写导出密码。
2. **iOS provisioning profiles**：添加在 Apple Developer 中手动创建的 **App Store** 类型 `.mobileprovision` 文件。本流程不使用 Xcode-managed 自动管理的描述文件。
3. 两者必须匹配，并属于团队 **`8S59A5XCJ9`**、Bundle ID **`com.huankecontact.test`**。
4. 确认 Codemagic 显示该描述文件具有匹配的证书。工作流按 Bundle ID 和 `app_store` 类型自动选择，不需要在 YAML 填证书文件名。

也可以先在 Codemagic 配置 Apple Developer Portal / App Store Connect API 集成，再使用平台的获取/生成入口；选择获取手动创建的 App Store 描述文件，不选 Xcode-managed 文件。这里的自动匹配签名资源不等同于 Xcode 自动签名。已有外部证书仍需要对应私钥，不能只上传 `.cer`。本次没有创建、吊销或替换 Apple 证书，也没有写入任何 `.p8`、密码、API token。

**请勿上传本机的 `huankeProfileDev` 开发描述文件来代替 App Store 描述文件。** 本地工程仍保留原签名；只有 Codemagic 临时 checkout 会由 `xcode-project use-profiles` 应用云端签名，随后校验实际 iphoneos 签名设置。

仅导出 IPA 不要求配置自动发布的 API Key 或数字 Apple ID。未来需要上传 TestFlight 时，再核实 App Store Connect 的应用记录、数字 Apple ID 和 API 权限；不要直接使用业务配置中的示例数字 ID。

## 首次运行

1. Codemagic 打开 CoastWild，确认读取仓库根目录的 `codemagic.yaml`。
2. 选择分支 `codex/native-uikit` 和 `dev-checks`，先运行无签名验证。自动 push 触发还要求 GitHub webhook / 仓库集成正常。
3. 签名配置完成后，选择分支 `main` 和 `main-ipa`，手动 Start new build。
4. 成功后从 Artifacts 下载 IPA、dSYM 和日志。此次配置没有发布步骤。

若平台提示缺少匹配签名，是账户端证书/描述文件尚未配置完整；修改代码不会生成缺失私钥。

## 依赖和版本

- Xcode **26.1.1**，CocoaPods **1.16.2**，Node **22**；CI 不运行 XcodeGen，直接使用已提交工程，避免覆盖签名和依赖设置。
- `pod install --deployment` 保持 Podfile.lock；Swift Package 按已提交 Package.resolved 解析，锁文件意外变动则失败，不执行依赖升级。
- 缓存依赖下载，不缓存签名、私钥或完整构建产物。
- Build Number 为 `1000 + PROJECT_BUILD_NUMBER`（Codemagic 应用级计数，不是每个工作流单独计数）。配置范围为 1000–9999；超过范围主动失败，需重新审查版本编号。
- 正式上传前确认该编号大于已有相同版本的构建号；本流程没有查询 App Store Connect。
- 测试用公共目录从 `Tests/Fixtures/public-catalog.json` 生成到 `build/codemagic/`，供契约测试使用；不会打入 App、不会部署 Firebase，也不会覆盖本机 `.firebase-content`。

## 校验和限制

`scripts/ci/ci_support.py`：分支/触发方式、测试环境、Bundle ID、Firebase 配置一致性、构建号、云端导出及实际签名检查。

`scripts/ci/run.sh`：依赖、测试、模拟器构建、签名归档。测试失败会阻止后续步骤。开发流程不加载签名或发布凭据，不接受 PR 构建。

`scripts/validate_release_config.sh` 已修正为第一版正式环境字段及运行时 `release` 模式，不再要求 Web/Adjust。它当前用于校验器测试，不会把现有测试后端伪装成正式环境。未来正式工作流需要经过确认的实际配置，并显式调用该校验器；当前 App 运行时正式环境策略拒绝 `.test` Bundle ID，切换前还需核实 Firebase 配置。

本地验证不等于 Codemagic 全新机器、Apple 签名或云端首次打包成功；首次云端运行仍需查看实际构建日志。没有平台签名时不能宣称已生成可分发 IPA。

2026-09-29 本地验证：Codemagic 官方 JSON Schema 校验通过；12 项 CI 配置/前置检查测试、发布配置 shell 测试、186 项 Swift 核心测试和 15 项内容工具测试通过；现有依赖下模拟器 Debug 构建通过。未执行云端首次依赖安装或签名导出。

## 官方资料

- [原生 iOS 工作流](https://docs.codemagic.io/yaml-quick-start/building-a-native-ios-app/)
- [证书和描述文件配置](https://docs.codemagic.io/yaml-code-signing/signing-ios/)
- [Xcode 26.1 环境](https://docs.codemagic.io/specs-macos/xcode-26-1/)
- [构建号与内置变量](https://docs.codemagic.io/yaml-basic-configuration/environment-variables/)
- [YAML 官方格式校验](https://docs.codemagic.io/partials/yaml-validate/)
