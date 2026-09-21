import UIKit
import WebKit

final class InternalWebController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {
  private let url: URL
  private let showsNavigationBar: Bool
  private let policy: BusinessWebNavigationPolicy
  private let onVisibilityChange: (String) -> Void
  private var webView: WKWebView!
  private var priorNavigationBarHidden = false

  init(url: URL, title: String?, showsNavigationBar: Bool, allowedHosts: Set<String>, onVisibilityChange: @escaping (String) -> Void) {
    self.url = url; self.showsNavigationBar = showsNavigationBar
    policy = BusinessWebNavigationPolicy(allowedHosts: allowedHosts)
    self.onVisibilityChange = onVisibilityChange
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = .default()
    super.init(nibName: nil, bundle: nil)
    self.title = title
    configuration.userContentController.add(WeakScriptMessageHandler(target: self), name: InternalWebContract.messageNames[0])
    webView = WKWebView(frame: .zero, configuration: configuration)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) unsupported") }

  deinit { webView.configuration.userContentController.removeScriptMessageHandler(forName: InternalWebContract.messageNames[0]) }
  override func viewDidLoad() {
    super.viewDidLoad(); view.backgroundColor = .systemBackground
    webView.navigationDelegate = self; webView.allowsBackForwardNavigationGestures = false
    webView.translatesAutoresizingMaskIntoConstraints = false; webView.accessibilityIdentifier = "business-web.internal"
    view.addSubview(webView)
    NSLayoutConstraint.activate([
      webView.topAnchor.constraint(equalTo: view.topAnchor), webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      webView.leadingAnchor.constraint(equalTo: view.leadingAnchor), webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    ])
    if let pop = navigationController?.interactivePopGestureRecognizer {
      webView.scrollView.panGestureRecognizer.require(toFail: pop)
    }
    webView.load(URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 20))
  }
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated); priorNavigationBarHidden = navigationController?.isNavigationBarHidden ?? false
    navigationController?.setNavigationBarHidden(!showsNavigationBar, animated: animated)
    onVisibilityChange(InternalWebContract.visibilityJavaScript(isVisible: true))
  }
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated); navigationController?.setNavigationBarHidden(priorNavigationBarHidden, animated: animated)
    onVisibilityChange(InternalWebContract.visibilityJavaScript(isVisible: false))
  }
  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    guard message.name == InternalWebContract.messageNames[0] else { return }
    navigationController?.popViewController(animated: true)
  }
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
  func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { webView.reloadFromOrigin() }
}

private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
  weak var target: WKScriptMessageHandler?
  init(target: WKScriptMessageHandler? = nil) { self.target = target }
  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    target?.userContentController(userContentController, didReceive: message)
  }
}
