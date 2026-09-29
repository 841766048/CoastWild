import UIKit

/// Shared tokens measured from the approved native-coin-purchase screens.
enum CoinStyle {
  static let background = UIColor(hex: 0xFCFAF6)
  static let surface = UIColor(hex: 0xF3EFE8)
  static let border = UIColor(hex: 0xE4E0DA)
  static let gold = UIColor(hex: 0xAA772B)
  static func text(_ text: String, _ size: CGFloat = 16, _ weight: UIFont.Weight = .regular,
                   color: UIColor = CoastStyle.ink) -> UILabel {
    let label = UILabel()
    label.text = text
    label.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: size, weight: weight))
    label.textColor = color
    label.numberOfLines = 0
    label.adjustsFontForContentSizeCategory = true
    return label
  }
  static func column(_ views: [UIView] = [], spacing: CGFloat = 12) -> UIStackView {
    let stack = UIStackView(arrangedSubviews: views)
    stack.axis = .vertical; stack.spacing = spacing
    return stack
  }
  static func row(_ views: [UIView], spacing: CGFloat = 12) -> UIStackView {
    let stack = UIStackView(arrangedSubviews: views)
    stack.axis = .horizontal; stack.alignment = .center; stack.spacing = spacing
    return stack
  }
  static func panel(_ views: [UIView], fill: UIColor = CoinStyle.background) -> UIStackView {
    let stack = column(views)
    stack.isLayoutMarginsRelativeArrangement = true
    stack.layoutMargins = UIEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
    stack.backgroundColor = fill; stack.layer.cornerRadius = 16
    stack.layer.borderColor = border.cgColor; stack.layer.borderWidth = 0.7
    return stack
  }
  static func button(_ title: String, id: String, secondary: Bool = false,
                     action: @escaping () -> Void) -> UIButton {
    let button = coastButton(title, secondary: secondary, action: action)
    button.configuration?.background.cornerRadius = 16
    button.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
    button.accessibilityIdentifier = id
    return button
  }
  static func link(_ title: String, id: String = "", action: @escaping () -> Void) -> UIButton {
    let button = UIButton(type: .system)
    button.setTitle(title, for: .normal)
    button.titleLabel?.font = CoastStyle.font(16, .semibold)
    button.tintColor = CoastStyle.brand
    button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
    button.accessibilityIdentifier = id
    button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    return button
  }
  static func symbol(_ name: String, size: CGFloat = 24, color: UIColor = CoastStyle.brand) -> UIImageView {
    let image = UIImageView(image: UIImage(systemName: name))
    image.tintColor = color; image.contentMode = .scaleAspectFit
    image.widthAnchor.constraint(equalToConstant: size).isActive = true
    image.heightAnchor.constraint(equalToConstant: size).isActive = true
    return image
  }
  static func separator() -> UIView {
    let view = UIView(); view.backgroundColor = border
    view.heightAnchor.constraint(equalToConstant: 0.7).isActive = true
    return view
  }
  static func value(_ title: String, _ value: String, color: UIColor = CoastStyle.ink) -> UIView {
    let number = text(value, 16, color: color)
    number.setContentCompressionResistancePriority(.required, for: .horizontal)
    return row([text(title), UIView(), number])
  }
  static func tappable(_ content: UIView, id: String, label: String,
                       action: @escaping () -> Void) -> UIButton {
    let button = CoastActionButton(type: .custom)
    content.translatesAutoresizingMaskIntoConstraints = false
    content.isUserInteractionEnabled = false; content.accessibilityElementsHidden = true
    button.addSubview(content)
    NSLayoutConstraint.activate([
      content.topAnchor.constraint(equalTo: button.topAnchor),
      content.bottomAnchor.constraint(equalTo: button.bottomAnchor),
      content.leadingAnchor.constraint(equalTo: button.leadingAnchor),
      content.trailingAnchor.constraint(equalTo: button.trailingAnchor)
    ])
    button.isAccessibilityElement = true; button.accessibilityLabel = label
    button.accessibilityIdentifier = id
    button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    return button
  }
}

/// Only artwork regions are sampled from approved image sources; all text,
/// controls, sheets, balances and navigation are live native UIKit elements.
enum CoinArtwork {
  private static var cache: [String: UIImage] = [:]
  static func image(_ name: String) -> UIImage? {
    if let image = cache[name] { return image }
    let source: String
    let region: CGRect
    switch name {
    case "coast": source = "coin-art-topic"; region = CGRect(x: 166, y: 202, width: 690, height: 347)
    case "purchase": source = "coin-art-purchase"; region = CGRect(x: 193, y: 381, width: 637, height: 322)
    case "coin": source = "coin-art-purchase"; region = CGRect(x: 248, y: 770, width: 91, height: 90)
    case "trail": source = "coin-art-learn"; region = CGRect(x: 216, y: 1070, width: 236, height: 147)
    case "success": source = "coin-art-success"; region = CGRect(x: 200, y: 325, width: 622, height: 242)
    default: return nil
    }
    guard let cg = UIImage(named: source)?.cgImage?.cropping(to: region) else { return nil }
    let result = UIImage(cgImage: cg)
    cache[name] = result
    return result
  }
  static func view(_ name: String, height: CGFloat, rounded: Bool = true) -> UIImageView {
    let view = UIImageView(image: image(name))
    view.contentMode = .scaleAspectFill; view.clipsToBounds = true
    view.layer.cornerRadius = rounded ? 16 : 0
    view.heightAnchor.constraint(equalToConstant: height).isActive = true
    return view
  }
  static func coin(_ size: CGFloat) -> UIImageView {
    let view = self.view("coin", height: size, rounded: false)
    view.contentMode = .scaleAspectFit
    view.layer.cornerRadius = size / 2
    view.widthAnchor.constraint(equalToConstant: size).isActive = true
    return view
  }
  static func fullBleed(_ name: String, height: CGFloat) -> UIView {
    let container = UIView()
    let image = view(name, height: height, rounded: false)
    image.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(image)
    NSLayoutConstraint.activate([
      image.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: -20),
      image.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: 20),
      image.topAnchor.constraint(equalTo: container.topAnchor),
      image.bottomAnchor.constraint(equalTo: container.bottomAnchor)
    ])
    return container
  }
}

class CoinScreen: CoastController {
  private var footer: UIView?
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = CoinStyle.background
    stack.spacing = 20
  }
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    let appearance = UINavigationBarAppearance()
    appearance.configureWithOpaqueBackground()
    appearance.backgroundColor = CoinStyle.background
    appearance.shadowColor = .clear
    appearance.buttonAppearance.normal.titleTextAttributes = [.foregroundColor: CoastStyle.brand]
    appearance.backButtonAppearance.normal.titleTextAttributes = [.foregroundColor: CoastStyle.brand]
    navigationItem.standardAppearance = appearance
    navigationItem.scrollEdgeAppearance = appearance
  }
  func pinFooter(_ content: UIView) {
    footer?.removeFromSuperview()
    let holder = CoinStyle.column([content])
    holder.backgroundColor = CoinStyle.background
    holder.isLayoutMarginsRelativeArrangement = true
    holder.layoutMargins = UIEdgeInsets(top: 12, left: 20, bottom: 8, right: 20)
    holder.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(holder); footer = holder
    NSLayoutConstraint.activate([
      holder.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      holder.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      holder.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
    ])
    view.setNeedsLayout()
  }
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    scroll.contentInset.bottom = footer?.bounds.height ?? 0
    scroll.verticalScrollIndicatorInsets.bottom = scroll.contentInset.bottom
    if #available(iOS 26.0, *) {
      navigationItem.rightBarButtonItems?.forEach { $0.hidesSharedBackground = true; $0.tintColor = CoastStyle.brand }
    }
  }
  func showCoinError(_ error: Error) {
    message("Unable to complete", "Your coins have not been changed. Please try again. If the problem continues, keep this app installed and contact support.")
  }
}

final class CoinScenicPanel: UIView {
  private let shade = CAGradientLayer()
  init(content: UIView) {
    super.init(frame: .zero)
    layer.cornerRadius = 16; clipsToBounds = true
    let photo = UIImageView(image: CoinArtwork.image("coast"))
    photo.contentMode = .scaleAspectFill; photo.clipsToBounds = true
    // The decoration must not determine the wallet card's content-driven size.
    photo.setContentHuggingPriority(UILayoutPriority(1), for: .vertical)
    photo.setContentCompressionResistancePriority(UILayoutPriority(1), for: .vertical)
    photo.setContentHuggingPriority(UILayoutPriority(1), for: .horizontal)
    photo.setContentCompressionResistancePriority(UILayoutPriority(1), for: .horizontal)
    photo.translatesAutoresizingMaskIntoConstraints = false; addSubview(photo)
    shade.colors = [CoinStyle.surface.cgColor, CoinStyle.surface.withAlphaComponent(0.95).cgColor,
                    CoinStyle.surface.withAlphaComponent(0.3).cgColor]
    shade.locations = [0, 0.45, 1]
    shade.startPoint = CGPoint(x: 0, y: 0.5); shade.endPoint = CGPoint(x: 1, y: 0.5)
    layer.addSublayer(shade)
    content.backgroundColor = .clear
    content.translatesAutoresizingMaskIntoConstraints = false; addSubview(content)
    NSLayoutConstraint.activate([
      photo.leadingAnchor.constraint(equalTo: leadingAnchor), photo.trailingAnchor.constraint(equalTo: trailingAnchor),
      photo.topAnchor.constraint(equalTo: topAnchor), photo.bottomAnchor.constraint(equalTo: bottomAnchor),
      content.leadingAnchor.constraint(equalTo: leadingAnchor), content.trailingAnchor.constraint(equalTo: trailingAnchor),
      content.topAnchor.constraint(equalTo: topAnchor), content.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])
  }
  required init?(coder: NSCoder) { fatalError() }
  override func layoutSubviews() { super.layoutSubviews(); shade.frame = bounds }
}
