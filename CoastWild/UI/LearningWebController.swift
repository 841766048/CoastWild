import SafariServices
import SkeletonView
import UIKit
import WebKit

final class LearningWebController: UIViewController, WKNavigationDelegate {
  private let env: CoastEnvironment
  private let lessonID: String
  private let webView = WKWebView(frame: .zero)
  private let placeholder = UIView()
  private let skeleton = LearningSkeletonView(style: .webDetail)
  private var loadTask: Task<Void, Never>?

  init(_ env: CoastEnvironment, lessonID: String) {
    self.env = env
    self.lessonID = lessonID
    super.init(nibName: nil, bundle: nil)
  }
  required init?(coder: NSCoder) { fatalError() }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    let share = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), style: .plain, target: self, action: #selector(shareArticle))
    share.accessibilityIdentifier = "learn.share"
    share.accessibilityLabel = env.t("Share", "分享")
    navigationItem.rightBarButtonItems = [
      share,
      UIBarButtonItem(image: UIImage(systemName: env.store.ledger.bookmarks.contains(lessonID) ? "bookmark.fill" : "bookmark"), style: .plain, target: self, action: #selector(toggleBookmark)),
    ]
    webView.navigationDelegate = self
    webView.translatesAutoresizingMaskIntoConstraints = false
    placeholder.translatesAutoresizingMaskIntoConstraints = false
    skeleton.setLoadingAccessibility(
      identifier: "learn.web.loading",
      label: env.t("Loading article", "正在加载文章"))
    skeleton.translatesAutoresizingMaskIntoConstraints = false
    placeholder.addSubview(skeleton)
    view.addSubview(webView)
    view.addSubview(placeholder)
    NSLayoutConstraint.activate([
      webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      placeholder.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 18),
      placeholder.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      placeholder.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
      placeholder.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
      skeleton.topAnchor.constraint(equalTo: placeholder.topAnchor),
      skeleton.leadingAnchor.constraint(equalTo: placeholder.leadingAnchor),
      skeleton.trailingAnchor.constraint(equalTo: placeholder.trailingAnchor),
      skeleton.bottomAnchor.constraint(lessThanOrEqualTo: placeholder.bottomAnchor),
    ])
    load()
  }

  deinit { loadTask?.cancel() }

  private func load() {
    placeholder.isHidden = false
    placeholder.subviews.filter { $0.tag == 4101 }.forEach { $0.removeFromSuperview() }
    skeleton.isHidden = false
    skeleton.startAnimating()
    loadTask?.cancel()
    loadTask = Task { [weak self] in
      guard let self else { return }
      do {
        let lesson = try await env.learning.lesson(id: lessonID)
        let html = try LearningHTMLRenderer.render(lesson: lesson, chinese: env.chinese)
        guard !Task.isCancelled else { return }
        title = env.text(lesson.title)
        skeleton.stopAnimating()
        placeholder.isHidden = true
        webView.loadHTMLString(html, baseURL: nil)
      } catch is CancellationError {
      } catch {
        showRetry(error)
      }
    }
  }

  private func showRetry(_ error: Error) {
    skeleton.stopAnimating()
    skeleton.isHidden = true
    let stack = UIStackView()
    stack.tag = 4101
    stack.axis = .vertical
    stack.alignment = .center
    stack.spacing = 12
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.addArrangedSubview(coastLabel(env.t("Couldn’t load this lesson.", "学习资料加载失败。"), size: 16, weight: .semibold))
    stack.addArrangedSubview(coastButton(env.t("Try again", "重新加载")) { [weak self] in self?.load() })
    placeholder.addSubview(stack)
    NSLayoutConstraint.activate([stack.centerXAnchor.constraint(equalTo: placeholder.centerXAnchor), stack.centerYAnchor.constraint(equalTo: placeholder.centerYAnchor), stack.leadingAnchor.constraint(greaterThanOrEqualTo: placeholder.leadingAnchor, constant: 24), stack.trailingAnchor.constraint(lessThanOrEqualTo: placeholder.trailingAnchor, constant: -24)])
  }

  @objc private func toggleBookmark() {
    guard (try? env.store.toggleBookmark(lessonID)) != nil else { return }
    navigationItem.rightBarButtonItems?.last?.image = UIImage(
      systemName: env.store.ledger.bookmarks.contains(lessonID) ? "bookmark.fill" : "bookmark")
  }

  /// 分享整篇文章的截图。内容还没加载完时不出图，避免分享出一张空白。
  @objc private func shareArticle() {
    guard placeholder.isHidden else {
      LearningShare.reportFailure(on: self, chinese: env.chinese)
      return
    }
    let item = navigationItem.rightBarButtonItems?.first
    item?.isEnabled = false
    Task { [weak self] in
      guard let self else { return }
      let image = await LearningShare.image(of: webView)
      item?.isEnabled = true
      guard let image else {
        LearningShare.reportFailure(on: self, chinese: env.chinese)
        return
      }
      LearningShare.present(image, from: self, item: item)
    }
  }

  func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
    guard navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url else { return .allow }
    if url.scheme == "https" {
      present(SFSafariViewController(url: url), animated: true)
    } else if url.scheme == "coastwild", url.host == "lesson", let id = url.pathComponents.last {
      Task { [weak self] in
        guard let self, let lesson = try? await env.learning.lesson(id: id) else { return }
        let controller: UIViewController = lesson.detailType == .web
          ? LearningWebController(env, lessonID: id)
          : LessonController(env, lessonID: id)
        navigationController?.pushViewController(controller, animated: true)
      }
    }
    return .cancel
  }
}
