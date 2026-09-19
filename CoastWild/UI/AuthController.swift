import UIKit

final class WelcomeController: CoastController {
  override func viewDidLoad() {
    super.viewDidLoad()
    render()
  }
  func render() {
    reset()
    heading("Coast & Wild")
    note(env.t("From the coast, into the wild.", "从海岸，到山野。"))
    add(coastImage("onboarding", height: 330))
    add(
      coastButton(env.t("Language: English", "语言：简体中文"), secondary: true) { [weak self] in
        guard let self else { return }
        var p = self.env.store.preferences
        p.language = self.env.chinese ? "en" : "zh-Hans"
        if self.save({ try self.env.store.updatePreferences(p) }) { self.render() }
      })
    add(
      coastButton(env.t("Region: ", "内容地区：") + env.store.preferences.region, secondary: true) {
        [weak self] in
        guard let self else { return }
        var p = self.env.store.preferences
        p.region = p.region == "CN" ? "US" : "CN"
        if self.save({ try self.env.store.updatePreferences(p) }) { self.render() }
      })
    add(coastLabel(env.t("What calls you outside?", "你想探索什么？"), size: 20, weight: .semibold))
    note(env.t("Surf culture · coastal walks · camping", "冲浪文化 · 海岸徒步 · 露营"))
    let login = coastButton(env.t("Log in", "登录")) { [weak self] in
      guard let self else { return }
      self.push(AuthController(self.env, mode: .login))
    }
    login.accessibilityIdentifier = "onboarding.login"
    add(login)
    add(
      coastButton(env.t("Create account", "注册账号"), secondary: true) { [weak self] in
        guard let self else { return }
        self.push(AuthController(self.env, mode: .register))
      })
    note(env.t("Log in to explore, plan and keep your stories.", "登录后即可探索内容、规划出游和记录手记。"))
  }
}
final class AuthController: CoastController {
  enum Mode { case login, register, recover, reset }
  let mode: Mode
  var demoCode: String?
  var email: UITextField!, password: UITextField!, name: UITextField!, confirmation: UITextField!,
    code: UITextField!
  var errorLabel = coastLabel("", size: 14, color: CoastStyle.red)
  init(_ env: CoastEnvironment, mode: Mode, demoCode: String? = nil) {
    self.mode = mode
    self.demoCode = demoCode
    super.init(env)
  }
  required init?(coder: NSCoder) { fatalError() }
  override func viewDidLoad() {
    super.viewDidLoad()
    build()
  }
  func build() {
    title = env.t("Local demo", "本地演示")
    if mode == .login || mode == .register { add(coastImage("surf-coast", height: 138)) }
    heading(
      mode == .login
        ? env.t("Welcome back.", "欢迎回来。")
        : mode == .register
          ? env.t("A place for your next adventure.", "为下一次出发，留个位置。")
          : mode == .recover
            ? env.t("Forgot your password?", "忘记密码？") : env.t("Set a new password.", "设置新密码。"))
    if mode == .login { note(env.t("Your next story starts outside.", "下一段故事，从户外开始。")) }
    if let demoCode {
      note(env.t("Local demo code (10 minutes): ", "本地演示验证码（10 分钟有效）：") + demoCode)
    }
    if mode == .register {
      name = field(
        env.t("Name", "昵称"), placeholder: env.t("What should we call you?", "怎么称呼你？"),
        id: "auth.name")
      name.textContentType = .nickname
    }
    if mode != .reset {
      email = field(env.t("Email", "邮箱"), placeholder: "you@example.com", id: "auth.email")
      email.keyboardType = .emailAddress
      email.textContentType = .username
    }
    if mode == .reset {
      code = field(env.t("Recovery code", "验证码"), placeholder: env.t("6-digit code", "6 位验证码"))
      code.keyboardType = .numberPad
      code.textContentType = .oneTimeCode
    }
    if mode != .recover {
      password = field(
        env.t("Password", "密码"), placeholder: env.t("At least 10 characters", "至少 10 个字符"),
        secure: true, id: "auth.password")
      password.textContentType = .password
      let toggle = UIButton(type: .system)
      toggle.setTitle(env.t("Show", "显示"), for: .normal)
      toggle.frame = CGRect(x: 0, y: 0, width: 60, height: 44)
      toggle.addAction(
        UIAction { [weak self] _ in
          guard let self else { return }
          self.password.isSecureTextEntry.toggle()
          toggle.setTitle(
            self.password.isSecureTextEntry ? self.env.t("Show", "显示") : self.env.t("Hide", "隐藏"),
            for: .normal)
        }, for: .touchUpInside)
      password.rightView = toggle
      password.rightViewMode = .always
    }
    if mode == .register || mode == .reset {
      confirmation = field(env.t("Confirm password", "确认密码"), secure: true, id: "auth.confirmation")
      confirmation.textContentType = .password
    }
    errorLabel.accessibilityIdentifier = "auth.error"
    errorLabel.isHidden = true
    add(errorLabel)
    if mode == .login {
      add(
        coastButton(env.t("Forgot password?", "忘记密码？"), secondary: true) { [weak self] in
          guard let self else { return }
          self.push(AuthController(self.env, mode: .recover))
        })
    }
    let title =
      mode == .login
      ? env.t("Log in", "登录")
      : mode == .register
        ? env.t("Create account", "注册账号")
        : mode == .recover
          ? env.t("Get demo recovery code", "获取演示验证码") : env.t("Reset password", "重置密码")
    let submit = coastButton(title) { [weak self] in self?.submit() }
    submit.accessibilityIdentifier = "auth.submit"
    add(submit)
    if mode == .login || mode == .register {
      add(
        coastButton(
          mode == .login
            ? env.t("New here? Create account", "还没有账号？注册账号")
            : env.t("Already have an account? Log in", "已有账号？登录"), secondary: true
        ) { [weak self] in
          guard let self else { return }
          self.push(AuthController(self.env, mode: self.mode == .login ? .register : .login))
        })
    }
    note(
      env.t(
        "This account stays on this device. Use a test email and a unique demo password. No email is sent.",
        "账号仅保存在此设备。请使用测试邮箱和专用演示密码，不会发送真实邮件。"))
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
        let value = try env.vault.requestRecovery(email: email.text ?? "")
        push(AuthController(env, mode: .reset, demoCode: value))
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
