import UIKit

extension CoastController {
  /// Returns true when the page has no content and should stop before rendering its cards.
  @discardableResult func addPublicContentStatus(isEmpty: Bool) -> Bool {
    let state = env.publicContent.state
    if state == .loaded, !isEmpty { return false }
    let text: String
    switch state {
    case .idle: text = env.t("Load the latest content to get started.", "加载最新内容，开始探索。")
    case .loading: text = env.t("Loading content…", "正在加载内容…")
    case .failed:
      text = isEmpty
        ? env.t("Content couldn’t be loaded. Please try again.", "内容加载失败，请重试。")
        : env.t("Couldn’t refresh. Your saved content is still available.", "更新失败，仍可查看已缓存内容。")
    case .loaded: text = env.t("No content available yet.", "暂无内容。")
    }
    let label = coastLabel(text, size: 16, color: CoastStyle.muted)
    label.accessibilityIdentifier = "public-content.status"
    add(label)
    if state == .loading {
      let spinner = UIActivityIndicatorView(style: .medium)
      spinner.startAnimating()
      add(spinner)
    } else {
      let retry = coastButton(env.t("Try again", "重试")) { [weak self] in
        self?.env.refreshPublicContent(force: true)
      }
      retry.accessibilityIdentifier = "public-content.retry"
      add(retry)
    }
    return isEmpty
  }
}
