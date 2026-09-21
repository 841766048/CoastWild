import UIKit

final class PrivacyConsentController: UIViewController, UITextViewDelegate {
  private let env: CoastEnvironment
  private var checked = false
  private let checkbox = UIButton(type: .system)
  private let validation = coastLabel("", size: 12, color: CoastStyle.red)

  init(_ env: CoastEnvironment) {
    self.env = env
    super.init(nibName: nil, bundle: nil)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) unsupported") }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = UIColor(hex: 0xF7F3EA)
    build()
  }

  private func build() {
    let scroll = UIScrollView()
    scroll.alwaysBounceVertical = true
    scroll.contentInsetAdjustmentBehavior = .never
    scroll.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(scroll)

    let content = UIView()
    content.translatesAutoresizingMaskIntoConstraints = false
    scroll.addSubview(content)
    NSLayoutConstraint.activate([
      scroll.topAnchor.constraint(equalTo: view.topAnchor),
      scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
      content.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
      content.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
      content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
      content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
      content.heightAnchor.constraint(greaterThanOrEqualTo: scroll.frameLayoutGuide.heightAnchor),
    ])

    let hero = UIImageView(image: UIImage(named: "privacy-hero"))
    hero.contentMode = .scaleAspectFill
    hero.clipsToBounds = true
    hero.isAccessibilityElement = true
    hero.accessibilityLabel = env.t("Coastal mountain overlook", "海岸山野风景")
    hero.translatesAutoresizingMaskIntoConstraints = false
    content.addSubview(hero)

    let body = UIView()
    body.backgroundColor = UIColor(hex: 0xF7F3EA)
    body.layer.cornerRadius = 28
    body.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    body.translatesAutoresizingMaskIntoConstraints = false
    content.addSubview(body)

    let stack = UIStackView()
    stack.axis = .vertical
    stack.spacing = 8
    stack.translatesAutoresizingMaskIntoConstraints = false
    body.addSubview(stack)

    let mark = UIView()
    mark.backgroundColor = UIColor(hex: 0xFFFDF7)
    mark.layer.cornerRadius = 36
    mark.layer.shadowColor = UIColor.black.cgColor
    mark.layer.shadowOpacity = 0.08
    mark.layer.shadowRadius = 14
    mark.layer.shadowOffset = CGSize(width: 0, height: 5)
    mark.translatesAutoresizingMaskIntoConstraints = false
    body.addSubview(mark)
    let markImage = UIImageView(image: UIImage(systemName: "mountain.2.fill"))
    markImage.contentMode = .scaleAspectFit
    markImage.tintColor = UIColor(hex: 0x2F5D50)
    markImage.translatesAutoresizingMaskIntoConstraints = false
    mark.addSubview(markImage)

    let title = coastLabel(env.t("Welcome to Coast & Wild", "欢迎来到海岸与山野"), size: 25, weight: .bold)
    title.textAlignment = .center
    stack.addArrangedSubview(title)
    let subtitle = coastLabel(
      env.t("Before you set out, see how we protect your information.", "在出发之前，请先了解我们如何保护你的信息"),
      size: 14, color: CoastStyle.muted)
    subtitle.textAlignment = .center
    stack.addArrangedSubview(subtitle)
    stack.setCustomSpacing(17, after: subtitle)

    stack.addArrangedSubview(infoRow(
      icon: "person.crop.circle", title: env.t("Account information", "账户信息"),
      detail: env.t("Used to sign in and save preferences", "用于登录与保存个人设置")))
    stack.addArrangedSubview(infoRow(
      icon: "photo", title: env.t("Photo access", "照片权限"),
      detail: env.t("Requested only when adding a cover or entry", "仅在添加封面或记录时请求")))
    stack.setCustomSpacing(17, after: stack.arrangedSubviews.last!)

    let agreementRow = UIStackView()
    agreementRow.axis = .horizontal
    agreementRow.alignment = .top
    agreementRow.spacing = 8
    checkbox.tintColor = UIColor(hex: 0x2F5D50)
    checkbox.accessibilityIdentifier = "privacy.checkbox"
    checkbox.accessibilityLabel = env.t("I have read and agree", "我已阅读并同意")
    checkbox.widthAnchor.constraint(equalToConstant: 30).isActive = true
    checkbox.heightAnchor.constraint(equalToConstant: 30).isActive = true
    checkbox.addAction(UIAction { [weak self] _ in self?.toggleAgreement() }, for: .touchUpInside)
    updateCheckbox()
    agreementRow.addArrangedSubview(checkbox)

    let agreement = UITextView()
    agreement.backgroundColor = .clear
    agreement.isEditable = false
    agreement.isScrollEnabled = false
    agreement.textContainerInset = UIEdgeInsets(top: 4, left: 0, bottom: 0, right: 0)
    agreement.textContainer.lineFragmentPadding = 0
    agreement.delegate = self
    agreement.adjustsFontForContentSizeCategory = true
    agreement.accessibilityIdentifier = "privacy.agreement"
    agreement.attributedText = agreementText()
    agreement.linkTextAttributes = [
      .foregroundColor: UIColor(hex: 0x2F5D50), .underlineStyle: NSUnderlineStyle.single.rawValue,
    ]
    agreementRow.addArrangedSubview(agreement)
    agreementRow.heightAnchor.constraint(equalToConstant: 42).isActive = true
    stack.addArrangedSubview(agreementRow)

    validation.text = env.t("Please read and accept both agreements first.", "请先阅读并同意用户协议和隐私政策。")
    validation.textAlignment = .center
    validation.isHidden = true
    validation.accessibilityIdentifier = "privacy.validation"
    stack.addArrangedSubview(validation)

    let continueButton = coastButton(env.t("Agree and continue", "同意并继续")) { [weak self] in
      guard let self else { return }
      guard checked else {
        validation.isHidden = false
        UIAccessibility.post(notification: .announcement, argument: validation.text)
        return
      }
      env.acceptPrivacy()
    }
    continueButton.accessibilityIdentifier = "privacy.continue"
    continueButton.configuration?.baseBackgroundColor = UIColor(hex: 0x2F5D50)
    stack.addArrangedSubview(continueButton)

    let decline = UIButton(type: .system)
    decline.setTitle(env.t("Not now", "暂不同意"), for: .normal)
    decline.setTitleColor(UIColor(hex: 0x2F5D50), for: .normal)
    decline.titleLabel?.font = CoastStyle.font(15, .semibold)
    decline.heightAnchor.constraint(equalToConstant: 42).isActive = true
    decline.accessibilityIdentifier = "privacy.decline"
    decline.addAction(UIAction { [weak self] _ in self?.showDeclineSheet() }, for: .touchUpInside)
    stack.addArrangedSubview(decline)

    let footnote = coastLabel(
      env.t("Photo access is requested only when you use the related feature.", "仅在使用相关功能时单独请求照片权限"),
      size: 11, color: CoastStyle.muted)
    footnote.textAlignment = .center
    stack.addArrangedSubview(footnote)

    NSLayoutConstraint.activate([
      hero.topAnchor.constraint(equalTo: content.topAnchor),
      hero.leadingAnchor.constraint(equalTo: content.leadingAnchor),
      hero.trailingAnchor.constraint(equalTo: content.trailingAnchor),
      hero.heightAnchor.constraint(equalToConstant: 300),
      body.topAnchor.constraint(equalTo: hero.bottomAnchor, constant: -24),
      body.leadingAnchor.constraint(equalTo: content.leadingAnchor),
      body.trailingAnchor.constraint(equalTo: content.trailingAnchor),
      body.bottomAnchor.constraint(equalTo: content.bottomAnchor),
      mark.centerXAnchor.constraint(equalTo: body.centerXAnchor),
      mark.centerYAnchor.constraint(equalTo: body.topAnchor),
      mark.widthAnchor.constraint(equalToConstant: 72),
      mark.heightAnchor.constraint(equalToConstant: 72),
      markImage.centerXAnchor.constraint(equalTo: mark.centerXAnchor),
      markImage.centerYAnchor.constraint(equalTo: mark.centerYAnchor),
      markImage.widthAnchor.constraint(equalToConstant: 42),
      markImage.heightAnchor.constraint(equalToConstant: 42),
      stack.topAnchor.constraint(equalTo: body.topAnchor, constant: 46),
      stack.leadingAnchor.constraint(equalTo: body.leadingAnchor, constant: 24),
      stack.trailingAnchor.constraint(equalTo: body.trailingAnchor, constant: -24),
      stack.bottomAnchor.constraint(lessThanOrEqualTo: body.bottomAnchor, constant: -20),
    ])
  }

  private func infoRow(icon: String, title: String, detail: String) -> UIView {
    let row = UIStackView()
    row.axis = .horizontal
    row.alignment = .center
    row.spacing = 12
    let image = UIImageView(image: UIImage(systemName: icon))
    image.tintColor = CoastStyle.ink
    image.contentMode = .scaleAspectFit
    image.widthAnchor.constraint(equalToConstant: 26).isActive = true
    image.heightAnchor.constraint(equalToConstant: 26).isActive = true
    row.addArrangedSubview(image)
    let titleLabel = coastLabel(title, size: 15, weight: .semibold)
    titleLabel.widthAnchor.constraint(equalToConstant: env.chinese ? 76 : 108).isActive = true
    row.addArrangedSubview(titleLabel)
    row.addArrangedSubview(coastLabel(detail, size: 12, color: CoastStyle.muted))
    row.heightAnchor.constraint(equalToConstant: 38).isActive = true
    return row
  }

  private func agreementText() -> NSAttributedString {
    let text = env.t(
      "I have read and agree to the Terms of Use and Privacy Policy",
      "我已阅读并同意《用户协议》和《隐私政策》")
    let value = NSMutableAttributedString(
      string: text,
      attributes: [.font: CoastStyle.font(13), .foregroundColor: CoastStyle.muted])
    let terms = env.t("Terms of Use", "《用户协议》")
    let privacy = env.t("Privacy Policy", "《隐私政策》")
    value.addAttribute(.link, value: "coastwild://terms", range: (text as NSString).range(of: terms))
    value.addAttribute(.link, value: "coastwild://privacy", range: (text as NSString).range(of: privacy))
    return value
  }

  private func toggleAgreement() {
    checked.toggle()
    validation.isHidden = true
    updateCheckbox()
  }

  private func updateCheckbox() {
    checkbox.setImage(UIImage(systemName: checked ? "checkmark.circle.fill" : "circle"), for: .normal)
    checkbox.accessibilityValue = checked ? env.t("Selected", "已选中") : env.t("Not selected", "未选中")
  }

  func textView(
    _ textView: UITextView, primaryActionFor textItem: UITextItem,
    defaultAction: UIAction
  ) -> UIAction? {
    guard case .link(let url) = textItem.content else { return defaultAction }
    return UIAction { [weak self] _ in
      self?.showPolicy(url.host == "terms" ? .terms : .privacy)
    }
  }

  private func showPolicy(_ kind: LegalDocument) {
    let detail = LegalWebController(env, document: kind)
    let nav = env.navigation(detail)
    nav.modalPresentationStyle = .fullScreen
    present(nav, animated: true)
  }

  private func showDeclineSheet() {
    let sheet = PrivacyDeclineController(env)
    sheet.onPrivacy = { [weak self] in self?.showPolicy(.privacy) }
    sheet.onAccept = { [weak self] in
      self?.checked = true
      self?.updateCheckbox()
      self?.env.acceptPrivacy()
    }
    sheet.modalPresentationStyle = .pageSheet
    if let presentation = sheet.sheetPresentationController {
      presentation.detents = [.medium()]
      presentation.prefersGrabberVisible = true
      presentation.preferredCornerRadius = 28
    }
    present(sheet, animated: true)
  }
}

final class PrivacyDeclineController: UIViewController {
  private let env: CoastEnvironment
  var onPrivacy: (() -> Void)?
  var onAccept: (() -> Void)?

  init(_ env: CoastEnvironment) {
    self.env = env
    super.init(nibName: nil, bundle: nil)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) unsupported") }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = UIColor(hex: 0xF7F3EA)
    let stack = UIStackView()
    stack.axis = .vertical
    stack.alignment = .fill
    stack.spacing = 14
    stack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(stack)
    let symbol = UIImageView(image: UIImage(systemName: "exclamationmark.shield"))
    symbol.tintColor = UIColor(hex: 0xD9785D)
    symbol.contentMode = .scaleAspectFit
    symbol.heightAnchor.constraint(equalToConstant: 48).isActive = true
    stack.addArrangedSubview(symbol)
    let title = coastLabel(env.t("Continue without agreeing?", "暂不同意隐私协议？"), size: 22, weight: .bold)
    title.textAlignment = .center
    stack.addArrangedSubview(title)
    let body = coastLabel(
      env.t("Agreement is required to sign in and use trips, learning, gear and journals. You can read the full policy before deciding.", "同意后才能登录并使用行程、学习、装备和记录功能。你可以先查看完整协议，再决定是否继续。"),
      size: 14, color: CoastStyle.muted)
    body.textAlignment = .center
    stack.addArrangedSubview(body)
    stack.setCustomSpacing(24, after: body)
    let policy = coastButton(env.t("View Privacy Policy", "查看隐私政策")) { [weak self] in
      guard let self else { return }
      dismiss(animated: true) { self.onPrivacy?() }
    }
    policy.accessibilityIdentifier = "privacy.sheet.policy"
    policy.configuration?.baseBackgroundColor = UIColor(hex: 0x2F5D50)
    stack.addArrangedSubview(policy)
    let accept = coastButton(env.t("Return and agree", "返回并同意"), secondary: true) { [weak self] in
      guard let self else { return }
      dismiss(animated: true) { self.onAccept?() }
    }
    accept.accessibilityIdentifier = "privacy.sheet.accept"
    stack.addArrangedSubview(accept)
    let exit = UIButton(type: .system)
    exit.setTitle(env.t("Exit app", "退出应用"), for: .normal)
    exit.setTitleColor(UIColor(hex: 0xD9785D), for: .normal)
    exit.titleLabel?.font = CoastStyle.font(15, .semibold)
    exit.heightAnchor.constraint(equalToConstant: 44).isActive = true
    exit.accessibilityIdentifier = "privacy.sheet.exit"
    exit.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .touchUpInside)
    stack.addArrangedSubview(exit)
    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 28),
      stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
      stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
      stack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -18),
    ])
  }
}

