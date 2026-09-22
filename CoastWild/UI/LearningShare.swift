import UIKit
import WebKit

/// 学习资料分享。两种详情页都分享整页内容的图片：
/// Web 长文截取整篇 HTML，原生课程截取内容区（不含操作按钮）。
enum LearningShare {
  /// 超长页面按此高度截断，避免一次性渲染吃掉过多内存。
  static let heightLimit: CGFloat = 12_000
  /// 位图倍率。3x 屏上整页长图会大到难以分享，压到 2x 已足够清晰。
  static let scaleLimit: CGFloat = 2

  /// 按视图的完整尺寸渲染成图片。视图放在滚动容器里也能拿到滚动区域以外的内容。
  /// inset 为四周留白，用来补回滚动容器的水平边距。
  @MainActor
  static func image(of view: UIView, background: UIColor = .white, inset: CGFloat = 0) -> UIImage? {
    view.layoutIfNeeded()
    let width = view.bounds.width
    let height = view.bounds.height
    guard width > 0, height > 0 else { return nil }
    let canvas = CGSize(
      width: width + inset * 2, height: min(height, heightLimit) + inset * 2)
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = min(UIScreen.main.scale, scaleLimit)
    return UIGraphicsImageRenderer(size: canvas, format: format).image { context in
      background.setFill()
      context.fill(CGRect(origin: .zero, size: canvas))
      // 按完整高度绘制，超出画布的部分自然被裁掉；若改用裁剪后的高度，
      // drawHierarchy 会把内容压缩变形而不是截断。
      let target = CGRect(x: inset, y: inset, width: width, height: height)
      if !view.drawHierarchy(in: target, afterScreenUpdates: true) {
        context.cgContext.translateBy(x: inset, y: inset)
        view.layer.render(in: context.cgContext)
      }
    }
  }

  /// 整篇 Web 长文。WKWebView 只渲染当前视口，把它撑高或直接截全图都只能拿到首屏，
  /// 所以逐屏滚动取图再拼成一张长图。
  @MainActor
  static func image(of webView: WKWebView) async -> UIImage? {
    let scroll = webView.scrollView
    let width = scroll.contentSize.width
    let viewport = webView.bounds.height
    guard width > 0, viewport > 0 else { return nil }
    let total = min(scroll.contentSize.height, heightLimit)
    guard total > 0 else { return nil }
    let insetTop = scroll.adjustedContentInset.top
    let restore = scroll.contentOffset

    var tiles: [(top: CGFloat, image: UIImage)] = []
    var top: CGFloat = 0
    while top < total {
      scroll.contentOffset = CGPoint(x: 0, y: top - insetTop)
      webView.layoutIfNeeded()
      // 滚到底时 contentOffset 会被夹住，按实际落点摆放，重叠部分由后一屏覆盖。
      let landed = scroll.contentOffset.y + insetTop
      try? await Task.sleep(nanoseconds: 150_000_000)
      let configuration = WKSnapshotConfiguration()
      configuration.rect = CGRect(x: 0, y: 0, width: width, height: viewport)
      configuration.afterScreenUpdates = true
      if let tile = try? await webView.takeSnapshot(configuration: configuration) {
        tiles.append((landed, tile))
      }
      if landed + viewport >= total { break }
      top = landed + viewport
    }
    scroll.contentOffset = restore
    guard !tiles.isEmpty else { return nil }

    let canvas = CGSize(width: width, height: total)
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = min(UIScreen.main.scale, scaleLimit)
    return UIGraphicsImageRenderer(size: canvas, format: format).image { context in
      UIColor.white.setFill()
      context.fill(CGRect(origin: .zero, size: canvas))
      for tile in tiles {
        tile.image.draw(
          in: CGRect(x: 0, y: tile.top, width: width, height: tile.image.size.height))
      }
    }
  }

  @MainActor
  static func present(_ image: UIImage, from controller: UIViewController, item: UIBarButtonItem?) {
    let share = UIActivityViewController(activityItems: [image], applicationActivities: nil)
    share.popoverPresentationController?.barButtonItem = item
    share.popoverPresentationController?.sourceView = controller.view
    controller.present(share, animated: true)
  }

  @MainActor
  static func reportFailure(on controller: UIViewController, chinese: Bool) {
    let alert = UIAlertController(
      title: chinese ? "无法生成图片" : "Couldn’t create the image",
      message: chinese ? "请等内容加载完成后再试。" : "Wait for the content to finish loading, then try again.",
      preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: chinese ? "好" : "OK", style: .default))
    controller.present(alert, animated: true)
  }
}
