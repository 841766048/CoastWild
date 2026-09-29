# 公共课程迁移执行任务

继续已获同意的 2026-09-23-firebase-content 计划，保持 codex/native-uikit 原工作区，不提交、不推送、不改签名，不引入内购或计费服务。用户照片仅本地。

## 发布任务（独立子任务）

实现 tools/firebase-content/ 下的 Node 发布打包、测试和说明文件，可修改 firebase.json Hosting 配置和 .gitignore。不要改 Swift、firestore.rules 或已有规则测试。先测试后实现。

输入仅 CoastWild/Resources/catalog.json 及它引用的公共图片，从 CoastWild/Resources/Assets.xcassets/<assetName>.imageset/Contents.json 查找实际图片；必要时检查 ../h5-preview/public/assets 对应图片。不得扫描复制整个工程目录。严格校验相对图片名，拒绝 traversal、symlink 越界、token/用户数据/任意新增顶层字段；验证关联 ID、重复 ID、HTTPS 来源链接。保留原 catalog 的全部课程与类别字段。

Firestore 公共发布文档为 publicCatalog/current，字段：schemaVersion:1、version:64位SHA256发布内容摘要、catalogJSON:压缩JSON字符串（小于700000字节）、images:数组，元素 {name,path,sha256,bytes}。name 是去掉扩展名的图片文件名（App 的 image/assetName 访问）；path 固定为 content/<version>/images/<name>.<ext>；sha256 为图片摘要，bytes 为图片字节数。每图最大8MiB，总计最大60MiB，最多128张，name 必须唯一。version 覆盖 catalog 和图片摘要，确定性构建。

输出仅 .firebase-public/content/<version>/images/ 及内部不可公开部署的发布文档工具产物（放 .firebase-content/manifest.json）。Hosting public=.firebase-public，指定 site=coast-wild-20260915，版本路径一年 immutable 缓存，无 SPA rewrite。不替换/删除先前 release 目录，保证旧客户端短暂仍可用。使用 .gitignore 忽略生成目录。不要自行上线；主代理将审核后部署。发布脚本需验证每个远端图片200及sha256再提交current文档，提交管理端认证使用环境 GOOGLE_OAUTH_ACCESS_TOKEN 或 ADC，不将凭据写文件或日志。探查现有 CLI 认证可复用方式但不读取/输出凭据，无法确定则报告。

验收：构建当前全部公开资源、测试路径注入/非法链接/重复id/缺失资源被拒绝；可重复构建同版本；提供可执行发布命令及资源统计。报告写 tools/firebase-content/REPORT.md，包含RED/GREEN证据。

## 客户端与验收（主代理）

1. 新增 Core 公共发布结构/缓存：严格验证版本和图片manifest，坏数据不替换；全包下载校验后原子激活，旧缓存/内置兜底。测试离线、损坏缓存、版本路径注入与hash不符。
2. Catalog 从缓存解码，Firebase 文档按匿名身份读取（隐私同意后），后台下载图片；完整验证后更新 catalog/learning 和界面通知，图片本地缓存优先、内置兜底。无个人图片上传。
3. 规则仅允许认证客户端读取 publicCatalog/current，禁止所有客户端写入/列举；原私有笔记规则不变。模拟器验证拒绝写入/跨用户读取。
4. 审核部署公开图片后，管理员写 current，实测远端读取与图片hash，Swift测试+模拟器编译+可行的UI回归；记录尚未完成的验收，不夸大结果。
