import UIKit

/// Restores the stored session before a login form is ever presented.
final class StartupController: UIViewController {
  private let env: CoastEnvironment
  private let activity = UIActivityIndicatorView(style: .large)
  private let status = UILabel()
  private let retry = UIButton(type: .system)
  private var recoveryTask: Task<Void, Never>?
  private var started = false

  init(_ env: CoastEnvironment) {
    self.env = env
    super.init(nibName: nil, bundle: nil)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = UIColor(hex: 0xF6F0E3)
    let mark = UIImageView(image: UIImage(named: "LaunchMark")?.withRenderingMode(.alwaysTemplate))
    mark.tintColor = CoastStyle.brand
    mark.contentMode = .scaleAspectFit
    mark.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(mark)
    NSLayoutConstraint.activate([
      mark.widthAnchor.constraint(equalToConstant: 200),
      mark.heightAnchor.constraint(equalToConstant: 200),
      mark.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      mark.centerYAnchor.constraint(equalTo: view.centerYAnchor)
    ])
    view.accessibilityIdentifier = "startup.recovery"
    status.textAlignment = .center
    status.numberOfLines = 0
    status.font = .systemFont(ofSize: 15)
    retry.setTitle(env.t("Try again", "重试"), for: .normal)
    retry.accessibilityIdentifier = "startup.retry"
    retry.addAction(UIAction { [weak self] _ in self?.recover() }, for: .touchUpInside)
    let stack = UIStackView(arrangedSubviews: [activity, status, retry])
    stack.axis = .vertical; stack.spacing = 20; stack.alignment = .center
    stack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -36),
      stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
      stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
    ])
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard !started else { return }
    started = true
    recover()
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    recoveryTask?.cancel()
  }

  private func recover() {
    guard recoveryTask == nil else { return }
    activity.startAnimating(); retry.isHidden = true
    status.text = env.t("Loading…", "加载中…")
    recoveryTask = Task { [weak self] in
      guard let self else { return }
      defer { recoveryTask = nil }
      let args = ProcessInfo.processInfo.arguments
      let state: RemoteLoginState
      if args.contains("--ui-testing") && args.contains("--ui-testing-manual-login") {
        state = .idle
      } else if args.contains("--ui-testing") && args.contains("--seed-account") {
        state = await env.remoteSessionCoordinator.manualLogin(riskInfo: nil)
      } else {
        state = await env.remoteSessionCoordinator.automaticLogin()
      }
      guard !Task.isCancelled, env.window?.rootViewController === self else { return }
      switch StartupRoute(state: state) {
      case .login:
        env.window?.rootViewController = env.navigation(RemoteLoginController(env))
      case .business:
        guard case let .authenticated(session, strategy) = state else { return }
        do { try await env.remoteAuthenticated(session: session, strategy: strategy) }
        catch { showFailure() }
      case .retry, .loading:
        showFailure()
      }
    }
  }

  private func showFailure() {
    activity.stopAnimating()
    status.text = env.t("Unable to connect. Please check your network and try again.", "暂时无法连接，请检查网络后重试。")
    retry.isHidden = false
  }
}

final class RemoteLoginController: CoastController {
  private let connectivity = ConnectivityMonitor()
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
      await handle(state)
    }
  }

  private func handle(_ state: RemoteLoginState) async {
    let presentation = RemoteLoginPresentation(state: state, isConnected: connectivity.isConnected)
    render(presentation)
    if case let .authenticated(session, strategy) = state {
      do { try await env.remoteAuthenticated(session: session, strategy: strategy) }
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
