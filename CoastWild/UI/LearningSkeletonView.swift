import SkeletonView
import UIKit

enum LearningSkeletonStyle {
  case list
  case webDetail
  case nativeDetail
}

/// Content-shaped loading UI for the three learning surfaces.
/// The warm artwork blocks stay visible while SkeletonView animates only the copy geometry.
final class LearningSkeletonView: UIView {
  private let style: LearningSkeletonStyle
  private let content = UIStackView()
  private var shimmerViews: [UIView] = []

  private let base = UIColor(hex: 0xE5EBE8)
  private let highlight = UIColor(hex: 0xF5F3ED)
  private let sand = UIColor(hex: 0xF3EFE5)
  private let mist = UIColor(hex: 0xEDF4F2)

  init(style: LearningSkeletonStyle) {
    self.style = style
    super.init(frame: .zero)
    translatesAutoresizingMaskIntoConstraints = false
    backgroundColor = .clear
    content.axis = .vertical
    content.alignment = .fill
    content.spacing = 12
    content.translatesAutoresizingMaskIntoConstraints = false
    addSubview(content)
    NSLayoutConstraint.activate([
      content.topAnchor.constraint(equalTo: topAnchor),
      content.leadingAnchor.constraint(equalTo: leadingAnchor),
      content.trailingAnchor.constraint(equalTo: trailingAnchor),
      content.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
    ])
    switch style {
    case .list: buildList()
    case .webDetail: buildWebDetail()
    case .nativeDetail: buildNativeDetail()
    }
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) unsupported") }

  func setLoadingAccessibility(identifier: String, label: String) {
    addAccessibilityMarker(to: self, identifier: identifier, label: label)
  }

  private func addAccessibilityMarker(to host: UIView, identifier: String, label: String) {
    let marker = UIView()
    marker.translatesAutoresizingMaskIntoConstraints = false
    marker.isAccessibilityElement = true
    marker.accessibilityIdentifier = identifier
    marker.accessibilityLabel = label
    host.addSubview(marker)
    NSLayoutConstraint.activate([
      marker.topAnchor.constraint(equalTo: host.topAnchor),
      marker.leadingAnchor.constraint(equalTo: host.leadingAnchor),
      marker.widthAnchor.constraint(equalToConstant: 1),
      marker.heightAnchor.constraint(equalToConstant: 1),
    ])
  }

  func startAnimating() {
    layoutIfNeeded()
    let gradient = SkeletonGradient(baseColor: base, secondaryColor: highlight)
    shimmerViews.forEach {
      if UIAccessibility.isReduceMotionEnabled {
        $0.showSkeleton(usingColor: base, transition: .none)
      } else {
        $0.showAnimatedGradientSkeleton(
          usingGradient: gradient, transition: .crossDissolve(0.16))
      }
    }
  }

  func stopAnimating() {
    shimmerViews.forEach {
      $0.hideSkeleton(reloadDataAfter: false, transition: .crossDissolve(0.16))
    }
  }

  private func buildList() {
    let featured = card()
    let featuredStack = vertical(in: featured, inset: 0, spacing: 10)
    let hero = artwork(.wave, height: 180, identifier: "learn.loading.hero")
    featuredStack.addArrangedSubview(hero)
    let copy = UIStackView()
    copy.axis = .vertical
    copy.alignment = .fill
    copy.spacing = 7
    copy.isLayoutMarginsRelativeArrangement = true
    copy.layoutMargins = UIEdgeInsets(top: 2, left: 14, bottom: 14, right: 14)
    featuredStack.addArrangedSubview(copy)
    addLine(to: copy, fraction: 0.72, height: 18)
    addLine(to: copy, fraction: 0.45, height: 10)
    content.addArrangedSubview(featured)
    addAccessibilityMarker(
      to: featured, identifier: "learn.loading.card", label: "Loading featured lesson")

    let row = UIStackView()
    row.axis = .horizontal
    row.spacing = 12
    row.distribution = .fillEqually
    row.addArrangedSubview(compactCard(motif: .ridge))
    row.addArrangedSubview(compactCard(motif: .wave))
    content.addArrangedSubview(row)
  }

  private func buildWebDetail() {
    content.spacing = 10
    let meta = UIStackView()
    meta.axis = .horizontal
    meta.spacing = 8
    meta.alignment = .center
    meta.addArrangedSubview(fixedLine(width: 82, height: 10))
    meta.addArrangedSubview(fixedLine(width: 62, height: 10))
    meta.addArrangedSubview(UIView())
    content.addArrangedSubview(meta)
    addLine(to: content, fraction: 0.94, height: 24)
    addLine(to: content, fraction: 0.72, height: 24)
    addLine(to: content, fraction: 0.86, height: 11)
    let hero = artwork(.wave, height: 216, identifier: "learn.web.loading.hero")
    content.addArrangedSubview(hero)

    let author = UIStackView()
    author.axis = .horizontal
    author.spacing = 12
    author.alignment = .center
    let avatar = skeletonBlock(radius: 25)
    NSLayoutConstraint.activate([
      avatar.widthAnchor.constraint(equalToConstant: 50),
      avatar.heightAnchor.constraint(equalToConstant: 50),
    ])
    author.addArrangedSubview(avatar)
    let authorCopy = UIStackView()
    authorCopy.axis = .vertical
    authorCopy.alignment = .leading
    authorCopy.spacing = 7
    authorCopy.addArrangedSubview(fixedLine(width: 150, height: 11))
    authorCopy.addArrangedSubview(fixedLine(width: 104, height: 9))
    author.addArrangedSubview(authorCopy)
    author.addArrangedSubview(UIView())
    content.addArrangedSubview(author)

    let highlights = card(color: sand)
    highlights.accessibilityIdentifier = "learn.web.loading.highlights"
    highlights.isAccessibilityElement = true
    highlights.accessibilityLabel = "Loading article highlights"
    let highlightRow = UIStackView()
    highlightRow.axis = .horizontal
    highlightRow.distribution = .fillEqually
    highlightRow.spacing = 0
    highlightRow.translatesAutoresizingMaskIntoConstraints = false
    highlights.addSubview(highlightRow)
    NSLayoutConstraint.activate([
      highlightRow.topAnchor.constraint(equalTo: highlights.topAnchor, constant: 15),
      highlightRow.leadingAnchor.constraint(equalTo: highlights.leadingAnchor, constant: 10),
      highlightRow.trailingAnchor.constraint(equalTo: highlights.trailingAnchor, constant: -10),
      highlightRow.bottomAnchor.constraint(equalTo: highlights.bottomAnchor, constant: -15),
      highlights.heightAnchor.constraint(equalToConstant: 126),
    ])
    ["lifepreserver", "water.waves", "person.2"].forEach { symbol in
      let group = UIStackView()
      group.axis = .vertical
      group.alignment = .center
      group.spacing = 10
      let icon = UIImageView(image: UIImage(systemName: symbol))
      icon.tintColor = UIColor(hex: 0x7EA8A9)
      icon.contentMode = .scaleAspectFit
      icon.heightAnchor.constraint(equalToConstant: 26).isActive = true
      group.addArrangedSubview(icon)
      group.addArrangedSubview(fixedLine(width: 74, height: 10))
      group.addArrangedSubview(fixedLine(width: 56, height: 8))
      highlightRow.addArrangedSubview(group)
    }
    content.addArrangedSubview(highlights)
  }

  private func buildNativeDetail() {
    content.spacing = 12
    addLine(to: content, fraction: 0.29, height: 10)
    addLine(to: content, fraction: 0.89, height: 24)
    addLine(to: content, fraction: 0.70, height: 24)

    let iconHolder = UIView()
    iconHolder.heightAnchor.constraint(equalToConstant: 62).isActive = true
    let iconCircle = UIView()
    iconCircle.translatesAutoresizingMaskIntoConstraints = false
    iconCircle.backgroundColor = mist
    iconCircle.layer.cornerRadius = 29
    iconCircle.layer.borderWidth = 1
    iconCircle.layer.borderColor = UIColor(hex: 0x9FC2C1).cgColor
    let icon = UIImageView(image: UIImage(systemName: "water.waves"))
    icon.translatesAutoresizingMaskIntoConstraints = false
    icon.tintColor = UIColor(hex: 0x6F9FA1)
    iconCircle.addSubview(icon)
    iconHolder.addSubview(iconCircle)
    NSLayoutConstraint.activate([
      iconCircle.centerXAnchor.constraint(equalTo: iconHolder.centerXAnchor),
      iconCircle.centerYAnchor.constraint(equalTo: iconHolder.centerYAnchor),
      iconCircle.widthAnchor.constraint(equalToConstant: 58),
      iconCircle.heightAnchor.constraint(equalToConstant: 58),
      icon.widthAnchor.constraint(equalToConstant: 27),
      icon.heightAnchor.constraint(equalToConstant: 27),
      icon.centerXAnchor.constraint(equalTo: iconCircle.centerXAnchor),
      icon.centerYAnchor.constraint(equalTo: iconCircle.centerYAnchor),
    ])
    content.addArrangedSubview(iconHolder)

    let hero = artwork(.board, height: 246, identifier: "learn.detail.loading.hero")
    content.addArrangedSubview(hero)
    addLine(to: content, fraction: 0.96, height: 11)
    addLine(to: content, fraction: 0.89, height: 11)
    addLine(to: content, fraction: 0.74, height: 11)

    let callout = card(color: mist)
    callout.accessibilityIdentifier = "learn.detail.loading.callout"
    callout.isAccessibilityElement = true
    callout.accessibilityLabel = "Loading lesson note"
    let calloutRow = UIStackView()
    calloutRow.axis = .horizontal
    calloutRow.alignment = .center
    calloutRow.spacing = 12
    calloutRow.translatesAutoresizingMaskIntoConstraints = false
    callout.addSubview(calloutRow)
    let dot = skeletonBlock(radius: 14)
    NSLayoutConstraint.activate([
      dot.widthAnchor.constraint(equalToConstant: 28),
      dot.heightAnchor.constraint(equalToConstant: 28),
    ])
    calloutRow.addArrangedSubview(dot)
    let calloutCopy = UIStackView()
    calloutCopy.axis = .vertical
    calloutCopy.alignment = .leading
    calloutCopy.spacing = 7
    calloutCopy.addArrangedSubview(fixedLine(width: 178, height: 10))
    calloutCopy.addArrangedSubview(fixedLine(width: 132, height: 9))
    calloutRow.addArrangedSubview(calloutCopy)
    calloutRow.addArrangedSubview(UIView())
    NSLayoutConstraint.activate([
      calloutRow.topAnchor.constraint(equalTo: callout.topAnchor, constant: 13),
      calloutRow.leadingAnchor.constraint(equalTo: callout.leadingAnchor, constant: 15),
      calloutRow.trailingAnchor.constraint(equalTo: callout.trailingAnchor, constant: -15),
      calloutRow.bottomAnchor.constraint(equalTo: callout.bottomAnchor, constant: -13),
      callout.heightAnchor.constraint(equalToConstant: 66),
    ])
    content.addArrangedSubview(callout)
    let button = skeletonBlock(radius: 14)
    button.backgroundColor = UIColor(hex: 0xDCE9E6)
    button.heightAnchor.constraint(equalToConstant: 52).isActive = true
    content.addArrangedSubview(button)
  }

  private func compactCard(motif: SkeletonArtworkView.Motif) -> UIView {
    let result = card()
    let stack = vertical(in: result, inset: 0, spacing: 8)
    stack.addArrangedSubview(artwork(motif, height: 92))
    let copy = UIStackView()
    copy.axis = .vertical
    copy.alignment = .leading
    copy.spacing = 6
    copy.isLayoutMarginsRelativeArrangement = true
    copy.layoutMargins = UIEdgeInsets(top: 0, left: 10, bottom: 11, right: 10)
    copy.addArrangedSubview(fixedLine(width: 112, height: 10))
    copy.addArrangedSubview(fixedLine(width: 76, height: 8))
    stack.addArrangedSubview(copy)
    return result
  }

  private func card(color: UIColor = .white) -> UIView {
    let view = UIView()
    view.backgroundColor = color
    view.layer.cornerRadius = 16
    view.layer.borderWidth = color == .white ? 1 : 0
    view.layer.borderColor = UIColor(hex: 0xE5E7E4).cgColor
    view.clipsToBounds = true
    return view
  }

  private func vertical(in host: UIView, inset: CGFloat, spacing: CGFloat) -> UIStackView {
    let stack = UIStackView()
    stack.axis = .vertical
    stack.spacing = spacing
    stack.translatesAutoresizingMaskIntoConstraints = false
    host.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: host.topAnchor, constant: inset),
      stack.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: inset),
      stack.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -inset),
      stack.bottomAnchor.constraint(equalTo: host.bottomAnchor, constant: -inset),
    ])
    return stack
  }

  private func artwork(
    _ motif: SkeletonArtworkView.Motif, height: CGFloat, identifier: String? = nil
  ) -> UIView {
    let view = SkeletonArtworkView(motif: motif, fill: sand)
    view.heightAnchor.constraint(equalToConstant: height).isActive = true
    view.accessibilityIdentifier = identifier
    if identifier != nil {
      view.isAccessibilityElement = true
      view.accessibilityLabel = "Loading illustration"
    } else {
      view.isAccessibilityElement = false
    }
    return view
  }

  @discardableResult
  private func addLine(to stack: UIStackView, fraction: CGFloat, height: CGFloat) -> UIView {
    let line = skeletonBlock(radius: height / 2)
    let row = UIStackView()
    row.axis = .horizontal
    row.alignment = .center
    row.spacing = 0
    row.addArrangedSubview(line)
    row.addArrangedSubview(UIView())
    stack.addArrangedSubview(row)
    line.heightAnchor.constraint(equalToConstant: height).isActive = true
    line.widthAnchor.constraint(equalTo: row.widthAnchor, multiplier: fraction).isActive = true
    row.heightAnchor.constraint(equalToConstant: height).isActive = true
    return line
  }

  private func fixedLine(width: CGFloat, height: CGFloat) -> UIView {
    let line = skeletonBlock(radius: height / 2)
    NSLayoutConstraint.activate([
      line.widthAnchor.constraint(equalToConstant: width),
      line.heightAnchor.constraint(equalToConstant: height),
    ])
    return line
  }

  private func skeletonBlock(radius: CGFloat) -> UIView {
    let view = UIView()
    view.backgroundColor = base
    view.layer.cornerRadius = radius
    view.clipsToBounds = true
    view.isSkeletonable = true
    view.skeletonCornerRadius = Float(radius)
    view.isAccessibilityElement = false
    shimmerViews.append(view)
    return view
  }
}

private final class SkeletonArtworkView: UIView {
  enum Motif { case wave, ridge, board }

  private let motif: Motif
  private let contour = CAShapeLayer()
  private let accent = CAShapeLayer()

  init(motif: Motif, fill: UIColor) {
    self.motif = motif
    super.init(frame: .zero)
    backgroundColor = fill
    layer.cornerRadius = 16
    clipsToBounds = true
    [contour, accent].forEach {
      $0.fillColor = UIColor.clear.cgColor
      $0.strokeColor = UIColor(hex: 0x7FA8A7).withAlphaComponent(0.24).cgColor
      $0.lineWidth = 1.3
      $0.lineCap = .round
      $0.lineJoin = .round
      layer.addSublayer($0)
    }
    accent.strokeColor = UIColor(hex: 0x7FA8A7).withAlphaComponent(0.15).cgColor
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) unsupported") }

  override func layoutSubviews() {
    super.layoutSubviews()
    contour.frame = bounds
    accent.frame = bounds
    switch motif {
    case .wave: drawWave()
    case .ridge: drawRidge()
    case .board: drawBoard()
    }
  }

  private func drawWave() {
    let first = UIBezierPath()
    first.move(to: CGPoint(x: -12, y: bounds.height * 0.70))
    first.addCurve(
      to: CGPoint(x: bounds.width * 0.56, y: bounds.height * 0.66),
      controlPoint1: CGPoint(x: bounds.width * 0.20, y: bounds.height * 0.69),
      controlPoint2: CGPoint(x: bounds.width * 0.25, y: bounds.height * 0.34))
    first.addCurve(
      to: CGPoint(x: bounds.width + 10, y: bounds.height * 0.58),
      controlPoint1: CGPoint(x: bounds.width * 0.76, y: bounds.height * 0.91),
      controlPoint2: CGPoint(x: bounds.width * 0.82, y: bounds.height * 0.44))
    contour.path = first.cgPath
    var offset = CGAffineTransform(translationX: 0, y: 18)
    accent.path = first.cgPath.copy(using: &offset)
  }

  private func drawRidge() {
    let ridge = UIBezierPath()
    ridge.move(to: CGPoint(x: -5, y: bounds.height * 0.72))
    ridge.addLine(to: CGPoint(x: bounds.width * 0.28, y: bounds.height * 0.48))
    ridge.addLine(to: CGPoint(x: bounds.width * 0.46, y: bounds.height * 0.68))
    ridge.addLine(to: CGPoint(x: bounds.width * 0.69, y: bounds.height * 0.40))
    ridge.addLine(to: CGPoint(x: bounds.width + 5, y: bounds.height * 0.72))
    contour.path = ridge.cgPath
    var offset = CGAffineTransform(translationX: 0, y: 11)
    accent.path = ridge.cgPath.copy(using: &offset)
  }

  private func drawBoard() {
    drawWave()
    let board = UIBezierPath(roundedRect: CGRect(
      x: bounds.midX - 22, y: bounds.height * 0.08,
      width: 44, height: bounds.height * 0.94), cornerRadius: 22)
    var transform = CGAffineTransform(rotationAngle: 0.18)
    contour.path = board.cgPath.copy(using: &transform)
  }
}
