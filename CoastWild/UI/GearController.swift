import UIKit

/// TR05 装备清单。按出游隔离，分组勾选，顶部显示进度。
final class GearController: CoastController {
  private let tripID: String

  init(_ env: CoastEnvironment, tripID: String) {
    self.tripID = tripID
    super.init(env)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) unsupported") }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    render()
  }

  private var trip: CoastTrip? { env.store.ledger.trips.first { $0.id == tripID } }

  func render() {
    reset()
    guard let trip else {
      navigationController?.popViewController(animated: true)
      return
    }
    title = env.t("Packing list", "装备清单")
    let optionsItem = iconItem("more", label: env.t("Checklist options", "清单选项")) {
      [weak self] in self?.options()
    }
    optionsItem.accessibilityIdentifier = "gear.options"
    let addItemButton = iconItem("plus", label: env.t("Add an item", "添加物品")) { [weak self] in
      self?.addItem()
    }
    addItemButton.accessibilityIdentifier = "gear.add"
    navigationItem.rightBarButtonItems = [optionsItem, addItemButton]
    contentTop.constant = 16
    stack.spacing = 14

    add(tripSummaryRow(trip))

    let groups = trip.gearByCategory
    if groups.isEmpty {
      empty(
        env.t("Nothing packed yet", "还没有装备清单"),
        env.t(
          "Start from a template, or add your own items one at a time.",
          "可以从模板开始，也可以逐项自己添加。"),
        icon: "check", actionTitle: env.t("Use a template", "套用模板")
      ) { [weak self] in self?.chooseTemplate() }
      add(coastButton(env.t("Add an item", "添加物品"), secondary: true) { [weak self] in
        self?.addItem()
      })
      return
    }

    add(progressBlock(trip))
    for group in groups {
      add(sectionLabel(env.gearGroupName(group.category)))
      add(gearCard(group.items, trip: trip))
    }
    add(
      coastNotice(
        env.t(
          "Ticks stay on this device with the trip. Templates only add what is missing.",
          "勾选状态随出游保存在本机。套用模板只会补充缺少的物品。")))
  }

  // MARK: 视图片段

  private func tripSummaryRow(_ trip: CoastTrip) -> UIView {
    let dates =
      trip.start.isEmpty ? env.t("No dates yet", "日期待定") : trip.start + " – " + trip.end
    let days = tripDayCount(trip)
    let subtitle =
      trip.start.isEmpty ? dates : dates + " · \(days) " + env.t("days", "天")
    let button = UIButton(type: .system)
    button.backgroundColor = .white
    button.layer.cornerRadius = 14
    button.layer.borderWidth = 1
    button.layer.borderColor = CoastStyle.border.cgColor
    let row = UIStackView()
    row.axis = .horizontal
    row.spacing = 12
    row.alignment = .center
    row.isUserInteractionEnabled = false
    row.translatesAutoresizingMaskIntoConstraints = false
    let tile = UIView()
    tile.backgroundColor = CoastStyle.field
    tile.layer.cornerRadius = 10
    tile.widthAnchor.constraint(equalToConstant: 44).isActive = true
    tile.heightAnchor.constraint(equalToConstant: 44).isActive = true
    let icon = UIImageView(image: UIImage(named: "icon-trips"))
    icon.tintColor = CoastStyle.brand
    icon.contentMode = .scaleAspectFit
    icon.translatesAutoresizingMaskIntoConstraints = false
    tile.addSubview(icon)
    NSLayoutConstraint.activate([
      icon.widthAnchor.constraint(equalToConstant: 22),
      icon.heightAnchor.constraint(equalToConstant: 22),
      icon.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
      icon.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
    ])
    row.addArrangedSubview(tile)
    let text = UIStackView()
    text.axis = .vertical
    text.spacing = 4
    text.addArrangedSubview(coastLabel(trip.name, size: 17, weight: .semibold))
    text.addArrangedSubview(coastLabel(subtitle, size: 13, color: CoastStyle.muted))
    row.addArrangedSubview(text)
    let chevron = UIImageView(image: UIImage(named: "icon-next"))
    chevron.tintColor = CoastStyle.brand
    chevron.contentMode = .scaleAspectFit
    chevron.widthAnchor.constraint(equalToConstant: 16).isActive = true
    row.addArrangedSubview(chevron)
    button.addSubview(row)
    NSLayoutConstraint.activate([
      row.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 12),
      row.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -12),
      row.topAnchor.constraint(equalTo: button.topAnchor, constant: 9),
      row.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -9),
    ])
    button.accessibilityLabel = trip.name + ", " + subtitle
    button.addAction(
      UIAction { [weak self] _ in self?.navigationController?.popViewController(animated: true) },
      for: .touchUpInside)
    return button
  }

  private func progressBlock(_ trip: CoastTrip) -> UIView {
    let progress = trip.gearProgress
    let group = UIStackView()
    group.axis = .vertical
    group.spacing = 10
    let line = UIStackView()
    line.axis = .horizontal
    line.alignment = .firstBaseline
    let packed = env.t(
      "\(progress.done) of \(progress.total) packed", "已备 \(progress.done) / \(progress.total) 项")
    line.addArrangedSubview(coastLabel(packed, size: 14, weight: .semibold))
    line.addArrangedSubview(UIView())
    line.addArrangedSubview(
      coastLabel("\(Int((progress.ratio * 100).rounded()))%", size: 13, color: CoastStyle.muted))
    group.addArrangedSubview(line)

    let track = UIView()
    track.backgroundColor = UIColor(hex: 0xE5EDF0)
    track.layer.cornerRadius = 2
    track.heightAnchor.constraint(equalToConstant: 4).isActive = true
    let fill = UIView()
    fill.backgroundColor = CoastStyle.brand
    fill.layer.cornerRadius = 2
    fill.translatesAutoresizingMaskIntoConstraints = false
    track.addSubview(fill)
    NSLayoutConstraint.activate([
      fill.leadingAnchor.constraint(equalTo: track.leadingAnchor),
      fill.topAnchor.constraint(equalTo: track.topAnchor),
      fill.bottomAnchor.constraint(equalTo: track.bottomAnchor),
      fill.widthAnchor.constraint(
        equalTo: track.widthAnchor, multiplier: max(0.001, progress.ratio)),
    ])
    group.addArrangedSubview(track)
    group.accessibilityLabel = packed
    return group
  }

  private func sectionLabel(_ text: String) -> UILabel {
    coastLabel(text.uppercased(), size: 11, weight: .semibold, color: CoastStyle.brand, letterSpacing: 1.7)
  }

  private func gearCard(_ items: [CoastGearItem], trip: CoastTrip) -> UIView {
    let card = UIStackView()
    card.axis = .vertical
    card.spacing = 0
    card.backgroundColor = .white
    card.layer.cornerRadius = 14
    card.layer.borderWidth = 1
    card.layer.borderColor = CoastStyle.border.cgColor
    card.clipsToBounds = true
    for (index, item) in items.enumerated() {
      if index > 0 {
        let divider = UIView()
        divider.backgroundColor = CoastStyle.border
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
        let holder = UIView()
        holder.addSubview(divider)
        divider.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
          // 分隔线内缩到文字起点，与 H5 一致。
          divider.leadingAnchor.constraint(equalTo: holder.leadingAnchor, constant: 48),
          divider.trailingAnchor.constraint(equalTo: holder.trailingAnchor),
          divider.topAnchor.constraint(equalTo: holder.topAnchor),
          divider.bottomAnchor.constraint(equalTo: holder.bottomAnchor),
          holder.heightAnchor.constraint(equalToConstant: 1),
        ])
        card.addArrangedSubview(holder)
      }
      card.addArrangedSubview(gearRow(item, trip: trip))
    }
    return card
  }

  private func gearRow(_ item: CoastGearItem, trip: CoastTrip) -> UIView {
    let container = UIView()
    let toggle = UIButton(type: .system)
    toggle.translatesAutoresizingMaskIntoConstraints = false
    let box = UIView()
    box.backgroundColor = item.done ? CoastStyle.brand : .white
    box.layer.cornerRadius = 7
    box.layer.borderWidth = item.done ? 0 : 1.5
    box.layer.borderColor = UIColor(hex: 0xC3D4DA).cgColor
    box.isUserInteractionEnabled = false
    box.translatesAutoresizingMaskIntoConstraints = false
    if item.done {
      let tick = UIImageView(image: UIImage(named: "icon-check"))
      tick.tintColor = .white
      tick.contentMode = .scaleAspectFit
      tick.translatesAutoresizingMaskIntoConstraints = false
      box.addSubview(tick)
      NSLayoutConstraint.activate([
        tick.widthAnchor.constraint(equalToConstant: 15),
        tick.heightAnchor.constraint(equalToConstant: 15),
        tick.centerXAnchor.constraint(equalTo: box.centerXAnchor),
        tick.centerYAnchor.constraint(equalTo: box.centerYAnchor),
      ])
    }
    let label = coastLabel(
      item.title, size: 16, weight: item.done ? .regular : .medium,
      color: item.done ? CoastStyle.muted : CoastStyle.ink)
    label.numberOfLines = 2
    label.isUserInteractionEnabled = false
    label.translatesAutoresizingMaskIntoConstraints = false
    toggle.addSubview(box)
    toggle.addSubview(label)
    toggle.accessibilityLabel = item.title
    toggle.accessibilityTraits = item.done ? [.button, .selected] : [.button]
    toggle.accessibilityValue = item.done
      ? env.t("Packed", "已备") : env.t("Not packed", "未备")
    toggle.accessibilityIdentifier = "gear.toggle"
    toggle.addAction(
      UIAction { [weak self] _ in
        guard let self else { return }
        if self.save({ try self.env.store.toggleGearItem(tripID: self.tripID, itemID: item.id) }) {
          UIAccessibility.post(
            notification: .announcement,
            argument: item.title + ", "
              + (item.done ? self.env.t("Not packed", "未备") : self.env.t("Packed", "已备")))
          self.render()
        }
      }, for: .touchUpInside)

    let options = UIButton(type: .system)
    options.setImage(UIImage(named: "icon-more"), for: .normal)
    options.tintColor = CoastStyle.muted
    options.translatesAutoresizingMaskIntoConstraints = false
    options.accessibilityLabel = env.t("Options for ", "更多选项：") + item.title
    options.addAction(
      UIAction { [weak self] _ in self?.itemMenu(item, trip: trip) }, for: .touchUpInside)

    container.addSubview(toggle)
    container.addSubview(options)
    NSLayoutConstraint.activate([
      toggle.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      toggle.topAnchor.constraint(equalTo: container.topAnchor),
      toggle.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      toggle.trailingAnchor.constraint(equalTo: options.leadingAnchor),
      box.leadingAnchor.constraint(equalTo: toggle.leadingAnchor, constant: 12),
      box.widthAnchor.constraint(equalToConstant: 24),
      box.heightAnchor.constraint(equalToConstant: 24),
      box.centerYAnchor.constraint(equalTo: toggle.centerYAnchor),
      label.leadingAnchor.constraint(equalTo: box.trailingAnchor, constant: 12),
      label.trailingAnchor.constraint(equalTo: toggle.trailingAnchor, constant: -4),
      label.topAnchor.constraint(equalTo: toggle.topAnchor, constant: 11),
      label.bottomAnchor.constraint(equalTo: toggle.bottomAnchor, constant: -11),
      toggle.heightAnchor.constraint(greaterThanOrEqualToConstant: 46),
      options.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
      options.centerYAnchor.constraint(equalTo: container.centerYAnchor),
      options.widthAnchor.constraint(equalToConstant: 44),
      options.heightAnchor.constraint(equalToConstant: 44),
    ])
    return container
  }

  // MARK: 操作

  private func options() {
    guard let trip else { return }
    menu(
      env.t("Checklist options", "清单选项"),
      choices: [
        (env.t("Add an item", "添加物品"), { [weak self] in self?.addItem() }),
        (env.t("Use a template", "套用模板"), { [weak self] in self?.chooseTemplate() }),
        (env.t("Clear all ticks", "清空全部勾选"), { [weak self] in self?.clearTicks(trip) }),
        (env.t("Remove the whole list", "删除整份清单"), { [weak self] in self?.confirmClear(trip) }),
      ])
  }

  private func clearTicks(_ trip: CoastTrip) {
    guard trip.gearList.contains(where: \.done) else {
      message(
        env.t("Nothing to clear", "没有可清空的勾选"),
        env.t("No items are ticked yet.", "当前没有已勾选的物品。"))
      return
    }
    if save({ try env.store.clearGearTicks(tripID: tripID) }) { render() }
  }

  private func confirmClear(_ trip: CoastTrip) {
    confirm(
      env.t("Remove this checklist?", "删除整份清单？"),
      env.t(
        "All items and ticks for this trip are removed. The trip, experiences and entries are not affected.",
        "这次出游的全部物品与勾选都会移除。出游、体验与手记不受影响。")
    ) { [weak self] in
      guard let self else { return }
      if self.save({ try self.env.store.clearGear(tripID: self.tripID) }) { self.render() }
    }
  }

  private func itemMenu(_ item: CoastGearItem, trip: CoastTrip) {
    var choices: [(String, () -> Void)] = [
      (
        item.done ? env.t("Mark as not packed", "标记为未备") : env.t("Mark as packed", "标记为已备"),
        { [weak self] in
          guard let self else { return }
          if self.save({ try self.env.store.toggleGearItem(tripID: self.tripID, itemID: item.id) }) {
            self.render()
          }
        }
      ),
      (env.t("Rename", "改名"), { [weak self] in self?.rename(item) }),
    ]
    for category in CoastGearItem.categories where category != item.category {
      choices.append(
        (
          env.t("Move to ", "移到") + env.gearGroupName(category),
          { [weak self] in
            guard let self else { return }
            if self.save({
              try self.env.store.updateGearItem(
                tripID: self.tripID, itemID: item.id, category: category)
            }) { self.render() }
          }
        ))
    }
    choices.append(
      (
        env.t("Remove from list", "从清单移除"),
        { [weak self] in
          guard let self else { return }
          if self.save({
            try self.env.store.removeGearItem(tripID: self.tripID, itemID: item.id)
          }) { self.render() }
        }
      ))
    menu(item.title, choices: choices)
  }

  private func addItem() {
    push(GearItemEditorController(env, tripID: tripID, item: nil))
  }

  private func rename(_ item: CoastGearItem) {
    push(GearItemEditorController(env, tripID: tripID, item: item))
  }

  private func chooseTemplate() {
    push(GearTemplateController(env, tripID: tripID))
  }
}

/// 新增或改名一项装备。用原生表单而不是弹窗输入框，便于动态字号与键盘工具栏。
final class GearItemEditorController: CoastController {
  private let tripID: String
  private let item: CoastGearItem?
  private var titleField: UITextField!
  private var category: String
  private var categoryButton: UIButton!

  init(_ env: CoastEnvironment, tripID: String, item: CoastGearItem?) {
    self.tripID = tripID
    self.item = item
    self.category = item?.category ?? "general"
    super.init(env)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) unsupported") }

  override func viewDidLoad() {
    super.viewDidLoad()
    render()
  }

  private func render() {
    reset()
    title = item == nil ? env.t("Add an item", "添加物品") : env.t("Rename", "改名")
    let save = UIBarButtonItem(
      title: env.t("Save", "保存"), primaryAction: UIAction { [weak self] _ in self?.commit() })
    save.accessibilityIdentifier = "gear.save"
    navigationItem.rightBarButtonItem = save
    contentTop.constant = 16
    stack.spacing = 16
    titleField = field(
      env.t("Item", "物品"),
      placeholder: env.t("What do you need to bring?", "需要带什么？"),
      value: item?.title ?? "", id: "gear.title")
    titleField.autocapitalizationType = .sentences
    let label = coastLabel(env.t("Group", "分组"), size: 14)
    add(label)
    stack.setCustomSpacing(8, after: label)
    categoryButton = coastButton(env.gearGroupName(category), secondary: true) { [weak self] in
      self?.pickCategory()
    }
    categoryButton.accessibilityIdentifier = "gear.category"
    add(categoryButton)
    add(
      coastNotice(
        env.t(
          "Items you add yourself are kept as written and are not translated.",
          "自己添加的物品按原文保存，不会被翻译。")))
  }

  private func pickCategory() {
    menu(
      env.t("Group", "分组"),
      choices: CoastGearItem.categories.map { key in
        (
          env.gearGroupName(key),
          { [weak self] in
            guard let self else { return }
            self.category = key
            self.categoryButton.setTitle(self.env.gearGroupName(key), for: .normal)
            var config = self.categoryButton.configuration
            config?.title = self.env.gearGroupName(key)
            self.categoryButton.configuration = config
          }
        )
      })
  }

  private func commit() {
    let text = titleField.text ?? ""
    let done: Bool
    if let item {
      done = save({
        try env.store.updateGearItem(
          tripID: tripID, itemID: item.id, title: text, category: category)
      })
    } else {
      done = save({
        try env.store.addGearItem(
          tripID: tripID, item: CoastGearItem(title: text, category: category))
      })
    }
    if done { navigationController?.popViewController(animated: true) }
  }
}

/// TR06 清单模板。多选后一次套用，只补充缺少的物品。
final class GearTemplateController: CoastController {
  private let tripID: String
  private var picked: Set<String> = []

  init(_ env: CoastEnvironment, tripID: String) {
    self.tripID = tripID
    super.init(env)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) unsupported") }

  override func viewDidLoad() {
    super.viewDidLoad()
    render()
  }

  private var trip: CoastTrip? { env.store.ledger.trips.first { $0.id == tripID } }

  /// 与 CoastStore.applyGearTemplate 用同一套判断：先看 sourceKey，再退回标题。
  private func missingCount(_ template: CoastGearTemplate) -> Int {
    let list = trip?.gearList ?? []
    var present = Set<String>()
    for item in list {
      present.insert("t\u{0}\(item.category)\u{0}\(item.foldedTitle)")
      if let key = item.sourceKey { present.insert("s\u{0}\(key)") }
    }
    return env.gearItems(from: template).filter { candidate in
      !present.contains("s\u{0}\(candidate.sourceKey ?? "")")
        && !present.contains("t\u{0}\(candidate.category)\u{0}\(candidate.foldedTitle)")
    }.count
  }

  private func render() {
    reset()
    title = env.t("Checklist templates", "清单模板")
    contentTop.constant = 16
    stack.spacing = 12
    add(
      coastLabel(
        env.t(
          "Templates only add what is missing. Items you have already ticked are never changed.",
          "模板只补充缺少的物品，不覆盖已勾选的内容。"),
        size: 15, color: CoastStyle.muted))
    for template in env.catalog.templates {
      add(templateCard(template))
    }
    add(
      coastNotice(
        env.t(
          "Templates are original examples for this project. Add or remove items to suit the trip.",
          "模板为本项目原创示例，可按实际出游自行增删。")))
    let apply = coastButton(
      picked.isEmpty
        ? env.t("Apply to this trip", "套用到此出游")
        : env.t("Apply \(picked.count) selected", "套用所选 \(picked.count) 套")
    ) { [weak self] in self?.apply() }
    apply.isEnabled = !picked.isEmpty
    apply.accessibilityIdentifier = "gear.apply"
    add(apply)
  }

  private func templateCard(_ template: CoastGearTemplate) -> UIView {
    let isPicked = picked.contains(template.key)
    let left = missingCount(template)
    let button = UIButton(type: .system)
    button.backgroundColor = .white
    button.layer.cornerRadius = 14
    button.layer.borderWidth = 1
    button.layer.borderColor = (isPicked ? CoastStyle.brand : CoastStyle.border).cgColor
    let row = UIStackView()
    row.axis = .horizontal
    row.spacing = 13
    row.alignment = .center
    row.isUserInteractionEnabled = false
    row.translatesAutoresizingMaskIntoConstraints = false

    let tile = UIView()
    tile.backgroundColor = CoastStyle.field
    tile.layer.cornerRadius = 11
    tile.widthAnchor.constraint(equalToConstant: 48).isActive = true
    tile.heightAnchor.constraint(equalToConstant: 48).isActive = true
    let icon = UIImageView(
      image: UIImage(named: "icon-" + (template.category == "surf" ? "wave" : template.category)))
    icon.tintColor = CoastStyle.brand
    icon.contentMode = .scaleAspectFit
    icon.translatesAutoresizingMaskIntoConstraints = false
    tile.addSubview(icon)
    NSLayoutConstraint.activate([
      icon.widthAnchor.constraint(equalToConstant: 24),
      icon.heightAnchor.constraint(equalToConstant: 24),
      icon.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
      icon.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
    ])
    row.addArrangedSubview(tile)

    let text = UIStackView()
    text.axis = .vertical
    text.spacing = 4
    text.addArrangedSubview(coastLabel(env.text(template.name), size: 17, weight: .semibold))
    text.addArrangedSubview(
      coastLabel(
        "\(template.items.count) " + env.t("items", "项") + " · " + env.text(template.summary),
        size: 13, color: CoastStyle.muted))
    let status = left > 0
      ? env.t("\(left) to add", "可补充 \(left) 项")
      : env.t("Already covered", "已全部具备")
    text.addArrangedSubview(
      coastLabel(status, size: 13, weight: .medium, color: CoastStyle.brand))
    row.addArrangedSubview(text)

    let box = UIView()
    box.backgroundColor = isPicked ? CoastStyle.brand : .white
    box.layer.cornerRadius = 7
    box.layer.borderWidth = isPicked ? 0 : 1.5
    box.layer.borderColor = UIColor(hex: 0xC3D4DA).cgColor
    box.widthAnchor.constraint(equalToConstant: 24).isActive = true
    box.heightAnchor.constraint(equalToConstant: 24).isActive = true
    if isPicked {
      let tick = UIImageView(image: UIImage(named: "icon-check"))
      tick.tintColor = .white
      tick.contentMode = .scaleAspectFit
      tick.translatesAutoresizingMaskIntoConstraints = false
      box.addSubview(tick)
      NSLayoutConstraint.activate([
        tick.widthAnchor.constraint(equalToConstant: 15),
        tick.heightAnchor.constraint(equalToConstant: 15),
        tick.centerXAnchor.constraint(equalTo: box.centerXAnchor),
        tick.centerYAnchor.constraint(equalTo: box.centerYAnchor),
      ])
    }
    row.addArrangedSubview(box)

    button.addSubview(row)
    NSLayoutConstraint.activate([
      row.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 11),
      row.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -11),
      row.topAnchor.constraint(equalTo: button.topAnchor, constant: 10),
      row.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -10),
    ])
    button.accessibilityLabel = env.text(template.name) + ", " + status
    button.accessibilityTraits = isPicked ? [.button, .selected] : [.button]
    button.accessibilityIdentifier = "gear.template." + template.key
    button.addAction(
      UIAction { [weak self] _ in
        guard let self else { return }
        if self.picked.contains(template.key) {
          self.picked.remove(template.key)
        } else {
          self.picked.insert(template.key)
        }
        self.render()
      }, for: .touchUpInside)
    return button
  }

  private func apply() {
    let items = env.catalog.templates
      .filter { picked.contains($0.key) }
      .flatMap { env.gearItems(from: $0) }
    var added = 0
    let ok = save({ added = try env.store.applyGearTemplate(tripID: tripID, items: items) })
    guard ok else { return }
    if added == 0 {
      message(
        env.t("Already covered", "已全部具备"),
        env.t(
          "Everything in those templates is already on the list.",
          "所选模板的物品清单里已经都有了。"))
      return
    }
    UIAccessibility.post(
      notification: .announcement,
      argument: env.t("\(added) items added", "已补充 \(added) 项"))
    navigationController?.popViewController(animated: !UIAccessibility.isReduceMotionEnabled)
  }
}
