# Codemagic 第二版上传流程

本分支使用 `v2-ipa`，仅允许手动选择 `codex/native-coin-learning` 运行，不自动触发。第一版 main/native-uikit 仍使用各自已有配置；不能以覆盖业务代码的方式同步分支。

- 上传授权：`CoastWild-NewAccount`，私钥只保存在 Codemagic。
- Bundle ID：`com.huankecontact.coastwild`；Team ID：`T4VGJVH22P`。
- 签名：App Store，复用云端已配置的匹配证书和描述文件。
- 构建后上传 App Store Connect；不自动提交 Beta 审核、App Store 审核或发布。
- 保留当前测试后端、内购、Web/JS、ATT/Adjust 等第二版功能，本次不改业务代码。
- 按第二版 Podfile.lock 安装依赖，不引入第一版 Firebase SPM 或内容工具测试，也不重新生成工程。
- 运行 CI 配置测试、发布校验器契约测试、Swift 核心测试后归档。
- 构建号使用应用级 `1000 + PROJECT_BUILD_NUMBER`，与第一版共用计数，范围 1000–9999。

App Store Connect 需已有该 Bundle ID 对应应用，API Key 需有 App Manager 权限。上传不等于正式上线准备完成，测试环境与第二版功能需单独验收。

本次仅同步配置，不启动云端构建或上传。第二版云端签名归档及实际上传结果仍需首次运行验证。
