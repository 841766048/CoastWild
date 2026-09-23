import UIKit
import SkeletonView

private func learnLabel(_ text: String, size: CGFloat, weight: UIFont.Weight = .regular, color: UIColor = CoastStyle.ink, lineHeight: CGFloat? = nil) -> UILabel {
  let label = coastLabel(text, size: size, weight: weight, color: color)
  guard let lineHeight else { return label }
  let paragraph = NSMutableParagraphStyle()
  paragraph.minimumLineHeight = lineHeight
  paragraph.maximumLineHeight = lineHeight
  let attributed = NSMutableAttributedString(attributedString: label.attributedText ?? NSAttributedString(string: text))
  attributed.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: attributed.length))
  label.attributedText = attributed
  return label
}

final class FreeLearnController: CoastController {
  var category = ""
  private var loadTask: Task<Void, Never>?
  private var requestedCategory = ""
  private var cachedLessons: [String: [CoastLesson]] = [:]
  private var progressLabels: [String: UILabel] = [:]
  private var renderedInChinese: Bool?

  override func viewDidLoad() {
    super.viewDidLoad()
    render()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if let renderedInChinese, renderedInChinese != env.chinese {
      render(preservingScrollPosition: true)
    } else {
      refreshProgressLabels()
    }
  }
  deinit { loadTask?.cancel() }

  func render(preservingScrollPosition: Bool = false) {
    let previousOffset = scroll.contentOffset
    reset()
    progressLabels.removeAll()
    renderedInChinese = env.chinese
    title = nil
    // 默认选中 catalog.json 里的第一个类别，而不是写死 surf。
    let keys = (env.catalog.categories ?? []).map(\.key)
    if !keys.contains(category), let first = keys.first { category = first }
    let header = UIStackView()
    header.axis = .horizontal
    header.alignment = .center
    header.addArrangedSubview(learnLabel(env.t("Learn", "学习"), size: 32, weight: .bold, lineHeight: 35.84))
    header.addArrangedSubview(UIView())
    let profile = UIButton(type: .system)
    profile.setImage(UIImage(named: "icon-user"), for: .normal)
    profile.tintColor = CoastStyle.brand
    profile.widthAnchor.constraint(equalToConstant: 44).isActive = true
    profile.heightAnchor.constraint(equalToConstant: 44).isActive = true
    profile.accessibilityLabel = env.t("Your space", "个人空间")
    profile.addAction(UIAction { [weak self] _ in guard let self else { return }; self.push(ProfileController(self.env)) }, for: .touchUpInside)
    header.addArrangedSubview(profile)
    add(header)
    stack.setCustomSpacing(14, after: header)
    if let copy = env.catalog.learn {
      let intro = learnLabel(env.text(copy.heading), size: 23, weight: .bold, lineHeight: 27.6)
      add(intro)
      stack.setCustomSpacing(2, after: intro)
      let subtitle = learnLabel(
        env.text(copy.subtitle), size: 14, color: CoastStyle.muted, lineHeight: 21)
      add(subtitle)
      stack.setCustomSpacing(14, after: subtitle)
    }
    add(categoryPills())
    if let lessons = cachedLessons[category] {
      renderLessons(lessons)
    } else {
      loadLessons()
    }
    if preservingScrollPosition {
      view.layoutIfNeeded()
      let maximumOffset = max(0, scroll.contentSize.height - scroll.bounds.height)
      scroll.setContentOffset(
        CGPoint(x: previousOffset.x, y: min(previousOffset.y, maximumOffset)), animated: false)
    }
  }

  private func loadLessons() {
    loadTask?.cancel()
    requestedCategory = category
    let loading = LearningSkeletonView(style: .list)
    loading.heightAnchor.constraint(equalToConstant: 390).isActive = true
    loading.setLoadingAccessibility(
      identifier: "learn.loading",
      label: env.t("Loading learning materials", "正在加载学习资料"))
    add(loading)
    loading.startAnimating()
    let requested = category
    loadTask = Task { [weak self, weak loading] in
      guard let self else { return }
      do {
        let lessons = try await env.learning.lessons(category: requested)
        guard !Task.isCancelled, requested == category else { return }
        cachedLessons[requested] = lessons
        loading?.stopAnimating()
        loading?.removeFromSuperview()
        renderLessons(lessons)
      } catch is CancellationError {
      } catch {
        loading?.stopAnimating()
        loading?.removeFromSuperview()
        renderLoadError()
      }
    }
  }

  private func renderLessons(_ lessons: [CoastLesson]) {
    guard let first = lessons.first else { return }
    let group = learnLabel(env.text(first.group), size: 21, weight: .bold, lineHeight: 25.2)
    add(group)
    stack.setCustomSpacing(12, after: group)
    for (index, lesson) in lessons.enumerated() {
      add(lessonCard(lesson, imageHeight: index == 0 ? 180 : 110))
      if let card = stack.arrangedSubviews.last { stack.setCustomSpacing(12, after: card) }
    }
  }

  private func renderLoadError() {
    let card = UIStackView()
    card.axis = .vertical
    card.spacing = 12
    card.alignment = .center
    card.isLayoutMarginsRelativeArrangement = true
    card.layoutMargins = UIEdgeInsets(top: 28, left: 20, bottom: 28, right: 20)
    card.layer.cornerRadius = 16
    card.layer.borderWidth = 1
    card.layer.borderColor = CoastStyle.border.cgColor
    card.addArrangedSubview(learnLabel(env.t("Couldn’t load learning materials.", "学习资料加载失败。"), size: 16, weight: .semibold))
    let retry = coastButton(env.t("Try again", "重新加载")) { [weak self] in
      guard let self else { return }
      self.cachedLessons[self.category] = nil
      self.render()
    }
    retry.accessibilityIdentifier = "learn.retry"
    card.addArrangedSubview(retry)
    add(card)
  }

  private func categoryPills() -> UIView {
    let row = UIStackView(); row.axis = .horizontal; row.spacing = 8
    (env.catalog.categories ?? []).map { (env.text($0.name), $0.key) }.forEach { title, value in
      let button = UIButton(type: .system)
      var config = UIButton.Configuration.filled(); config.title = title
      config.baseBackgroundColor = category == value ? CoastStyle.brand : .white
      config.baseForegroundColor = category == value ? .white : CoastStyle.muted
      config.background.cornerRadius = 20; config.background.strokeColor = category == value ? CoastStyle.brand : CoastStyle.border; config.background.strokeWidth = 1
      config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 17, bottom: 10, trailing: 17)
      config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
        var attributes = incoming
        attributes.font = CoastStyle.font(14)
        return attributes
      }
      button.configuration = config; button.heightAnchor.constraint(equalToConstant: 40).isActive = true
      button.addAction(UIAction { [weak self] _ in
        guard let self, self.category != value else { return }
        self.category = value
        self.scroll.setContentOffset(.zero, animated: false)
        self.render()
      }, for: .touchUpInside)
      row.addArrangedSubview(button)
    }
    row.addArrangedSubview(UIView()); return row
  }

  private func lessonCard(_ lesson: CoastLesson, imageHeight: CGFloat) -> UIView {
    let button = UIButton(type: .system)
    button.backgroundColor = .white
    button.layer.cornerRadius = 16
    button.layer.borderWidth = 1
    button.layer.borderColor = CoastStyle.border.cgColor
    button.clipsToBounds = true
    let content = UIStackView()
    content.axis = .vertical
    content.spacing = 0
    content.translatesAutoresizingMaskIntoConstraints = false
    content.isUserInteractionEnabled = false
    button.addSubview(content)
    let image = UIImageView(image: UIImage(named: lesson.image))
    image.contentMode = .scaleAspectFill
    image.clipsToBounds = true
    image.heightAnchor.constraint(equalToConstant: imageHeight).isActive = true
    content.addArrangedSubview(image)
    let copy = UIStackView()
    copy.axis = .vertical
    copy.spacing = 4
    copy.isLayoutMarginsRelativeArrangement = true
    copy.layoutMargins = UIEdgeInsets(top: 11, left: 15, bottom: 12, right: 15)
    copy.addArrangedSubview(learnLabel(env.text(lesson.title), size: 24, weight: .bold, lineHeight: 28.8))
    let meta = lessonMeta(lesson)
    let metaLabel = learnLabel(meta, size: 14, color: CoastStyle.muted, lineHeight: 20.3)
    progressLabels[lesson.key] = metaLabel
    copy.addArrangedSubview(metaLabel)
    content.addArrangedSubview(copy)
    NSLayoutConstraint.activate([content.topAnchor.constraint(equalTo: button.topAnchor), content.leadingAnchor.constraint(equalTo: button.leadingAnchor), content.trailingAnchor.constraint(equalTo: button.trailingAnchor), content.bottomAnchor.constraint(equalTo: button.bottomAnchor)])
    button.accessibilityIdentifier = "learn.lesson.\(lesson.key)"
    button.accessibilityLabel = [env.text(lesson.title), meta].joined(separator: ", ")
    button.addAction(UIAction { [weak self] _ in
      guard let self else { return }
      if lesson.detailType == .web { self.push(LearningWebController(self.env, lessonID: lesson.key)) }
      else { self.push(LessonController(self.env, lessonID: lesson.key)) }
    }, for: .touchUpInside)
    return button
  }

  private func lessonMeta(_ lesson: CoastLesson) -> String {
    let progress = env.store.ledger.progress[lesson.key]
    let state = progress?.completed == true
      ? env.t("Review", "复习")
      : (progress == nil
        ? env.t("Start learning", "开始学习")
        : env.t("Continue learning", "继续学习"))
    let type = lesson.detailType == .web
      ? env.t("Web guide", "Web 长文")
      : env.t("Native lesson", "原生课程")
    return "\(lesson.readingMinutes) " + env.t("min", "分钟") + " · " + type + " · " + state
  }

  private func refreshProgressLabels() {
    guard let lessons = cachedLessons[category] else { return }
    lessons.forEach { progressLabels[$0.key]?.text = lessonMeta($0) }
  }
}

final class LessonController: CoastController {
  let lessonID: String
  var lesson: CoastLesson?
  var step = 0
  private var loadTask: Task<Void, Never>?
  /// 分享截图时要临时藏起来的操作按钮，随每次 reset 清空。
  private var actionViews: [UIView] = []
  private lazy var shareItem: UIBarButtonItem = {
    let item = UIBarButtonItem(
      image: UIImage(systemName: "square.and.arrow.up"), style: .plain,
      target: self, action: #selector(shareLesson))
    item.accessibilityIdentifier = "learn.share"
    item.accessibilityLabel = env.t("Share", "分享")
    return item
  }()
  init(_ env: CoastEnvironment, lessonID: String) {
    self.lessonID = lessonID
    super.init(env)
  }
  required init?(coder: NSCoder) { fatalError() }
  override func viewDidLoad() { super.viewDidLoad(); load() }
  deinit { loadTask?.cancel() }

  override func reset() {
    super.reset()
    actionViews = []
  }

  /// 分享当前内容区的整体截图。按钮属于操作而不是内容，截图前先藏起来。
  @objc private func shareLesson() {
    guard lesson != nil else {
      LearningShare.reportFailure(on: self, chinese: env.chinese)
      return
    }
    let hidden = actionViews.filter { !$0.isHidden }
    hidden.forEach { $0.isHidden = true }
    // stack 的左右边距来自滚动容器约束，截图时用 inset 补回来。
    let image = LearningShare.image(of: stack, inset: 20)
    hidden.forEach { $0.isHidden = false }
    stack.layoutIfNeeded()
    guard let image else {
      LearningShare.reportFailure(on: self, chinese: env.chinese)
      return
    }
    LearningShare.present(image, from: self, item: shareItem)
  }

  private func load() {
    reset()
    let loading = LearningSkeletonView(style: .nativeDetail)
    loading.heightAnchor.constraint(equalToConstant: 650).isActive = true
    loading.setLoadingAccessibility(
      identifier: "learn.detail.loading",
      label: env.t("Loading lesson", "正在加载课程"))
    add(loading)
    loading.startAnimating()
    loadTask = Task { [weak self, weak loading] in
      guard let self else { return }
      do {
        let lesson = try await env.learning.lesson(id: lessonID)
        guard lesson.detailType == .native, !Task.isCancelled else { return }
        self.lesson = lesson
        self.step = min(env.store.ledger.progress[lesson.key]?.step ?? 0, max(lesson.steps.count - 1, 0))
        loading?.stopAnimating()
        render()
      } catch is CancellationError {
      } catch {
        loading?.stopAnimating()
        reset()
        add(learnLabel(env.t("Couldn’t load this lesson.", "课程加载失败。"), size: 18, weight: .semibold))
        add(coastButton(env.t("Try again", "重新加载")) { [weak self] in self?.load() })
      }
    }
  }

  func render() {
    guard let lesson, !lesson.steps.isEmpty else { return }
    reset()
    title = env.text(lesson.title)
    navigationItem.rightBarButtonItem = shareItem
    let value = lesson.steps[step]
    let stepLabel = learnLabel(env.t("Step \(step + 1) of \(lesson.steps.count)", "步骤 \(step + 1) / \(lesson.steps.count)"), size: 13, color: CoastStyle.muted, lineHeight: 18.85)
    add(stepLabel)
    stack.setCustomSpacing(31, after: stepLabel)
    let heading = learnLabel(env.text(value.title), size: 32, weight: .bold, lineHeight: 35.84)
    add(heading)
    stack.setCustomSpacing(17, after: heading)
    let icon = UIImageView(image: value.icon.flatMap { UIImage(systemName: $0) })
    icon.tintColor = CoastStyle.brand
    icon.contentMode = .scaleAspectFit
    icon.heightAnchor.constraint(equalToConstant: 32).isActive = true
    add(icon)
    stack.setCustomSpacing(12, after: icon)
    let image = UIImageView(image: UIImage(named: value.assetName))
    image.contentMode = .scaleAspectFit
    image.clipsToBounds = true
    image.backgroundColor = UIColor(hex: 0xF7F4EA)
    image.layer.cornerRadius = 16
    image.heightAnchor.constraint(equalToConstant: 320).isActive = true
    add(image)
    stack.setCustomSpacing(18, after: image)
    let body = learnLabel(env.text(value.body), size: 16, lineHeight: 24)
    add(body)
    stack.setCustomSpacing(18, after: body)
    if let callout = value.callout {
      let note = learnLabel(env.text(callout), size: 14, weight: .semibold, color: CoastStyle.brand, lineHeight: 21)
      note.backgroundColor = UIColor(hex: 0xEAF5F6)
      note.layer.cornerRadius = 12
      note.clipsToBounds = true
      add(note)
      stack.setCustomSpacing(18, after: note)
    }
    let nextButton = coastButton(step == lesson.steps.count - 1 ? env.t("Finish lesson", "完成学习") : env.t("Next step", "下一步")) { [weak self] in self?.next() }
    add(nextButton)
    actionViews.append(nextButton)
    if step > 0 {
      let previous = subtleButton(env.t("Previous step", "上一步")) { [weak self] in
        guard let self, let lesson = self.lesson else { return }
        let previousStep = self.step - 1
        if self.save({ try self.env.store.setProgress(lessonID: lesson.key, step: previousStep, completed: false) }) { self.step = previousStep; self.render() }
      }
      add(previous)
      actionViews.append(previous)
    }
  }

  private func subtleButton(_ title: String, action: @escaping () -> Void) -> UIButton {
    let button = UIButton(type: .system)
    var config = UIButton.Configuration.filled()
    config.title = title
    config.baseForegroundColor = CoastStyle.brand
    config.baseBackgroundColor = UIColor(hex: 0xEAF1F4)
    config.background.cornerRadius = 12
    config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
      var attributes = incoming
      attributes.font = CoastStyle.font(16, .semibold)
      return attributes
    }
    button.configuration = config
    button.heightAnchor.constraint(equalToConstant: 50).isActive = true
    button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    return button
  }

  func next() {
    guard let lesson else { return }
    let complete = step == lesson.steps.count - 1
    if save({ try env.store.setProgress(lessonID: lesson.key, step: complete ? step : step + 1, completed: complete) }) {
      if complete { renderCompletion() } else { step += 1; render(); scroll.setContentOffset(.zero, animated: false) }
    }
  }

  private func renderCompletion() {
    guard let lesson else { return }
    reset()
    let spacer = UIView()
    spacer.heightAnchor.constraint(equalToConstant: 180).isActive = true
    add(spacer)
    let eyebrow = learnLabel(env.t("A LITTLE MORE CONFIDENT", "又多了解了一点"), size: 11, weight: .semibold, color: CoastStyle.brand)
    eyebrow.textAlignment = .center
    add(eyebrow)
    let complete = learnLabel(env.t("Lesson complete", "学习完成"), size: 30, weight: .bold, lineHeight: 34)
    complete.textAlignment = .center
    add(complete)
    let message = learnLabel(env.t("You’ve completed", "你已完成"), size: 16, color: CoastStyle.muted, lineHeight: 24)
    message.textAlignment = .center; add(message)
    let lessonTitle = learnLabel(env.text(lesson.title), size: 16, weight: .bold, color: CoastStyle.muted, lineHeight: 24)
    lessonTitle.textAlignment = .center; add(lessonTitle)
    let explore = coastButton(env.t("Explore an experience", "探索相关体验")) { [weak self] in self?.tabBarController?.selectedIndex = 0; self?.navigationController?.popToRootViewController(animated: true) }
    add(explore)
    let keep = coastButton(env.t("Keep learning", "继续学习"), secondary: true) { [weak self] in self?.navigationController?.popViewController(animated: true) }
    add(keep)
    let review = subtleButton(env.t("Review this lesson", "复习这一课")) { [weak self] in self?.step = 0; self?.render() }
    add(review)
    actionViews.append(contentsOf: [explore, keep, review])
  }
}
