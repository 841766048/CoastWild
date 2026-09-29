import Foundation

struct Catalog: Decodable {
  static let empty = Catalog(items: [], lessons: [], home: nil, learn: nil, categories: [], gearTemplates: [])
  let items: [CoastContent]
  let lessons: [CoastLesson]
  /// 探索首页的编排。旧 catalog.json 没有这一项时首页不展示推荐位。
  let home: CoastHome?
  /// 学习页页头文案。
  let learn: CoastSectionCopy?
  /// 类别名称。旧 catalog.json 没有这一项时回落到 key 本身。
  let categories: [CoastCategory]?
  /// 装备清单模板。旧 catalog.json 没有这一项时解码为空数组。
  let gearTemplates: [CoastGearTemplate]?
  var templates: [CoastGearTemplate] { gearTemplates ?? [] }
}

/// 探索首页推荐位。选哪条内容、配什么图、写什么标题都在 catalog.json 里，
/// 换首页不用改代码。
struct CoastHome: Decodable {
  let heading: [String: String]
  let hero: CoastFeature
  let tiles: [CoastFeature]
}

/// 指向 items 里的一条内容。title / subtitle / photo 省略时用那条内容自己的，
/// 填了就作为首页展示用的覆盖值。
struct CoastFeature: Decodable {
  let item: String
  let title: [String: String]?
  let subtitle: [String: String]?
  let photo: String?
}

struct CoastSectionCopy: Decodable {
  let heading: [String: String]
  let subtitle: [String: String]
}

struct CoastCategory: Decodable {
  let key: String
  /// 筛选与分类按钮上的完整名称，例如 Surfing。
  let name: [String: String]
  /// 卡片副标题里的简称，例如 Surf。
  let label: [String: String]
}

/// 清单模板。原创示例，只描述物品与分组，勾选状态由账本负责。
struct CoastGearTemplate: Decodable {
  let key: String
  let category: String
  let name: [String: String]
  let summary: [String: String]
  let items: [CoastGearTemplateItem]
}
struct CoastGearTemplateItem: Decodable {
  /// 跨语言稳定的物品标识，套用后存进账本的 sourceKey，去重据此进行。
  let key: String
  let title: [String: String]
  let category: String
}
struct CoastContent: Decodable {
  let key: String
  let kind: String
  let category: String
  let title: [String: String]
  let subtitle: [String: String]
  let photo: String
  let minutes: Int
  let level: String
  let distanceKm: Double?
  let region: String
  let page: String
  let body: [String: String]?
  var image: String { URL(fileURLWithPath: photo).deletingPathExtension().lastPathComponent }
}
