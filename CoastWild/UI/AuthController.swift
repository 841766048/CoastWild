import UIKit

private final class WelcomeGradientView: UIView {
  override class var layerClass: AnyClass { CAGradientLayer.self }
  override init(frame: CGRect) {
    super.init(frame: frame)
    let gradient = layer as! CAGradientLayer
    gradient.colors = [UIColor.black.withAlphaComponent(0.48).cgColor, UIColor.clear.cgColor]
    gradient.locations = [0, 1]
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) unsupported") }
}

final class WelcomeController: CoastController {
  override func viewDidLoad() {
    super.viewDidLoad()
    scrollTop.isActive = false
    scrollTop = scroll.topAnchor.constraint(equalTo: view.topAnchor)
    scrollTop.isActive = true
    scroll.contentInsetAdjustmentBehavior = .never
    render()
  }
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    render()
  }
  func render() {
    reset()
    contentTop.constant = 0
    stack.spacing = 12
    let heroContainer = UIView()
    heroContainer.heightAnchor.constraint(equalToConstant: 372).isActive = true
    let hero = coastImage("onboarding", height: 372)
    hero.accessibilityIdentifier = "welcome.hero"
    hero.layer.cornerRadius = 0
    hero.translatesAutoresizingMaskIntoConstraints = false
    heroContainer.addSubview(hero)
    let overlay = WelcomeGradientView()
    overlay.translatesAutoresizingMaskIntoConstraints = false
    hero.addSubview(overlay)
    let title = coastLabel("Coast & Wild", size: 38, weight: .bold, color: .white)
    title.layer.shadowColor = UIColor.black.cgColor
    title.layer.shadowOpacity = 0.35
    title.layer.shadowRadius = 5
    title.layer.shadowOffset = CGSize(width: 0, height: 2)
    title.translatesAutoresizingMaskIntoConstraints = false
    hero.addSubview(title)
    let subtitle = coastLabel(
      env.t("From the shoreline to the trail.", "从海岸，到山野。"), size: 16,
      weight: .medium, color: .white)
    subtitle.layer.shadowColor = UIColor.black.cgColor
    subtitle.layer.shadowOpacity = 0.4
    subtitle.layer.shadowRadius = 4
    subtitle.layer.shadowOffset = CGSize(width: 0, height: 1)
    subtitle.translatesAutoresizingMaskIntoConstraints = false
    hero.addSubview(subtitle)
    add(heroContainer)
    NSLayoutConstraint.activate([
      hero.topAnchor.constraint(equalTo: heroContainer.topAnchor),
      hero.leadingAnchor.constraint(equalTo: heroContainer.leadingAnchor, constant: -20),
      hero.trailingAnchor.constraint(equalTo: heroContainer.trailingAnchor, constant: 20),
      overlay.topAnchor.constraint(equalTo: hero.topAnchor),
      overlay.leadingAnchor.constraint(equalTo: hero.leadingAnchor),
      overlay.trailingAnchor.constraint(equalTo: hero.trailingAnchor),
      overlay.heightAnchor.constraint(equalToConstant: 176),
      title.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 14),
      title.centerXAnchor.constraint(equalTo: hero.centerXAnchor),
      subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 1),
      subtitle.centerXAnchor.constraint(equalTo: hero.centerXAnchor),
    ])
    add(preferenceRow(icon: "globe", title: env.t("Language", "语言"), value: env.t("English", "简体中文")) { [weak self] in
      guard let self else { return }; self.push(PreferencesController(self.env))
    })
    add(preferenceRow(icon: "trips", title: env.t("Explore region", "探索地区"), value: env.store.preferences.region == "CN" ? env.t("Mainland China", "中国大陆") : env.t("United States", "美国")) { [weak self] in
      guard let self else { return }; self.push(PreferencesController(self.env))
    })
    let question = coastLabel(env.t("What are you most interested in?", "你最感兴趣的是什么？"), size: 16, weight: .bold)
    add(question)
    stack.setCustomSpacing(3, after: question)
    note(env.t("Choose as many as you like.", "可以选择多个方向。"))
    let interests = UIStackView()
    interests.axis = .horizontal; interests.spacing = 10; interests.distribution = .fillEqually
    for key in env.categoryKeys {
      let selected = (env.store.preferences.interests ?? env.categoryKeys).contains(key)
      let button = CoastActionButton(type: .custom)
      button.backgroundColor = selected ? UIColor(hex: 0xF8EFDE) : CoastStyle.field
      button.layer.cornerRadius = 12
      button.heightAnchor.constraint(equalToConstant: 89).isActive = true
      button.accessibilityLabel = env.category(key)
      button.accessibilityTraits = selected ? [.button, .selected] : [.button]
      let symbol = UIImageView(image: UIImage(named: "icon-" + (key == "surf" ? "wave" : key)))
      symbol.tintColor = CoastStyle.brand; symbol.contentMode = .scaleAspectFit
      let name = coastLabel(env.category(key), size: 14, weight: .bold)
      let check = coastLabel(selected ? "✓" : "", size: 13, color: .white)
      check.backgroundColor = selected ? CoastStyle.brand : .clear
      check.textAlignment = .center; check.layer.cornerRadius = 8; check.clipsToBounds = true
      for element in [symbol, name, check] { element.translatesAutoresizingMaskIntoConstraints = false; button.addSubview(element) }
      NSLayoutConstraint.activate([
        symbol.widthAnchor.constraint(equalToConstant: 30), symbol.heightAnchor.constraint(equalToConstant: 30),
        symbol.centerXAnchor.constraint(equalTo: button.centerXAnchor), symbol.topAnchor.constraint(equalTo: button.topAnchor, constant: 18),
        name.centerXAnchor.constraint(equalTo: button.centerXAnchor), name.topAnchor.constraint(equalTo: button.topAnchor, constant: 52),
        check.widthAnchor.constraint(equalToConstant: 16), check.heightAnchor.constraint(equalToConstant: 16),
        check.topAnchor.constraint(equalTo: button.topAnchor, constant: 7), check.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -12)
      ])
      button.addAction(UIAction { [weak self] _ in
        guard let self else { return }
        var prefs = self.env.store.preferences
        var values = prefs.interests ?? self.env.categoryKeys
        if values.contains(key) { values.removeAll { $0 == key } } else { values.append(key) }
        prefs.interests = values
        if self.save({ try self.env.store.updatePreferences(prefs) }) { self.render() }
      }, for: .touchUpInside)
      interests.addArrangedSubview(button)
    }
    add(interests); stack.setCustomSpacing(16, after: interests)
    let actions = UIStackView(); actions.axis = .horizontal; actions.spacing = 10; actions.distribution = .fillEqually
    for mode: AuthController.Mode in [.login, .register] {
      let button = coastButton(mode == .login ? env.t("Sign in", "登录") : env.t("Create account", "注册账号"), secondary: mode == .register) { [weak self] in
        guard let self else { return }; self.push(AuthController(self.env, mode: mode))
      }
      button.constraints.filter { $0.firstAttribute == .height }.forEach { $0.isActive = false }
      button.heightAnchor.constraint(greaterThanOrEqualToConstant: 42).isActive = true
      button.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
      button.configuration?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
        var a = incoming; a.font = CoastStyle.font(14, .semibold); return a
      }
      if mode == .login { button.accessibilityIdentifier = "onboarding.login" }
      actions.addArrangedSubview(button)
    }
    add(actions); stack.setCustomSpacing(16, after: actions)
    let footnote = coastLabel(env.t("Sign in to explore, plan trips and keep your journal.", "登录后即可探索内容、规划出游和记录手记。"), size: 11, color: CoastStyle.muted)
    footnote.textAlignment = .center; add(footnote)
  }
  private func preferenceRow(icon: String, title: String, value: String, action: @escaping () -> Void) -> UIButton {
    let button = UIButton(type: .system)
    button.layer.cornerRadius = 10; button.layer.borderWidth = 1; button.layer.borderColor = CoastStyle.border.cgColor
    button.heightAnchor.constraint(equalToConstant: 40).isActive = true
    let row = UIStackView(); row.axis = .horizontal; row.spacing = 10; row.alignment = .center
    row.isUserInteractionEnabled = false; row.translatesAutoresizingMaskIntoConstraints = false
    let image = UIImageView(image: UIImage(named: "icon-" + icon)); image.contentMode = .scaleAspectFit
    image.widthAnchor.constraint(equalToConstant: 22).isActive = true
    image.heightAnchor.constraint(equalToConstant: 22).isActive = true
    row.addArrangedSubview(image); row.addArrangedSubview(coastLabel(title, size: 13)); row.addArrangedSubview(UIView())
    row.addArrangedSubview(coastLabel(value, size: 12, color: CoastStyle.muted))
    let chevron = UIImageView(image: UIImage(named: "icon-down")); chevron.tintColor = CoastStyle.muted; chevron.contentMode = .scaleAspectFit
    chevron.widthAnchor.constraint(equalToConstant: 16).isActive = true; chevron.heightAnchor.constraint(equalToConstant: 16).isActive = true
    row.addArrangedSubview(chevron)
    button.addSubview(row)
    NSLayoutConstraint.activate([row.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 12), row.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -12), row.centerYAnchor.constraint(equalTo: button.centerYAnchor)])
    button.accessibilityLabel = title + ": " + value
    button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    return button
  }
}
final class AuthController: CoastController {
  enum Mode { case login, register, recover, reset }
  let mode: Mode
  var recoveryCode: String?
  let recoveryEmail: String?
  var email: UITextField!, password: UITextField!, name: UITextField!, confirmation: UITextField!,
    code: UITextField!
  var errorLabel = coastLabel("", size: 14, color: CoastStyle.red)
  init(_ env: CoastEnvironment, mode: Mode, recoveryCode: String? = nil, recoveryEmail: String? = nil) {
    self.mode = mode
    self.recoveryCode = recoveryCode
    self.recoveryEmail = recoveryEmail
    super.init(env)
  }
  required init?(coder: NSCoder) { fatalError() }
  override func viewDidLoad() {
    super.viewDidLoad()
    build()
  }
  func build() {
    title = nil
    stack.spacing = 16
    contentTop.constant = 27
    if mode == .login || mode == .register {
      let photo = coastImage("surf-coast", height: 137); photo.layer.cornerRadius = 14; add(photo); stack.setCustomSpacing(23, after: photo)
    }
    let headline = coastLabel(mode == .login ? env.t("Welcome back.", "欢迎回来。") : mode == .register
      ? env.t("Make room for adventure.", "为下一次出发，留个位置。") : mode == .recover
      ? env.t("Forgot your password?", "忘记密码？") : env.t("A fresh start.", "设置新密码。"), size: 30, weight: .bold)
    add(headline); stack.setCustomSpacing(12, after: headline)
    if mode == .login || mode == .recover || mode == .reset {
      let subtitle = coastLabel(mode == .login ? env.t("Your next chapter starts outside.", "下一段故事，从户外开始。") : mode == .recover
        ? env.t("Enter the email you used to sign up on this device.", "输入你在此设备注册时使用的邮箱。")
        : env.t("Reset the password for", "为以下账号重置密码"), size: 15, color: CoastStyle.muted)
      add(subtitle)
      if mode == .reset, let recoveryEmail {
        let account = coastLabel(recoveryEmail, size: 15, weight: .semibold)
        account.accessibilityIdentifier = "auth.recovery.email"; add(account); stack.setCustomSpacing(23, after: account)
      } else { stack.setCustomSpacing(23, after: subtitle) }
    }
    if let recoveryCode {
      let panel = UIStackView(); panel.axis = .vertical; panel.spacing = 8
      panel.isLayoutMarginsRelativeArrangement = true; panel.layoutMargins = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
      panel.backgroundColor = UIColor(hex: 0xF8EFDE); panel.layer.cornerRadius = 12
      panel.addArrangedSubview(coastLabel(env.t("Recovery code · No email sent", "验证码 · 未发送邮件"), size: 12, color: CoastStyle.muted))
      panel.addArrangedSubview(coastLabel(recoveryCode, size: 27, weight: .bold))
      panel.addArrangedSubview(coastLabel(env.t("Valid for 10 minutes.", "10 分钟内有效。"), size: 11, color: CoastStyle.muted)); add(panel)
    }
    if mode == .register {
      name = field(env.t("Name", "昵称"), placeholder: env.t("What should we call you?", "怎么称呼你？"), id: "auth.name")
      name.textContentType = .nickname
    }
    if mode != .reset {
      email = field(env.t("Email", "邮箱"), placeholder: "you@example.com", id: "auth.email")
      email.keyboardType = .emailAddress; email.textContentType = .username
    }
    if mode == .reset {
      code = field(env.t("Verification code", "验证码"), placeholder: env.t("6-digit code", "6 位验证码"))
      code.keyboardType = .numberPad; code.textContentType = .oneTimeCode
    }
    if mode != .recover {
      password = field(mode == .reset ? env.t("New password", "新密码") : env.t("Password", "密码"), placeholder: mode == .login ? env.t("Your password", "输入密码") : env.t("At least 10 characters", "至少 10 个字符"), secure: true, id: "auth.password")
      password.textContentType = .password
      let toggle = UIButton(type: .system)
      toggle.setTitle(env.t("Show", "显示"), for: .normal); toggle.titleLabel?.font = CoastStyle.font(12)
      toggle.frame = CGRect(x: 0, y: 0, width: 48, height: 44)
      toggle.addAction(UIAction { [weak self] _ in
        guard let self else { return }; self.password.isSecureTextEntry.toggle()
        toggle.setTitle(self.password.isSecureTextEntry ? self.env.t("Show", "显示") : self.env.t("Hide", "隐藏"), for: .normal)
      }, for: .touchUpInside)
      password.rightView = toggle; password.rightViewMode = .always
    }
    if mode == .register || mode == .reset {
      confirmation = field(env.t("Confirm password", "确认密码"), placeholder: env.t("Enter it again", "再次输入密码"), secure: true, id: "auth.confirmation")
      confirmation.textContentType = .password
    }
    errorLabel.accessibilityIdentifier = "auth.error"; errorLabel.isHidden = true; add(errorLabel)
    if mode == .login {
      stack.setCustomSpacing(4, after: password)
      let forgot = textLink(env.t("Forgot password?", "忘记密码？"), size: 13) { [weak self] in
        guard let self else { return }; self.push(AuthController(self.env, mode: .recover))
      }
      forgot.contentHorizontalAlignment = .right; add(forgot); stack.setCustomSpacing(12, after: forgot)
    }
    let label = mode == .login ? env.t("Sign in", "登录") : mode == .register ? env.t("Create account", "注册账号")
      : mode == .recover ? env.t("Get a reset code", "获取重置验证码") : env.t("Reset password", "重置密码")
    let submit = coastButton(label) { [weak self] in self?.submit() }
    submit.accessibilityIdentifier = "auth.submit"; add(submit); stack.setCustomSpacing(13, after: submit)
    if mode == .login || mode == .register {
      let row = UIStackView(); row.axis = .horizontal; row.alignment = .center; row.spacing = 4
      row.addArrangedSubview(UIView())
      row.addArrangedSubview(coastLabel(mode == .login ? env.t("New to Coast & Wild?", "还没有账号？") : env.t("Already have an account?", "已有账号？"), size: 14))
      row.addArrangedSubview(textLink(mode == .login ? env.t("Create an account", "注册账号") : env.t("Sign in", "登录"), size: 14, weight: .semibold) { [weak self] in
        guard let self else { return }; self.push(AuthController(self.env, mode: self.mode == .login ? .register : .login))
      })
      let spacer = UIView(); row.addArrangedSubview(spacer)
      spacer.widthAnchor.constraint(equalTo: row.arrangedSubviews[0].widthAnchor).isActive = true
      add(row); stack.setCustomSpacing(20, after: row)
    }
    if mode == .reset {
      add(textLink(env.t("Request another code", "重新获取验证码")) { [weak self] in
        guard let self else { return }; self.push(AuthController(self.env, mode: .recover))
      })
    }
    add(coastLabel(env.t("Your account stays on this device. Use a unique password, not one you use elsewhere. No email is sent.", "账号保存在此设备上。请使用专用密码，不要沿用其他服务的密码，不会发送邮件。"), size: 11, color: CoastStyle.muted))
  }
  private func textLink(_ title: String, size: CGFloat = 16, weight: UIFont.Weight = .regular, action: @escaping () -> Void) -> UIButton {
    let button = UIButton(type: .system); button.setTitle(title, for: .normal)
    button.titleLabel?.font = CoastStyle.font(size, weight); button.tintColor = CoastStyle.brand
    button.heightAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
    button.addAction(UIAction { _ in action() }, for: .touchUpInside); return button
  }
  func submit() {
    view.endEditing(true)
    do {
      if mode == .register || mode == .reset {
        guard password.text == confirmation.text else {
          errorLabel.text = env.t("Passwords do not match.", "两次输入的密码不一致。")
          errorLabel.isHidden = false
          return
        }
      }
      switch mode {
      case .login:
        try env.vault.login(email: email.text ?? "", password: password.text ?? "")
        try env.authenticated()
      case .register:
        try env.vault.register(
          name: name.text ?? "", email: email.text ?? "", password: password.text ?? "")
        try env.authenticated()
      case .recover:
        let recoveryEmail = (email.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let value = try env.vault.requestRecovery(email: recoveryEmail)
        push(AuthController(env, mode: .reset, recoveryCode: value, recoveryEmail: recoveryEmail))
      case .reset:
        try env.vault.reset(code: code.text ?? "", password: password.text ?? "")
        navigationController?.setViewControllers(
          [AuthController(env, mode: .login)], animated: true)
      }
    } catch {
      errorLabel.text = env.errorText(error)
      errorLabel.isHidden = false
    }
  }
}
