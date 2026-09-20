# 出游可选封面验证 · 2026-09-20

## 实现范围

- 创建/编辑出游顶部增加 HF-v1「封面（选填）」卡片。
- 单张系统照片选择，支持添加、更换、移除和取消编辑。
- 自选封面显示于列表首卡、普通列表行和详情；无封面时回退原 `camp` 图片。
- `CoastTrip.coverPhoto` 仅保存账号照片目录内的文件名，兼容旧版 JSON。
- 清理逻辑同时保留手记图片和出游封面；保存替换、移除或删除后清理无引用文件。

## 验证证据

- `swift test`：26 项，0 失败，包含旧数据解码、封面持久化和引用集合测试。最终日志：`/tmp/coast-cover-core-postclean.log`。
- Workspace build：成功。最终日志：`/tmp/coast-cover-build-final.log`。
- 原生 UI 回归：3 项，0 失败，158.5 秒；覆盖默认封面卡片、详情封面、列表回退及原有完整业务流程。日志：`/tmp/coast-cover-ui-final.log`。
- UI 结果包：`build/Logs/Test/Test-CoastWild-2026.09.20_10-23-17-+0800.xcresult`。
- 人工检查创建页和列表截图，封面比例、圆角、角标、按钮、标题层级及列表卡片均符合已确认高保真稿。
