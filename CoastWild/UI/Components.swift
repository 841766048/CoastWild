import UIKit

enum CoastStyle {
  static let brand = UIColor(hex: 0x075E73), sand = UIColor(hex: 0xE8B86D),
    ink = UIColor(hex: 0x142E37), muted = UIColor(hex: 0x526871), field = UIColor(hex: 0xEDF3F5),
    inputFill = UIColor(hex: 0xEFF4F6), border = UIColor(hex: 0xDFE9ED), red = UIColor(hex: 0xB42332)
  static func font(_ size: CGFloat, _ weight: UIFont.Weight = .regular) -> UIFont {
    UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: size, weight: weight))
  }
}
extension UIColor {
  convenience init(hex: UInt) {
    self.init(
      red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
      blue: CGFloat(hex & 255) / 255, alpha: 1)
  }
}
func coastLabel(
  _ text: String, size: CGFloat = 16, weight: UIFont.Weight = .regular,
  color: UIColor = CoastStyle.ink, lineHeight: CGFloat? = nil, letterSpacing: CGFloat? = nil
) -> UILabel {
  let label = UILabel()
  label.text = text
  let containsChinese = text.unicodeScalars.contains { (0x3400...0x9fff).contains($0.value) }
  let face = weight >= .semibold ? "PingFangSC-Semibold" : weight >= .medium ? "PingFangSC-Medium" : "PingFangSC-Regular"
  label.font = containsChinese
    ? UIFontMetrics(forTextStyle: .body).scaledFont(for: UIFont(name: face, size: size) ?? .systemFont(ofSize: size, weight: weight))
    : CoastStyle.font(size, weight)
  let paragraph = NSMutableParagraphStyle()
  let titleLines: [CGFloat: CGFloat] = [17: 22.1, 18: 23.4, 19: 22.8, 21: 25.2, 22: 28.6, 23: 27.6, 24: 28.8, 27: 30.24, 30: 34.5, 32: 35.84, 38: 42.56]
  let titleTracking: [CGFloat: CGFloat] = [16: -0.3, 17: -0.3, 18: -0.3, 19: -0.5, 21: -0.5, 22: -0.3, 23: -0.5, 24: -0.5, 27: -1.2, 30: -1.2, 32: -1.2, 38: -1.5]
  let resolvedLineHeight = lineHeight ?? (weight >= .semibold ? (titleLines[size] ?? size * 1.5) : size * 1.5)
  paragraph.minimumLineHeight = UIFontMetrics(forTextStyle: .body).scaledValue(for: resolvedLineHeight)
  paragraph.maximumLineHeight = paragraph.minimumLineHeight
  label.attributedText = NSAttributedString(string: text, attributes: [.paragraphStyle: paragraph, .kern: letterSpacing ?? (weight >= .semibold ? (titleTracking[size] ?? 0) : 0)])
  label.textColor = color
  label.numberOfLines = 0
  label.adjustsFontForContentSizeCategory = true
  return label
}
final class CoastActionButton: UIButton {
  override var isHighlighted: Bool {
    didSet {
      guard !UIAccessibility.isReduceMotionEnabled else {
        transform = .identity
        return
      }
      if isHighlighted {
        layer.removeAllAnimations()
        transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
      } else {
        UIView.animate(
          withDuration: 0.16, delay: 0,
          options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut]
        ) { self.transform = .identity }
      }
    }
  }
}
func coastButton(_ title: String, secondary: Bool = false, action: @escaping () -> Void) -> UIButton
{
  let button = CoastActionButton(type: .system)
  var config = UIButton.Configuration.filled()
  config.title = title
  config.baseBackgroundColor = secondary ? .white : CoastStyle.brand
  config.baseForegroundColor = secondary ? CoastStyle.brand : .white
  config.cornerStyle = .fixed
  config.background.cornerRadius = 12
  config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
  config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
    var attributes = incoming
    attributes.font = CoastStyle.font(16, .semibold)
    return attributes
  }
  if secondary {
    config.background.strokeColor = CoastStyle.brand
    config.background.strokeWidth = 1
  }
  button.configuration = config
  button.titleLabel?.font = CoastStyle.font(16, .semibold)
  button.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
  button.addAction(UIAction { _ in action() }, for: .touchUpInside)
  return button
}
func coastImage(_ name: String, height: CGFloat) -> UIImageView {
  let image = UIImageView(image: UIImage(named: name))
  image.contentMode = .scaleAspectFill
  image.clipsToBounds = true
  image.layer.cornerRadius = 16
  image.heightAnchor.constraint(equalToConstant: height).isActive = true
  image.isAccessibilityElement = true
  image.accessibilityLabel = name.replacingOccurrences(of: "-", with: " ")
  return image
}
class CoastController: UIViewController {
  let env: CoastEnvironment
  let scroll = UIScrollView()
  let stack = UIStackView()
  var contentTop: NSLayoutConstraint!
  init(_ env: CoastEnvironment) {
    self.env = env
    super.init(nibName: nil, bundle: nil)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) unsupported") }
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    scroll.keyboardDismissMode = .interactive
    scroll.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(scroll)
    stack.axis = .vertical
    stack.spacing = 16
    stack.translatesAutoresizingMaskIntoConstraints = false
    scroll.addSubview(stack)
    contentTop = stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16)
    NSLayoutConstraint.activate([
      scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
      contentTop,
      stack.leadingAnchor.constraint(
        equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 20),
      stack.trailingAnchor.constraint(
        equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -20),
      stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
      stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40),
    ])
    navigationItem.backButtonTitle = env.t("Back", "返回")
  }
  func reset() { stack.arrangedSubviews.forEach { $0.removeFromSuperview() } }
  func add(_ view: UIView) { stack.addArrangedSubview(view) }
  func heading(_ text: String) { add(coastLabel(text, size: 32, weight: .bold)) }
  func note(_ text: String) { add(coastLabel(text, size: 13, color: CoastStyle.muted)) }
  func push(_ controller: UIViewController) {
    controller.hidesBottomBarWhenPushed = true
    navigationController?.pushViewController(
      controller, animated: !UIAccessibility.isReduceMotionEnabled)
  }
  func iconItem(_ icon: String, label: String, action: @escaping () -> Void) -> UIBarButtonItem {
    let item = UIBarButtonItem(
      image: UIImage(named: "icon-" + icon), primaryAction: UIAction { _ in action() })
    item.accessibilityLabel = label
    return item
  }
  func error(_ error: Error) { message(env.t("Unable to save", "未能保存"), env.errorText(error)) }
  func message(_ title: String, _ body: String) {
    present(CoastDialog(title: title, message: body, actions: [(env.t("OK", "好"), false, {})]), animated: false)
  }
  func perform(_ body: () -> Void) { body() }
  @discardableResult func save(_ body: () throws -> Void) -> Bool {
    do {
      try body()
      return true
    } catch {
      self.error(error)
      return false
    }
  }
  func confirm(_ title: String, _ body: String, action: @escaping () -> Void) {
    present(CoastDialog(title: title, message: body, actions: [
      (env.t("Confirm", "确认"), true, action), (env.t("Cancel", "取消"), false, {})
    ]), animated: false)
  }
  func menu(_ title: String, choices: [(String, () -> Void)]) {
    let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
    choices.forEach { choice in
      alert.addAction(UIAlertAction(title: choice.0, style: .default) { _ in choice.1() })
    }
    alert.addAction(UIAlertAction(title: env.t("Cancel", "取消"), style: .cancel))
    alert.popoverPresentationController?.sourceView = view
    present(alert, animated: true)
  }
  func empty(_ title: String, _ body: String, icon: String = "info", actionTitle: String? = nil, action: (() -> Void)? = nil) {
    let container = UIView()
    container.heightAnchor.constraint(greaterThanOrEqualToConstant: 420).isActive = true
    let group = UIStackView(); group.axis = .vertical; group.alignment = .center; group.spacing = 16
    group.translatesAutoresizingMaskIntoConstraints = false; container.addSubview(group)
    let circle = UIView(); circle.backgroundColor = CoastStyle.field; circle.layer.cornerRadius = 42
    circle.widthAnchor.constraint(equalToConstant: 84).isActive = true
    circle.heightAnchor.constraint(equalToConstant: 84).isActive = true
    let image = UIImageView(image: UIImage(named: "icon-" + icon)); image.contentMode = .scaleAspectFit; image.tintColor = CoastStyle.brand
    image.translatesAutoresizingMaskIntoConstraints = false; circle.addSubview(image)
    NSLayoutConstraint.activate([image.widthAnchor.constraint(equalToConstant: 38), image.heightAnchor.constraint(equalToConstant: 38), image.centerXAnchor.constraint(equalTo: circle.centerXAnchor), image.centerYAnchor.constraint(equalTo: circle.centerYAnchor)])
    group.addArrangedSubview(circle)
    let heading = coastLabel(title, size: 23, weight: .bold); heading.textAlignment = .center; group.addArrangedSubview(heading)
    let detail = coastLabel(body, size: 15, color: CoastStyle.muted); detail.textAlignment = .center; group.addArrangedSubview(detail)
    if let actionTitle, let action {
      let button = coastButton(actionTitle, action: action); group.addArrangedSubview(button)
      button.widthAnchor.constraint(equalTo: group.widthAnchor).isActive = true
      group.setCustomSpacing(28, after: detail)
    }
    NSLayoutConstraint.activate([
      group.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
      group.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
      group.centerYAnchor.constraint(equalTo: container.centerYAnchor),
      group.topAnchor.constraint(greaterThanOrEqualTo: container.topAnchor, constant: 16),
      group.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -16)
    ])
    add(container)
  }
  func field(
    _ title: String, placeholder: String = "", value: String = "", secure: Bool = false,
    id: String? = nil
  ) -> UITextField {
    let label = coastLabel(title, size: 14)
    add(label)
    stack.setCustomSpacing(8, after: label)
    let input = UITextField()
    input.text = value
    input.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [.foregroundColor: UIColor(hex: 0x757575), .font: CoastStyle.font(14)])
    input.font = CoastStyle.font(14)
    input.adjustsFontForContentSizeCategory = true
    input.backgroundColor = CoastStyle.inputFill
    input.layer.cornerRadius = 9
    input.isSecureTextEntry = secure
    input.autocorrectionType = .no
    input.autocapitalizationType = .none
    input.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
    input.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
    input.leftViewMode = .always
    input.accessibilityIdentifier = id
    add(input)
    return input
  }
  func textArea(_ title: String, value: String = "", height: CGFloat = 160) -> UITextView {
    let label = coastLabel(title, size: 14)
    add(label)
    stack.setCustomSpacing(8, after: label)
    let input = UITextView()
    input.text = value
    input.font = CoastStyle.font(14)
    input.adjustsFontForContentSizeCategory = true
    input.backgroundColor = CoastStyle.inputFill
    input.layer.cornerRadius = 9
    input.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
    input.heightAnchor.constraint(equalToConstant: height).isActive = true
    add(input)
    return input
  }
  func row(
    title: String, subtitle: String? = nil, image: String? = nil, action: @escaping () -> Void
  ) -> UIView {
    let button = UIButton(type: .system)
    button.backgroundColor = .white
    button.layer.cornerRadius = 14
    button.layer.borderWidth = 1
    button.layer.borderColor = CoastStyle.border.cgColor
    let row = UIStackView()
    row.axis = .horizontal
    row.spacing = 13
    row.alignment = .center
    row.isUserInteractionEnabled = false
    row.translatesAutoresizingMaskIntoConstraints = false
    button.addSubview(row)
    if let image {
      let photo = coastImage(image, height: 90)
      photo.widthAnchor.constraint(equalToConstant: 88).isActive = true
      row.addArrangedSubview(photo)
    }
    let text = UIStackView()
    text.axis = .vertical
    text.spacing = 7
    text.addArrangedSubview(coastLabel(title, size: 17, weight: .bold))
    if let subtitle {
      text.addArrangedSubview(coastLabel(subtitle, size: 13, color: CoastStyle.muted))
    }
    row.addArrangedSubview(text)
    NSLayoutConstraint.activate([
      row.topAnchor.constraint(equalTo: button.topAnchor, constant: 12),
      row.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -12),
      row.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 12),
      row.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -12),
      button.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),
    ])
    button.accessibilityLabel = [title, subtitle].compactMap { $0 }.joined(separator: ", ")
    button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    return button
  }
  func chips(_ titles: [String], selected: Int, onChange: @escaping (Int) -> Void) {
    let container = UIStackView(); container.axis = .horizontal; container.spacing = 4
    container.distribution = .fillEqually; container.backgroundColor = CoastStyle.field
    container.layer.cornerRadius = 10; container.isLayoutMarginsRelativeArrangement = true
    container.layoutMargins = UIEdgeInsets(top: 3, left: 3, bottom: 3, right: 3)
    for (index, title) in titles.enumerated() {
      let button = UIButton(type: .system)
      button.setTitle(title, for: .normal); button.titleLabel?.font = CoastStyle.font(14)
      button.setTitleColor(index == selected ? .white : CoastStyle.ink, for: .normal)
      button.backgroundColor = index == selected ? CoastStyle.brand : .clear; button.layer.cornerRadius = 7
      button.heightAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
      button.accessibilityTraits = index == selected ? [.button, .selected] : [.button]
      button.addAction(UIAction { _ in onChange(index) }, for: .touchUpInside)
      container.addArrangedSubview(button)
    }
    add(container)
  }

}

/// HF-v1.2 grouped panel; insets and stroke come from the imported design.
func coastPanel(_ views: [UIView], spacing: CGFloat = 16, inset: CGFloat = 14) -> UIStackView {
  let panel = UIStackView(arrangedSubviews: views)
  panel.axis = .vertical; panel.spacing = spacing
  panel.isLayoutMarginsRelativeArrangement = true
  panel.layoutMargins = UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
  panel.layer.cornerRadius = 14; panel.layer.borderWidth = 1
  panel.layer.borderColor = CoastStyle.border.cgColor; panel.backgroundColor = .white
  return panel
}
func coastSettingRow(_ title: String, value: String? = nil, icon: String? = nil, destructive: Bool = false, action: @escaping () -> Void) -> UIButton {
  let button = UIButton(type: .system)
  let row = UIStackView(); row.axis = .horizontal; row.spacing = 12; row.alignment = .center
  row.translatesAutoresizingMaskIntoConstraints = false; row.isUserInteractionEnabled = false
  if let icon {
    let image = UIImageView(image: UIImage(named: "icon-" + icon)); image.contentMode = .scaleAspectFit
    image.tintColor = destructive ? CoastStyle.red : CoastStyle.brand
    image.widthAnchor.constraint(equalToConstant: 21).isActive = true
    image.heightAnchor.constraint(equalToConstant: 24).isActive = true
    row.addArrangedSubview(image)
  }
  row.addArrangedSubview(coastLabel(title, size: 15, color: destructive ? CoastStyle.red : CoastStyle.ink))
  row.addArrangedSubview(UIView())
  if let value { row.addArrangedSubview(coastLabel(value, size: 12, color: CoastStyle.muted)) }
  let chevron = UIImageView(image: UIImage(named: "icon-next")); chevron.tintColor = CoastStyle.muted; chevron.contentMode = .scaleAspectFit
  chevron.widthAnchor.constraint(equalToConstant: 16).isActive = true
  chevron.heightAnchor.constraint(equalToConstant: 24).isActive = true; row.addArrangedSubview(chevron)
  button.addSubview(row)
  NSLayoutConstraint.activate([
    button.heightAnchor.constraint(greaterThanOrEqualToConstant: 59),
    row.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 14),
    row.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -14),
    row.topAnchor.constraint(equalTo: button.topAnchor, constant: 17.5),
    row.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -17.5)
  ])
  button.accessibilityLabel = [title, value].compactMap { $0 }.joined(separator: ", ")
  button.addAction(UIAction { _ in action() }, for: .touchUpInside)
  return button
}
func coastStats(_ values: [(String, String)]) -> UIView {
  let row = UIStackView(); row.axis = .horizontal; row.distribution = .fillEqually
  row.backgroundColor = .clear
  row.isLayoutMarginsRelativeArrangement = true; row.layoutMargins = UIEdgeInsets(top: 18, left: 0, bottom: 18, right: 0)
  for (value, title) in values {
    let group = UIStackView(); group.axis = .vertical; group.spacing = 5; group.alignment = .center
    group.addArrangedSubview(coastLabel(value, size: 18, weight: .bold, lineHeight: 21.5, letterSpacing: 0))
    group.addArrangedSubview(coastLabel(title, size: 13, color: CoastStyle.muted, lineHeight: 18.85)); row.addArrangedSubview(group)
  }
  for edge in [true, false] {
    let rule = UIView(); rule.backgroundColor = CoastStyle.border; rule.translatesAutoresizingMaskIntoConstraints = false
    row.addSubview(rule)
    NSLayoutConstraint.activate([rule.leadingAnchor.constraint(equalTo: row.leadingAnchor), rule.trailingAnchor.constraint(equalTo: row.trailingAnchor), rule.heightAnchor.constraint(equalToConstant: 1), edge ? rule.topAnchor.constraint(equalTo: row.topAnchor) : rule.bottomAnchor.constraint(equalTo: row.bottomAnchor)])
  }
  return row
}

/// Native UIKit version of the HF-v1.2 centered confirmation/error dialog.
final class CoastDialog: UIViewController {
  private let heading: String
  private let message: String
  private let actions: [(String, Bool, () -> Void)]
  init(title: String, message: String, actions: [(String, Bool, () -> Void)]) {
    self.heading = title; self.message = message; self.actions = actions
    super.init(nibName: nil, bundle: nil)
    modalPresentationStyle = .overFullScreen
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) unsupported") }
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = UIColor(hex: 0x10252E).withAlphaComponent(0.35)
    view.accessibilityViewIsModal = true
    let card = UIStackView(); card.axis = .vertical; card.backgroundColor = .white
    card.layer.cornerRadius = 18; card.clipsToBounds = true; card.translatesAutoresizingMaskIntoConstraints = false
    let title = coastLabel(heading, size: 19, weight: .bold); title.textAlignment = .center
    let body = coastLabel(message, size: 14, color: CoastStyle.muted); body.textAlignment = .center
    let content = UIStackView(arrangedSubviews: [title, body]); content.axis = .vertical; content.spacing = 12
    content.isLayoutMarginsRelativeArrangement = true
    content.layoutMargins = UIEdgeInsets(top: 24, left: 20, bottom: 24, right: 20)
    card.addArrangedSubview(content)
    for (text, destructive, action) in actions {
      let divider = UIView(); divider.backgroundColor = CoastStyle.border; divider.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
      card.addArrangedSubview(divider)
      let button = UIButton(type: .system); button.setTitle(text, for: .normal)
      button.titleLabel?.font = CoastStyle.font(16)
      button.setTitleColor(destructive ? CoastStyle.red : CoastStyle.brand, for: .normal)
      button.heightAnchor.constraint(greaterThanOrEqualToConstant: 51).isActive = true
      button.addAction(UIAction { [weak self] _ in self?.dismiss(animated: false, completion: action) }, for: .touchUpInside)
      card.addArrangedSubview(button)
    }
    let scroll = UIScrollView(); scroll.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(scroll); scroll.addSubview(card)
    let idealHeight = scroll.heightAnchor.constraint(equalTo: card.heightAnchor)
    idealHeight.priority = .defaultHigh
    NSLayoutConstraint.activate([
      scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 35),
      scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -35),
      scroll.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
      idealHeight,
      scroll.heightAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.heightAnchor, constant: -24),
      card.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
      card.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
      card.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
      card.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
      card.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
    ])
  }
}

func coastNotice(_ text: String) -> UIView {
  let group = UIStackView(); group.axis = .horizontal; group.spacing = 10; group.alignment = .top
  group.isLayoutMarginsRelativeArrangement = true
  group.layoutMargins = UIEdgeInsets(top: 15, left: 0, bottom: 15, right: 0)
  let image = UIImageView(image: UIImage(named: "icon-info")); image.tintColor = CoastStyle.muted; image.contentMode = .scaleAspectFit
  image.widthAnchor.constraint(equalToConstant: 19).isActive = true; image.heightAnchor.constraint(equalToConstant: 19).isActive = true
  group.addArrangedSubview(image); group.addArrangedSubview(coastLabel(text, size: 13, color: CoastStyle.muted))
  return group
}
func coastFormPanel(_ views: [UIView], spacing: CGFloat = 18) -> UIStackView {
  let panel = coastPanel(views, spacing: spacing)
  panel.layer.borderWidth = 0
  panel.layoutMargins = UIEdgeInsets(top: 18, left: 14, bottom: 18, right: 14)
  return panel
}

func coastPreviewBadge(_ env: CoastEnvironment) -> UIView {
  let badge = UIView()
  badge.backgroundColor = UIColor(hex: 0xF8EFDE)
  badge.layer.cornerRadius = 6
  let label = coastLabel(env.t("Local preview", "本地演示"), size: 11, color: UIColor(hex: 0x705523))
  label.translatesAutoresizingMaskIntoConstraints = false; badge.addSubview(label)
  NSLayoutConstraint.activate([
    label.leadingAnchor.constraint(equalTo: badge.leadingAnchor, constant: 9),
    label.trailingAnchor.constraint(equalTo: badge.trailingAnchor, constant: -9),
    label.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
    badge.heightAnchor.constraint(greaterThanOrEqualToConstant: 25),
    label.topAnchor.constraint(greaterThanOrEqualTo: badge.topAnchor, constant: 4)
  ])
  return badge
}
