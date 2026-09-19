import UIKit

final class LearnController: CoastController {
  var category = "surf"
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    render()
  }
  func render() {
    reset()
    title = env.t("Learn", "学习")
    heading(env.t("Find your confidence outdoors", "找到自己的节奏"))
    note(env.t("Small lessons. More confidence.", "从基础开始，自信探索。"))
    chips(
      [env.t("Surf", "冲浪"), env.t("Hiking", "徒步"), env.t("Camping", "露营")],
      selected: ["surf", "hike", "camp"].firstIndex(of: category) ?? 0
    ) { [weak self] i in
      self?.category = ["surf", "hike", "camp"][i]
      self?.render()
    }
    for lesson in env.catalog.lessons.filter({ $0.category == category }) {
      add(coastLabel(env.text(lesson.group), size: 20, weight: .semibold))
      add(coastImage(lesson.image, height: 190))
      let progress = env.store.ledger.progress[lesson.key]
      add(
        row(
          title: env.text(lesson.title),
          subtitle: progress?.completed == true
            ? env.t("Completed · Review", "已完成 · 复习")
            : env.t("\(lesson.steps.count) short steps", "\(lesson.steps.count) 个步骤")
        ) { [weak self] in
          guard let self else { return }
          self.push(LessonController(self.env, lesson: lesson))
        })
    }
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
  override func viewDidLoad() {
    super.viewDidLoad()
    render()
  }
  func render() {
    reset()
    title = env.text(lesson.title)
    let value = lesson.steps[step]
    note(env.t("STEP", "步骤") + " \(step+1) / \(lesson.steps.count)")
    let progress = UIProgressView(progressViewStyle: .default)
    progress.progress = Float(step + 1) / Float(lesson.steps.count)
    progress.progressTintColor = CoastStyle.brand
    add(progress)
    heading(env.text(value.title))
    add(coastImage(value.image, height: 290))
    add(coastLabel(env.text(value.body)))
    add(
      coastButton(
        step == lesson.steps.count - 1 ? env.t("Finish lesson", "完成学习") : env.t("Next step", "下一步")
      ) { [weak self] in self?.next() })
    if step > 0 {
      add(
        coastButton(env.t("Previous step", "上一步"), secondary: true) { [weak self] in
          guard let self else { return }
          let next = self.step - 1
          if self.save({
            try self.env.store.setProgress(lessonID: self.lesson.key, step: next, completed: false)
          }) {
            self.step = next
            self.render()
          }
        })
    }
  }
  func next() {
    let complete = step == lesson.steps.count - 1
    if save({
      try env.store.setProgress(
        lessonID: lesson.key, step: complete ? step : step + 1, completed: complete)
    }) {
      if complete {
        reset()
        empty(
          env.t("Well done!", "学习完成。"),
          env.t("A little more confidence for your next time outside.", "为下一次出发，多一份从容。"),
          icon: "check")
        add(
          coastButton(env.t("Back to lessons", "回到学习专题")) { [weak self] in
            self?.navigationController?.popViewController(animated: true)
          })
        add(
          coastButton(env.t("Review", "回顾学习"), secondary: true) { [weak self] in
            self?.step = 0
            self?.render()
          })
      } else {
        step += 1
        render()
        scroll.setContentOffset(.zero, animated: false)
      }
    }
  }
}
