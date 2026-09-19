# 原生页面覆盖（开发版）

| 设计 ID | UIKit 实现 | 当前行为 |
|---|---|---|
| ON01 | WelcomeController | 欢迎、偏好、兴趣、登录与注册入口 |
| AU01–04 | AuthController | 邮箱密码、本地演示恢复、校验；登录前置 |
| AU05 | AccountController | 账号信息、退出 |
| EX01 | ExploreController | 原摄影、地区、搜索、双列推荐 |
| EX02 / ST04 / ST11 | SearchController | 搜索、空结果、类别和时长筛选；筛选使用原生选项菜单 |
| EX03–05 | ContentController | 专题／目的地／体验共用原生详情，收藏与加入出游 |
| LE01–03 | LearnController / LessonController | 专题、步骤、进度与完成 |
| TR01 / ST05 / ST15 | TripsController | 待出发／已完成与空态 |
| TR02 / ST06 | TripEditorController | 名称、日期、备注校验与未保存退出确认 |
| TR03 | TripDetailController | 按天列表、排序、移除、改天、完成、删除 |
| TR04 / ST12 | ActivityPickerController | 选择体验／日期／时间，重复添加提示 |
| JO01 / ST08 | JournalController | 正文与草稿列表、空态 |
| JO02 / ST07 / ST09 / ST13 | JournalEditorController | 原生照片选择、草稿、导入失败、退出确认、保存失败 |
| JO03 / ST14 | JournalDetailController | 详情、编辑、系统分享、删除 |
| SA01 / ST10 | BookmarksController | 收藏及空态 |
| ME01 | ProfileController | 账号、收藏、学习统计与设置 |
| SE01 | PreferencesController | 语言、地区、单位；与引导复用 |
| SE02 / ST01 / ST16 | PrivacyController | 数据导出、清除确认与失败反馈 |
| ST02 / ST03 | 本地资源加载边界 | 当前内容打包在 App 中，没有远程加载请求；未伪造网络加载和重试成功 |

## 与静态稿的适配

- 画稿中的状态栏、灵动岛与底部 Home 指示条由 iOS 绘制，不作为图片复刻。
- 导航、筛选选项菜单、照片选择器、分享和确认弹窗使用 UIKit 系统组件；未复刻 H5 的浏览器外壳。
- 内容可随动态字体和键盘纵向滚动；实际可视区域不同于固定 393×852 画板。
- 业务页实现并不等于所有状态已在真机验证；验证证据单列在 verification.md。
