import UIKit

enum CoastStyle {
  static let brand = UIColor(hex: 0x075E73), sand = UIColor(hex: 0xE8B86D),
    ink = UIColor(hex: 0x142E37), muted = UIColor(hex: 0x526871), field = UIColor(hex: 0xEDF3F5),
    border = UIColor(hex: 0xD7E2E6), red = UIColor(hex: 0xB42332)
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
  color: UIColor = CoastStyle.ink
) -> UILabel {
  let label = UILabel()
  label.text = text
  label.font = CoastStyle.font(size, weight)
  label.textColor = color
  label.numberOfLines = 0
  label.adjustsFontForContentSizeCategory = true
  return label
}
func coastButton(_ title: String, secondary: Bool = false, action: @escaping () -> Void) -> UIButton
{
  let button = UIButton(type: .system)
  var config = UIButton.Configuration.filled()
  config.title = title
  config.baseBackgroundColor = secondary ? .white : CoastStyle.brand
  config.baseForegroundColor = secondary ? CoastStyle.brand : .white
  config.cornerStyle = .fixed
  config.background.cornerRadius = 12
  config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
  if secondary {
    config.background.strokeColor = CoastStyle.brand
    config.background.strokeWidth = 1
  }
  button.configuration = config
  button.titleLabel?.font = CoastStyle.font(15, .semibold)
  button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
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
    NSLayoutConstraint.activate([
      scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scroll.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
      stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
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
  func heading(_ text: String) { add(coastLabel(text, size: 28, weight: .semibold)) }
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
    let alert = UIAlertController(title: title, message: body, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: env.t("OK", "好"), style: .default))
    present(alert, animated: true)
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
    let alert = UIAlertController(title: title, message: body, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: env.t("Cancel", "取消"), style: .cancel))
    alert.addAction(
      UIAlertAction(title: env.t("Confirm", "确认"), style: .destructive) { _ in action() })
    present(alert, animated: true)
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
  func empty(_ title: String, _ body: String, icon: String = "info") {
    let image = UIImageView(image: UIImage(named: "icon-" + icon))
    image.tintColor = CoastStyle.brand
    image.contentMode = .scaleAspectFit
    image.heightAnchor.constraint(equalToConstant: 60).isActive = true
    add(image)
    add(coastLabel(title, size: 20, weight: .semibold))
    note(body)
  }
  func field(
    _ title: String, placeholder: String = "", value: String = "", secure: Bool = false,
    id: String? = nil
  ) -> UITextField {
    add(coastLabel(title, size: 14, weight: .medium))
    let input = UITextField()
    input.text = value
    input.placeholder = placeholder
    input.font = CoastStyle.font(16)
    input.adjustsFontForContentSizeCategory = true
    input.backgroundColor = CoastStyle.field
    input.layer.cornerRadius = 10
    input.isSecureTextEntry = secure
    input.autocorrectionType = .no
    input.autocapitalizationType = .none
    input.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
    input.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
    input.leftViewMode = .always
    input.accessibilityIdentifier = id
    add(input)
    return input
  }
  func textArea(_ title: String, value: String = "", height: CGFloat = 160) -> UITextView {
    add(coastLabel(title, size: 14, weight: .medium))
    let input = UITextView()
    input.text = value
    input.font = CoastStyle.font(16)
    input.adjustsFontForContentSizeCategory = true
    input.backgroundColor = CoastStyle.field
    input.layer.cornerRadius = 12
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
    button.layer.cornerRadius = 12
    let row = UIStackView()
    row.axis = .horizontal
    row.spacing = 14
    row.alignment = .center
    row.isUserInteractionEnabled = false
    row.translatesAutoresizingMaskIntoConstraints = false
    button.addSubview(row)
    if let image {
      let photo = coastImage(image, height: 92)
      photo.widthAnchor.constraint(equalToConstant: 92).isActive = true
      row.addArrangedSubview(photo)
    }
    let text = UIStackView()
    text.axis = .vertical
    text.spacing = 7
    text.addArrangedSubview(coastLabel(title, size: 17, weight: .semibold))
    if let subtitle {
      text.addArrangedSubview(coastLabel(subtitle, size: 13, color: CoastStyle.muted))
    }
    row.addArrangedSubview(text)
    NSLayoutConstraint.activate([
      row.topAnchor.constraint(equalTo: button.topAnchor, constant: 8),
      row.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -8),
      row.leadingAnchor.constraint(equalTo: button.leadingAnchor),
      row.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -4),
      button.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),
    ])
    button.accessibilityLabel = [title, subtitle].compactMap { $0 }.joined(separator: ", ")
    button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    return button
  }
  func chips(_ titles: [String], selected: Int, onChange: @escaping (Int) -> Void) {
    let segmented = UISegmentedControl(items: titles)
    segmented.selectedSegmentIndex = selected
    segmented.selectedSegmentTintColor = CoastStyle.brand
    segmented.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
    segmented.setTitleTextAttributes([.foregroundColor: CoastStyle.ink], for: .normal)
    segmented.heightAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
    segmented.addAction(
      UIAction { _ in onChange(segmented.selectedSegmentIndex) }, for: .valueChanged)
    add(segmented)
  }
}
