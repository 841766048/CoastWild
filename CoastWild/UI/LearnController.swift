import UIKit

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

final class LearnController: CoastController {
  var category = "surf"
  override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); render() }

  func render() {
    reset()
    title = nil
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
    let intro = learnLabel(env.t("Find your footing", "找到自己的节奏"), size: 23, weight: .bold, lineHeight: 27.6)
    add(intro)
    stack.setCustomSpacing(2, after: intro)
    let subtitle = learnLabel(env.t("Build skills, confidence and a deeper connection with the coast.", "收获知识与信心，与海岸建立更深的联结。"), size: 14, color: CoastStyle.muted, lineHeight: 21)
    add(subtitle)
    stack.setCustomSpacing(14, after: subtitle)
    add(categoryPills())
    guard let first = env.catalog.lessons.first(where: { $0.category == category }) else { return }
    let group = learnLabel(env.text(first.group), size: 21, weight: .bold, lineHeight: 25.2)
    add(group)
    stack.setCustomSpacing(12, after: group)
    for (index, lesson) in env.catalog.lessons.filter({ $0.category == category }).enumerated() {
      add(lessonCard(lesson, imageHeight: index == 0 ? 180 : 110))
      if let card = stack.arrangedSubviews.last { stack.setCustomSpacing(12, after: card) }
    }
  }

  private func categoryPills() -> UIView {
    let row = UIStackView(); row.axis = .horizontal; row.spacing = 8
    [(env.t("Surfing", "冲浪"), "surf"), (env.t("Hiking", "徒步"), "hike"), (env.t("Camping", "露营"), "camp")].forEach { title, value in
      let button = UIButton(type: .system)
      var config = UIButton.Configuration.filled(); config.title = title
      config.baseBackgroundColor = category == value ? CoastStyle.brand : .white
      config.baseForegroundColor = category == value ? .white : CoastStyle.muted
      config.background.cornerRadius = 20; config.background.strokeColor = category == value ? CoastStyle.brand : CoastStyle.border; config.background.strokeWidth = 1
      config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 17, bottom: 10, trailing: 17)
      button.configuration = config; button.heightAnchor.constraint(equalToConstant: 40).isActive = true
      button.addAction(UIAction { [weak self] _ in self?.category = value; self?.render() }, for: .touchUpInside)
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
    let progress = env.store.ledger.progress[lesson.key]
    let state = progress?.completed == true ? env.t("Review", "复习") : (progress == nil ? env.t("Start learning", "开始学习") : env.t("Continue learning", "继续学习"))
    copy.addArrangedSubview(learnLabel("\(lesson.steps.count) " + env.t("short steps", "个简短步骤") + " · " + state, size: 14, color: CoastStyle.muted, lineHeight: 20.3))
    content.addArrangedSubview(copy)
    NSLayoutConstraint.activate([content.topAnchor.constraint(equalTo: button.topAnchor), content.leadingAnchor.constraint(equalTo: button.leadingAnchor), content.trailingAnchor.constraint(equalTo: button.trailingAnchor), content.bottomAnchor.constraint(equalTo: button.bottomAnchor)])
    button.accessibilityIdentifier = "learn.lesson.\(lesson.key)"
    button.accessibilityLabel = [env.text(lesson.title), "\(lesson.steps.count) " + env.t("short steps", "个简短步骤"), state].joined(separator: ", ")
    button.addAction(UIAction { [weak self] _ in guard let self else { return }; self.push(LessonController(self.env, lesson: lesson)) }, for: .touchUpInside)
    return button
  }
}

final class LessonController: CoastController {
  let lesson: CoastLesson
  var step: Int
  init(_ env: CoastEnvironment, lesson: CoastLesson) {
    self.lesson = lesson
    self.step = min(env.store.ledger.progress[lesson.key]?.step ?? 0, lesson.steps.count - 1)
    super.init(env)
  }
  required init?(coder: NSCoder) { fatalError() }
  override func viewDidLoad() { super.viewDidLoad(); render() }

  func render() {
    reset()
    title = env.text(lesson.title)
    let value = lesson.steps[step]
    let stepLabel = learnLabel(env.t("Step \(step + 1) of \(lesson.steps.count)", "步骤 \(step + 1) / \(lesson.steps.count)"), size: 13, color: CoastStyle.muted, lineHeight: 18.85)
    add(stepLabel)
    stack.setCustomSpacing(31, after: stepLabel)
    let heading = learnLabel(env.text(value.title), size: 32, weight: .bold, lineHeight: 35.84)
    add(heading)
    stack.setCustomSpacing(17, after: heading)
    let image = UIImageView(image: UIImage(named: value.image))
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
    let nextButton = coastButton(step == lesson.steps.count - 1 ? env.t("Finish lesson", "完成学习") : env.t("Next step", "下一步")) { [weak self] in self?.next() }
    add(nextButton)
    if step > 0 {
      let previous = subtleButton(env.t("Previous step", "上一步")) { [weak self] in
        guard let self else { return }
        let previousStep = self.step - 1
        if self.save({ try self.env.store.setProgress(lessonID: self.lesson.key, step: previousStep, completed: false) }) { self.step = previousStep; self.render() }
      }
      add(previous)
    }
  }

  private func subtleButton(_ title: String, action: @escaping () -> Void) -> UIButton {
    let button = UIButton(type: .system)
    var config = UIButton.Configuration.filled()
    config.title = title
    config.baseForegroundColor = CoastStyle.brand
    config.baseBackgroundColor = UIColor(hex: 0xEAF1F4)
    config.background.cornerRadius = 12
    button.configuration = config
    button.heightAnchor.constraint(equalToConstant: 50).isActive = true
    button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    return button
  }

  func next() {
    let complete = step == lesson.steps.count - 1
    if save({ try env.store.setProgress(lessonID: lesson.key, step: complete ? step : step + 1, completed: complete) }) {
      if complete { renderCompletion() } else { step += 1; render(); scroll.setContentOffset(.zero, animated: false) }
    }
  }

  private func renderCompletion() {
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
    add(coastButton(env.t("Explore an experience", "探索相关体验")) { [weak self] in self?.tabBarController?.selectedIndex = 0; self?.navigationController?.popToRootViewController(animated: true) })
    add(coastButton(env.t("Keep learning", "继续学习"), secondary: true) { [weak self] in self?.navigationController?.popViewController(animated: true) })
    add(subtleButton(env.t("Review this lesson", "复习这一课")) { [weak self] in self?.step = 0; self?.render() })
  }
}
