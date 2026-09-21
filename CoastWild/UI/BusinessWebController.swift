import UIKit
import WebKit

final class BusinessWebController: UIViewController, WKNavigationDelegate, WKUIDelegate {
  private let initialURL: URL
  private let bootstrap: BusinessWebBootstrap
  private let policy: BusinessWebNavigationPolicy
  private let appIconDataURL: String
  private var webView: WKWebView?
  private var progressObservation: NSKeyValueObservation?
  private let progress = UIProgressView(progressViewStyle: .bar)
  private let percent = UILabel()
  private let retry = UIButton(type: .system)
  private var configured = false

  init(url: URL, bootstrap: BusinessWebBootstrap, allowedHosts: Set<String>, appIconDataURL: String) {
    initialURL = url
    self.bootstrap = bootstrap
    policy = BusinessWebNavigationPolicy(allowedHosts: allowedHosts)
    self.appIconDataURL = appIconDataURL
    super.init(nibName: nil, bundle: nil)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) unsupported") }

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
    let next = WKWebView(frame: .zero, configuration: configuration)
    next.navigationDelegate = self; next.uiDelegate = self
    next.allowsLinkPreview = false; next.allowsBackForwardNavigationGestures = false
    next.isOpaque = false; next.backgroundColor = .clear; next.layer.shouldRasterize = false
    next.scrollView.bounces = false; next.scrollView.isScrollEnabled = false
    next.scrollView.contentInsetAdjustmentBehavior = .never
    next.scrollView.delaysContentTouches = false; next.scrollView.keyboardDismissMode = .none
    next.accessibilityIdentifier = "business-web.main"; next.translatesAutoresizingMaskIntoConstraints = false
    view.insertSubview(next, at: 0)
    NSLayoutConstraint.activate([
      next.topAnchor.constraint(equalTo: view.topAnchor), next.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      next.leadingAnchor.constraint(equalTo: view.leadingAnchor), next.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    ])
    webView = next
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
