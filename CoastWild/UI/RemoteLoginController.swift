import UIKit

final class RemoteLoginController: CoastController {
  private let connectivity = ConnectivityMonitor()
  private var attemptedAutomaticLogin = false
  private var submit: UIButton!
  private let status = coastLabel("", size: 14, color: CoastStyle.red)
  private let activity = UIActivityIndicatorView(style: .medium)
  private weak var offlineAlert: UIAlertController?

  override func viewDidLoad() {
    super.viewDidLoad()
    build()
    connectivity.onChange = { [weak self] connected in
      if connected { self?.offlineAlert?.dismiss(animated: true) }
    }
    connectivity.start()
  }

  deinit { connectivity.cancel() }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard !attemptedAutomaticLogin else { return }
    attemptedAutomaticLogin = true
    if ProcessInfo.processInfo.arguments.contains("--ui-testing-manual-login") { return }
    performLogin(automatic: true)
  }

  private func build() {
    contentTop.constant = 28
    stack.spacing = 18
    let image = coastImage("surf-coast", height: 190)
    image.layer.cornerRadius = 16
    add(image)
    heading(env.t("Welcome to Coast & Wild", "欢迎来到海岸与山野"))
    add(coastLabel(
      env.t("Continue securely with this device. No email or password is required.", "使用当前设备安全登录，无需邮箱或密码。"),
      size: 15,
      color: CoastStyle.muted
    ))
    status.accessibilityIdentifier = "auth.remote.status"
    status.isHidden = true
    add(status)
    activity.hidesWhenStopped = true
    activity.accessibilityIdentifier = "auth.remote.loading"
    add(activity)
    submit = coastButton(env.t("Continue", "快捷登录")) { [weak self] in
      self?.performLogin(automatic: false)
    }
    submit.accessibilityIdentifier = "auth.remote.submit"
    add(submit)
    let legal = UIStackView(); legal.axis = .horizontal; legal.distribution = .fillEqually; legal.spacing = 10
    let terms = coastButton(env.t("Terms of Use", "用户协议"), secondary: true) { [weak self] in
      guard let self else { return }; self.push(LegalWebController(self.env, document: .terms))
    }
    terms.accessibilityIdentifier = "auth.terms"
    let privacy = coastButton(env.t("Privacy Policy", "隐私政策"), secondary: true) { [weak self] in
      guard let self else { return }; self.push(LegalWebController(self.env, document: .privacy))
    }
    privacy.accessibilityIdentifier = "auth.privacy"
    legal.addArrangedSubview(terms); legal.addArrangedSubview(privacy); add(legal)
  }

  private func performLogin(automatic: Bool) {
    render(.loading)
    Task { [weak self] in
      guard let self else { return }
      let state = automatic
        ? await env.remoteSessionCoordinator.automaticLogin()
        : await env.remoteSessionCoordinator.manualLogin(riskInfo: nil)
      handle(state)
    }
  }

  private func handle(_ state: RemoteLoginState) {
    let presentation = RemoteLoginPresentation(state: state, isConnected: connectivity.isConnected)
    render(presentation)
    if case let .authenticated(userID) = presentation {
      do { try env.remoteAuthenticated(userID: userID) }
      catch { render(.retryableFailure) }
    } else if presentation == .offline {
      showOfflineAlert()
    }
  }

  private func render(_ presentation: RemoteLoginPresentation) {
    switch presentation {
    case .loading:
      submit.isEnabled = false
      status.isHidden = true
      activity.startAnimating()
    case .retryableFailure:
      submit.isEnabled = true
      activity.stopAnimating()
      status.text = env.t("Login failed. Please try again.", "登录失败，请重试。")
      status.isHidden = false
    case .offline, .ready:
      submit.isEnabled = true
      activity.stopAnimating()
      status.isHidden = true
    case .authenticated:
      submit.isEnabled = false
      activity.stopAnimating()
      status.isHidden = true
    }
  }

  private func showOfflineAlert() {
    guard offlineAlert == nil else { return }
    let alert = UIAlertController(
      title: env.t("No Network Connection", "无网络连接"),
      message: env.t("Check your connection and try again.", "请检查网络连接后重试。"),
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: env.t("Cancel", "取消"), style: .cancel))
    alert.addAction(UIAlertAction(title: env.t("Open Settings", "打开设置"), style: .default) { _ in
      guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
      UIApplication.shared.open(url)
    })
    offlineAlert = alert
    present(alert, animated: true)
  }
}
