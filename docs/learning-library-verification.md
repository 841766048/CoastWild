# 学习模块交付验证

验证日期：2026-09-21

## 覆盖范围

- `catalog.json` 共 45 篇双语资料：冲浪、徒步、露营各 15 篇。
- 每个分类含 8 篇 Web 详情和 7 篇 UIKit 原生步骤详情。
- 列表与详情均经 `LearningRepository` 模拟网络请求；生产延迟为 650–1100ms。
- `SkeletonView 1.30.4` 提供列表和详情加载状态，减少动态效果设置下使用静态占位。
- Web 详情支持结构化正文、项目图片、提示卡、清单、引用、来源链接、收藏、分享和继续阅读。
- 原生详情支持步骤图片、SF Symbols 图标、提示卡和学习进度。

## 验证结果

| 检查 | 结果 |
| --- | --- |
| `python3 -m json.tool CoastWild/Resources/catalog.json` | 通过 |
| `swift test` | 59 项通过，0 项失败 |
| 学习模块专项 UI 测试 | 1 项通过，0 项失败 |
| 完整 Workspace UI 测试 | 6 项通过，0 项失败 |
| `xcodebuild build` | `BUILD SUCCEEDED` |
| `git diff --check` | 通过 |

UI 与构建验证设备为 iOS 18.6 模拟器 `CoastWild QA`。本轮没有连接实体 iPhone，因此未覆盖真机网络调试、内存压力和不同屏幕尺寸的人工视觉走查。

## 骨架屏高保真实现

- 学习列表采用主推荐卡与两张紧凑内容卡的内容轮廓。
- Web 详情采用标题、摘要、主题插画、作者与三列重点信息的内容轮廓。
- 原生详情采用步骤标题、主题插画、正文、提示卡与底部按钮的内容轮廓。
- 波浪、山脊与冲浪板线稿由 Core Animation 矢量图层绘制；装饰元素不参与 VoiceOver。
- 返回学习页时复用已加载数据并保留滚动位置，骨架屏不会重复出现。

实现截图：

- `docs/screenshots/hf-v1.3/learning-skeleton-list-implemented.png`
- `docs/screenshots/hf-v1.3/learning-skeleton-web-implemented.png`
- `docs/screenshots/hf-v1.3/learning-skeleton-native-implemented.png`

## 双层学习图片库

- 45 篇资料各有一张独立写实封面，资源名为 `learn-<key>-photo`。
- 45 篇资料各有一张独立 HF-V1 教学插画，资源名为 `learn-<key>-illustration`。
- 冲浪、徒步、露营分别包含 15 张摄影图与 15 张教学图，共 90 张。
- 新增图片约 18 MB，单张最大约 401 KB；旧通用图片继续供其他模块使用。
- `catalog.json` 的 `heroImage`、Web 图片块与原生步骤图片均已更新为逐篇资源。
- 图片库总览：`docs/screenshots/hf-v1.3/learning-image-library-contact-sheet.jpg`。

资源校验结果：45 篇资料、90 个引用、90 个唯一资源、0 个缺失；学习模块专项 UI 测试通过。
