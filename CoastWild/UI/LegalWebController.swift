import SafariServices
import UIKit
import WebKit

final class LegalWebController: UIViewController, WKNavigationDelegate, WKUIDelegate {
  private let env: CoastEnvironment
  private let document: LegalDocument
  private let webView: WKWebView
  private let spinner = UIActivityIndicatorView(style: .medium)
  private let fallbackBanner = UILabel()
  private var remoteHost: String?
  private var attemptedRemote = false
  private var showingFallback = false

  init(_ env: CoastEnvironment, document: LegalDocument) {
    self.env = env
    self.document = document
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = .nonPersistent()
    configuration.defaultWebpagePreferences.allowsContentJavaScript = false
    webView = WKWebView(frame: .zero, configuration: configuration)
    super.init(nibName: nil, bundle: nil)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) unsupported") }

  override func viewDidLoad() {
    super.viewDidLoad()
    title = document.title(language: env.store.preferences.language)
    view.backgroundColor = UIColor(hex: 0xF7F3EA)
    navigationItem.rightBarButtonItem = UIBarButtonItem(
      title: env.t("Done", "完成"),
      primaryAction: UIAction { [weak self] _ in self?.close() })

    webView.navigationDelegate = self
    webView.uiDelegate = self
    webView.isOpaque = false
    webView.backgroundColor = UIColor(hex: 0xF7F3EA)
    webView.scrollView.backgroundColor = UIColor(hex: 0xF7F3EA)
    webView.accessibilityIdentifier = "legal.webview"
    webView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(webView)

    fallbackBanner.text = env.t(
      "You’re viewing the offline version.", "当前显示离线版本。")
    fallbackBanner.textAlignment = .center
    fallbackBanner.textColor = UIColor(hex: 0x73510D)
    fallbackBanner.backgroundColor = UIColor(hex: 0xFFF3CD)
    fallbackBanner.font = CoastStyle.font(12, .semibold)
    fallbackBanner.isHidden = true
    fallbackBanner.accessibilityIdentifier = "legal.offline"
    fallbackBanner.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(fallbackBanner)

    spinner.hidesWhenStopped = true
    spinner.color = CoastStyle.brand
    spinner.accessibilityLabel = env.t("Loading legal document", "正在加载协议")
    spinner.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(spinner)

    NSLayoutConstraint.activate([
      fallbackBanner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      fallbackBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      fallbackBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      fallbackBanner.heightAnchor.constraint(equalToConstant: 32),
      webView.topAnchor.constraint(equalTo: fallbackBanner.bottomAnchor),
      webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
    ])
    loadDocument()
  }

  private func close() {
    if presentingViewController != nil { dismiss(animated: true) }
    else { navigationController?.popViewController(animated: true) }
  }

  private func loadDocument() {
    spinner.startAnimating()
    Task { [weak self] in
      guard let self else { return }
      let snapshot = await env.integrationRuntime.snapshot()
      let remote = document == .privacy ? snapshot.privacyURL : snapshot.termsURL
      attemptedRemote = true
      remoteHost = remote.host?.lowercased()
      webView.load(URLRequest(url: remote, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 12))
    }
  }

  private func loadBundledDocument(showOfflineBanner: Bool) {
    guard !showingFallback else { return }
    showingFallback = true
    fallbackBanner.isHidden = !showOfflineBanner
    let path = document.localResource(language: env.store.preferences.language)
    let name = URL(fileURLWithPath: path).lastPathComponent
    let url = Bundle.main.url(forResource: name, withExtension: "html", subdirectory: "Legal")
      ?? Bundle.main.url(forResource: name, withExtension: "html")
    guard let url else {
      spinner.stopAnimating()
      showMissingDocument()
      return
    }
    webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
  }

  private func showMissingDocument() {
    let html = """
      <meta name="viewport" content="width=device-width,initial-scale=1">
      <body style="font:16px -apple-system;padding:32px;background:#f7f3ea;color:#17211d">
      \(env.t("This document is temporarily unavailable.", "协议内容暂时无法显示。"))
      </body>
      """
    webView.loadHTMLString(html, baseURL: nil)
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    spinner.stopAnimating()
  }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    fallbackAfterRemoteFailure()
  }

  func webView(
    _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
    withError error: Error
  ) {
    fallbackAfterRemoteFailure()
  }

  private func fallbackAfterRemoteFailure() {
    guard attemptedRemote && !showingFallback else { return }
    loadBundledDocument(showOfflineBanner: true)
  }

  func webView(
    _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
    preferences: WKWebpagePreferences
  ) async -> (WKNavigationActionPolicy, WKWebpagePreferences) {
    preferences.allowsContentJavaScript = false
    guard let url = navigationAction.request.url else { return (.cancel, preferences) }
    if url.isFileURL { return (.allow, preferences) }
    if url.scheme == "https", url.host?.lowercased() == remoteHost {
      return (.allow, preferences)
    }
    if navigationAction.navigationType == .linkActivated {
      await MainActor.run {
        if url.scheme == "https" { self.present(SFSafariViewController(url: url), animated: true) }
        else if UIApplication.shared.canOpenURL(url) { UIApplication.shared.open(url) }
      }
    }
    return (.cancel, preferences)
  }

  func webView(
    _ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
    initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
    decisionHandler: @escaping (WKPermissionDecision) -> Void
  ) {
    decisionHandler(.deny)
  }
}
