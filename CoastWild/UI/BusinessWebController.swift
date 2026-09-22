import UIKit
import WebKit
import SafariServices
import StoreKit

final class BusinessWebController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, BridgeMessageHandling {
  private let initialURL: URL
  private let bootstrap: BusinessWebBootstrap
  private let policy: BusinessWebNavigationPolicy
  private let allowedHosts: Set<String>
  private let appIconDataURL: String
  private let iapBridgeHandler: (any IAPBridgeHandling)?
  private let onApplicationAction: ((BusinessBridgeAction) -> Void)?
  private let onBridgeMessage: (BridgeMessage) -> Void
  private var webView: WKWebView?
  private var progressObservation: NSKeyValueObservation?
  private var localActionState = BusinessWebLocalActionState()
  private var launchCover: UIView?
  private let progress = UIProgressView(progressViewStyle: .bar)
  private let percent = UILabel()
  private let retry = UIButton(type: .system)
  private var configured = false
  private var keyboardTokens: [NSObjectProtocol] = []
  private lazy var router = BridgeRouter(allowedHosts: allowedHosts, handler: self)
  private lazy var edgePanRecognizer = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleEdgePan(_:)))
  private lazy var eventEmitter = BridgeEventEmitter(
    resumedName: UIApplication.didBecomeActiveNotification,
    pausedName: UIApplication.didEnterBackgroundNotification,
    evaluate: { [weak self] in self?.evaluate($0) }
  )

  init(url: URL, bootstrap: BusinessWebBootstrap, allowedHosts: Set<String>, appIconDataURL: String,
       iapBridgeHandler: (any IAPBridgeHandling)? = nil,
       onApplicationAction: ((BusinessBridgeAction) -> Void)? = nil,
       onBridgeMessage: @escaping (BridgeMessage) -> Void) {
    initialURL = url
    self.bootstrap = bootstrap
    self.allowedHosts = allowedHosts
    policy = BusinessWebNavigationPolicy(allowedHosts: allowedHosts)
    self.appIconDataURL = appIconDataURL
    self.iapBridgeHandler = iapBridgeHandler
    self.onApplicationAction = onApplicationAction
    self.onBridgeMessage = onBridgeMessage
    super.init(nibName: nil, bundle: nil)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) unsupported") }
  deinit {
    keyboardTokens.forEach(NotificationCenter.default.removeObserver)
    webView?.configuration.userContentController.removeAllScriptMessageHandlers()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.setNavigationBarHidden(true, animated: animated)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black
    progress.trackTintColor = UIColor.white.withAlphaComponent(0.2)
    progress.progressTintColor = UIColor(hex: 0xFF765F)
    progress.translatesAutoresizingMaskIntoConstraints = false
    percent.font = CoastStyle.font(12, .semibold); percent.textColor = .white; percent.textAlignment = .center
    percent.translatesAutoresizingMaskIntoConstraints = false
    retry.setTitle("Retry", for: .normal); retry.backgroundColor = .white; retry.layer.cornerRadius = 12
    retry.accessibilityIdentifier = "business-web.retry"; retry.isHidden = true
    retry.addAction(UIAction { [weak self] _ in self?.reloadFromStart() }, for: .touchUpInside)
    retry.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(progress); view.addSubview(percent); view.addSubview(retry)
    NSLayoutConstraint.activate([
      progress.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
      progress.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
      progress.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -90),
      progress.heightAnchor.constraint(equalToConstant: 8),
      percent.centerXAnchor.constraint(equalTo: progress.centerXAnchor), percent.centerYAnchor.constraint(equalTo: progress.centerYAnchor),
      retry.centerXAnchor.constraint(equalTo: view.centerXAnchor), retry.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      retry.widthAnchor.constraint(equalToConstant: 160), retry.heightAnchor.constraint(equalToConstant: 48),
    ])
    _ = eventEmitter
    observeKeyboard()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    guard !configured else { return }
    configured = true
    rebuildAndLoad()
  }

  private func rebuildAndLoad() {
    progressObservation = nil
    webView?.removeFromSuperview()
    localActionState.beginLoading()
    installLaunchCover()
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = .default()
    configuration.allowsInlineMediaPlayback = true
    configuration.mediaTypesRequiringUserActionForPlayback = []
    configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
    let insets = view.safeAreaInsets
    let script: String
    do {
      script = try bootstrap.javaScript(
        webLoadTimeMilliseconds: Int64(Date().timeIntervalSince1970 * 1_000),
        safeAreaInsets: .init(top: Int(insets.top), bottom: Int(insets.bottom), left: Int(insets.left), right: Int(insets.right)),
        appIconDataURL: appIconDataURL
      )
    } catch {
      showFailure(); return
    }
    configuration.userContentController.addUserScript(WKUserScript(
      source: script, injectionTime: .atDocumentStart, forMainFrameOnly: false))
    for topic in BridgeTopic.allCases {
      configuration.userContentController.add(BusinessWeakScriptMessageHandler(target: self), name: topic.rawValue)
    }
    let next = WKWebView(frame: .zero, configuration: configuration)
    next.navigationDelegate = self; next.uiDelegate = self
    next.allowsLinkPreview = false; next.allowsBackForwardNavigationGestures = false
    next.isOpaque = false; next.backgroundColor = .clear; next.layer.shouldRasterize = false
    next.scrollView.bounces = false; next.scrollView.isScrollEnabled = false
    next.scrollView.contentInsetAdjustmentBehavior = .never
    next.scrollView.delaysContentTouches = false; next.scrollView.keyboardDismissMode = .none
    next.accessibilityIdentifier = "business-web.main"; next.translatesAutoresizingMaskIntoConstraints = false
    next.addGestureRecognizer(edgePanRecognizer)
    view.insertSubview(next, at: 0)
    NSLayoutConstraint.activate([
      next.topAnchor.constraint(equalTo: view.topAnchor), next.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      next.leadingAnchor.constraint(equalTo: view.leadingAnchor), next.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    ])
    webView = next
    applyEdgePan(localActionState.edgePan)
    progress.progress = 0.05; percent.text = "5%"; progress.isHidden = false; percent.isHidden = false; retry.isHidden = true
    progressObservation = next.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
      DispatchQueue.main.async { self?.updateProgress(webView.estimatedProgress) }
    }
    next.load(URLRequest(url: initialURL, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 20))
  }

  private func updateProgress(_ value: Double) {
    let adjusted = max(0.05, Float(value - 0.01))
    guard adjusted > progress.progress else { return }
    progress.setProgress(adjusted, animated: true); percent.text = "\(Int(adjusted * 100))%"
  }
  private func reloadFromStart() { rebuildAndLoad() }
  private func showFailure() { progress.isHidden = true; percent.isHidden = true; retry.isHidden = false }
  private func evaluate(_ script: String) { webView?.evaluateJavaScript(script) }

  private func installLaunchCover() {
    launchCover?.removeFromSuperview()
    let cover = UIView()
    cover.backgroundColor = .black
    cover.translatesAutoresizingMaskIntoConstraints = false
    view.insertSubview(cover, belowSubview: progress)
    NSLayoutConstraint.activate([
      cover.topAnchor.constraint(equalTo: view.topAnchor), cover.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      cover.leadingAnchor.constraint(equalTo: view.leadingAnchor), cover.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    ])
    launchCover = cover
  }

  private func revealBusinessWeb() {
    guard localActionState.reveal() else { return }
    progress.setProgress(1, animated: true); percent.text = "100%"
    guard let cover = launchCover else {
      progress.isHidden = true; percent.isHidden = true
      return
    }
    UIView.animate(withDuration: 0.2, animations: {
      cover.alpha = 0
    }, completion: { [weak self, weak cover] _ in
      guard let self, let cover else { return }
      cover.removeFromSuperview()
      guard launchCover === cover else { return }
      launchCover = nil
      progress.isHidden = true; percent.isHidden = true
    })
  }

  private func applyEdgePan(_ payload: EdgePanPayload) {
    localActionState.setEdgePan(payload)
    edgePanRecognizer.edges = payload.isLeftEdge ? .left : .right
    edgePanRecognizer.isEnabled = payload.isEnabled
  }

  @objc private func handleEdgePan(_ recognizer: UIScreenEdgePanGestureRecognizer) {
    guard recognizer.state == .ended, let webView, webView.canGoBack else { return }
    webView.goBack()
  }

  private func observeKeyboard() {
    let center = NotificationCenter.default
    keyboardTokens = [
      center.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main) { [weak self] note in
        guard let self, let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let local = view.convert(frame, from: nil); let height = max(0, view.bounds.maxY - local.minY)
        let duration = (note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0
        eventEmitter.emitKeyboard(height: height, duration: duration)
      },
      center.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { [weak self] _ in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self?.eventEmitter.emitKeyboard(height: 0, duration: 0) }
      },
    ]
  }

  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    try? router.route(name: message.name, body: message.body, sourceURL: message.frameInfo.request.url, isMainFrame: message.frameInfo.isMainFrame)
  }

  func handle(_ message: BridgeMessage) {
    switch message {
    case let .openInternalWeb(payload):
      guard policy.decision(for: payload.url) == .allow else { return }
      let controller = InternalWebController(
        url: payload.url, title: payload.title, showsNavigationBar: payload.showsNavigationBar,
        allowedHosts: allowedHosts, onVisibilityChange: { [weak self] in self?.evaluate($0) })
      navigationController?.pushViewController(controller, animated: true)
    case .newTppClose: evaluate(JavaScriptCallbackEncoder.closeInternalWeb())
    case .openAppPurchase, .logPurchase, .onCreateOrder, .getProductPrice:
      guard let iapBridgeHandler else { onBridgeMessage(message); return }
      Task { [weak self] in
        guard let self, let commands = try? await iapBridgeHandler.handle(message) else { return }
        for command in commands {
          guard let script = try? command.javaScript() else { continue }
          evaluate(script)
        }
      }
    default:
      guard let action = BusinessBridgeActionPlanner.action(for: message) else { return }
      execute(action, originalMessage: message)
    }
  }

  private func execute(_ action: BusinessBridgeAction, originalMessage: BridgeMessage) {
    switch action {
    case .revealBusinessWeb:
      revealBusinessWeb()
    case .presentBrowser:
      guard let url = policy.validatedURL(for: action) else { return }
      present(SFSafariViewController(url: url), animated: true)
    case .openExternalLink:
      guard let url = policy.validatedURL(for: action), UIApplication.shared.canOpenURL(url) else { return }
      UIApplication.shared.open(url)
    case .openSettings:
      guard let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) else { return }
      UIApplication.shared.open(url)
    case .requestReview:
      guard let scene = view.window?.windowScene else { return }
      SKStoreReviewController.requestReview(in: scene)
    case let .setEdgePan(payload):
      applyEdgePan(payload)
    case let .callback(callback):
      switch callback {
      case .closeInternalWeb: evaluate(JavaScriptCallbackEncoder.closeInternalWeb())
      case .openVIPService: evaluate(JavaScriptCallbackEncoder.openVIPService())
      case .recharge: evaluate(JavaScriptCallbackEncoder.recharge())
      }
    case .openInternalWeb:
      break
    case .backgroundLogin, .logout, .setLanguage, .refreshEntitlements, .nativeLog:
      if let onApplicationAction {
        onApplicationAction(action)
      } else {
        onBridgeMessage(originalMessage)
      }
    }
  }

  func sendBackgroundLoginSuccess(_ value: JSONValue) throws { evaluate(try JavaScriptCallbackEncoder.backgroundLoginSuccess(value)) }
  func sendIAPLog(_ value: JSONValue) throws { evaluate(try JavaScriptCallbackEncoder.iapLog(value)) }
  func sendProductPrices(_ value: JSONValue) throws { evaluate(try JavaScriptCallbackEncoder.productPriceResult(value)) }
  func sendOpenVIPService() { evaluate(JavaScriptCallbackEncoder.openVIPService()) }
  func sendRecharge() { evaluate(JavaScriptCallbackEncoder.recharge()) }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    progress.setProgress(1, animated: true); percent.text = "100%"
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in self?.progress.isHidden = true; self?.percent.isHidden = true }
  }
  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { showFailure() }
  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { showFailure() }
  func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { rebuildAndLoad() }

  func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
               decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    switch policy.decision(for: navigationAction.request.url) {
    case .allow: decisionHandler(.allow)
    case let .openExternal(url):
      if UIApplication.shared.canOpenURL(url) { UIApplication.shared.open(url) }
      decisionHandler(.cancel)
    case .deny: decisionHandler(.cancel)
    }
  }
  func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
               initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
               decisionHandler: @escaping (WKPermissionDecision) -> Void) { decisionHandler(.prompt) }
}

private final class BusinessWeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
  weak var target: WKScriptMessageHandler?
  init(target: WKScriptMessageHandler) { self.target = target }
  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    target?.userContentController(userContentController, didReceive: message)
  }
}
