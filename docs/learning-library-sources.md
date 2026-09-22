# 学习资料来源说明

## 内容规模

`catalog.json` 包含 45 篇双语学习资料：冲浪、徒步、露营各 15 篇；每类 8 篇 Web 长文与 7 篇原生步骤课。完整标题与类型直接以 JSON 为准，并由 `testCatalogContainsCompleteLearningLibrary` 自动校验数量、唯一 ID、双语字段、图片、详情载荷与下一篇引用。

## 主要核对来源

- 冲浪与海滩安全：NOAA Ocean Service、National Weather Service 的海况、离岸流与海滩安全资料。
- 徒步安全：U.S. National Park Service 的路线规划、天气、迷路处置与步道安全资料。
- 露营安全：U.S. National Park Service 的行前规划、营地安全与紧急准备资料。
- 户外伦理：Leave No Trace Center for Outdoor Ethics 的七项原则。

JSON 的每篇文章都保存 `sourceLinks`，包含来源机构、双语标题和 HTTPS 地址。正文为项目原创整理，不复制来源段落；资料只作为入门教育，不能替代当地实时公告、现场专业指导或紧急服务。

## 图片与图标

文章使用项目 Asset Catalog 内的自有或已生成图片：`surf-lesson`、`surf-coast`、`coast-wide`、`board-diagram`、`shoreline`、`coast-hiker`、`hills`、`camp`。图标字段使用 SF Symbols 名称，不抓取第三方图标文件。

