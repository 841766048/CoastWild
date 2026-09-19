import UIKit
import BRPickerView

/// Date-only values are serialized independently of device time zone and calendar.
enum CoastDatePicker {
  static func formatter(time: Bool = false) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = time ? "HH:mm" : "yyyy-MM-dd"
    formatter.isLenient = false
    return formatter
  }

  static func show(from controller: CoastController, title: String, value: String,
                   time: Bool = false, minimum: Date? = nil, maximum: Date? = nil,
                   allowsClear: Bool = false, completion: @escaping (String) -> Void) {
    controller.view.endEditing(true)
    let formatter = formatter(time: time)
    let local = self.formatter(time: time)
    local.timeZone = TimeZone(identifier: controller.env.store.preferences.region == "CN"
      ? "Asia/Shanghai" : "America/Los_Angeles")
    let defaultValue = time ? local.string(from: Date()) : CoastEntry(region: controller.env.store.preferences.region).date
    var initial = formatter.date(from: value) ?? formatter.date(from: defaultValue)!
    if let minimum { initial = max(initial, minimum) }
    if let maximum { initial = min(initial, maximum) }
    let picker = BRDatePickerView(pickerMode: time ? .HM : .YMD)
    picker.title = title
    picker.timeZone = TimeZone(secondsFromGMT: 0)
    picker.calendar = Calendar(identifier: .gregorian)
    picker.minDate = minimum
    picker.maxDate = maximum
    picker.selectDate = initial
    picker.isAutoSelect = false
    picker.keyView = controller.view.window ?? controller.view
    picker.accessibilityIdentifier = "date.picker"
    picker.accessibilityViewIsModal = true
    let style = BRPickerStyle()
    style.language = controller.env.chinese ? "zh-Hans" : "en"
    style.cancelBtnTitle = controller.env.t("Cancel", "取消")
    style.doneBtnTitle = controller.env.t("Confirm", "确定")
    style.titleTextColor = CoastStyle.ink
    style.titleTextFont = CoastStyle.font(17, .semibold)
    style.cancelTextColor = CoastStyle.muted
    style.doneTextColor = CoastStyle.brand
    style.cancelTextFont = CoastStyle.font(16)
    style.doneTextFont = CoastStyle.font(16, .semibold)
    let width = (controller.view.window ?? controller.view).bounds.width
    style.cancelBtnFrame = CGRect(x: 8, y: 0, width: 88, height: 44)
    style.doneBtnFrame = CGRect(x: width - 96, y: 0, width: 88, height: 44)
    style.titleLabelFrame = CGRect(x: 98, y: 0, width: max(0, width - 196), height: 44)
    style.pickerTextColor = CoastStyle.ink
    style.pickerTextFont = CoastStyle.font(20)
    style.selectRowTextColor = CoastStyle.brand
    style.selectRowColor = CoastStyle.inputFill
    style.topCornerRadius = 16
    style.titleBarColor = .white
    style.pickerColor = .white
    picker.pickerStyle = style
    picker.resultBlock = { date, _ in
      guard let date else { return }
      completion(formatter.string(from: date))
    }
    if allowsClear {
      let clear = UIButton(type: .system)
      clear.frame = CGRect(x: 0, y: 0, width: controller.view.bounds.width, height: 44)
      clear.setTitle(controller.env.t("Clear", "清空"), for: .normal)
      clear.setTitleColor(CoastStyle.muted, for: .normal)
      clear.titleLabel?.font = CoastStyle.font(14)
      clear.accessibilityIdentifier = "date.clear"
      clear.addAction(UIAction { [weak picker] _ in
        picker?.dismiss()
        completion("")
      }, for: .touchUpInside)
      picker.pickerFooterView = clear
    }
    picker.show()
  }
}

/// A button styled as the existing field; dates never summon the text keyboard.
final class CoastDateField: UIButton {
  var text: String? { didSet { refresh() } }
  var minimum: (() -> Date?)?
  var maximum: (() -> Date?)?
  private weak var controller: CoastController?
  private let fieldTitle: String
  private let time: Bool
  private let allowsClear: Bool
  init(_ controller: CoastController, title: String, value: String, id: String,
       time: Bool = false, allowsClear: Bool = true) {
    self.controller = controller
    self.fieldTitle = title
    self.time = time
    self.allowsClear = allowsClear
    self.text = value
    super.init(frame: .zero)
    backgroundColor = CoastStyle.inputFill
    layer.cornerRadius = 9
    contentHorizontalAlignment = .leading
    var config = UIButton.Configuration.plain()
    config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
    config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
      var attributes = incoming; attributes.font = CoastStyle.font(14); return attributes
    }
    configuration = config
    heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
    accessibilityLabel = title
    accessibilityIdentifier = id
    refresh()
    addAction(UIAction { [weak self] _ in
      guard let self, let controller = self.controller else { return }
      CoastDatePicker.show(from: controller, title: self.fieldTitle, value: self.text ?? "",
        time: self.time, minimum: self.minimum?(), maximum: self.maximum?(), allowsClear: self.allowsClear
      ) { [weak self] value in
        guard let self else { return }
        self.text = value
        self.sendActions(for: .valueChanged)
      }
    }, for: .touchUpInside)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) unsupported") }
  private func refresh() {
    let value = text ?? ""
    configuration?.title = value.isEmpty ? (time ? "HH:mm" : "YYYY-MM-DD") : value
    configuration?.baseForegroundColor = value.isEmpty ? UIColor(hex: 0x757575) : CoastStyle.ink
    accessibilityValue = value
  }
}
