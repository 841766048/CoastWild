import UIKit

final class LearnController: CoinScreen {
  var unlockedOnly = false
  override func viewDidLoad() { super.viewDidLoad(); render(balance: nil, owned: false) }
  override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); refresh() }
  func refresh() {
    Task { [weak self] in
      guard let self else { return }
      do {
        let state = try await env.coinWallet.snapshot()
        render(balance: state.balance, owned: state.unlockedGuideIDs.contains(CoinGuide.id))
      } catch { showCoinError(error) }
    }
  }
  private func render(balance: Int?, owned: Bool) {
    reset()
    let brand = CoinStyle.row([CoinStyle.symbol("water.waves", size: 32, color: CoinStyle.gold),
                               CoinStyle.text("Coast & Wild", 20, .semibold), UIView()])
    let wallet = CoinStyle.link(balance.map(String.init) ?? "—", id: "coins.wallet") { [weak self] in
      guard let self else { return }; push(CoinWalletController(env))
    }
    wallet.setImage(UIImage(systemName: "circle.circle"), for: .normal)
    wallet.tintColor = CoinStyle.gold
    wallet.accessibilityLabel = "My coins, \(balance ?? 0)"
    brand.addArrangedSubview(wallet)
    add(brand)
    add(CoinStyle.text("Learn", 42, .bold))
    add(CoinStyle.text("Skills for your next escape.", 19, .medium, color: CoastStyle.muted))
    let segments = UISegmentedControl(items: ["All guides", "Unlocked"])
    segments.selectedSegmentIndex = unlockedOnly ? 1 : 0
    segments.selectedSegmentTintColor = CoastStyle.brand
    segments.setTitleTextAttributes([.foregroundColor: UIColor.white, .font: CoastStyle.font(15, .semibold)], for: .selected)
    segments.setTitleTextAttributes([.foregroundColor: CoastStyle.muted, .font: CoastStyle.font(15)], for: .normal)
    segments.heightAnchor.constraint(equalToConstant: 40).isActive = true
    segments.addAction(UIAction { [weak self] _ in
      guard let self else { return }
      unlockedOnly = segments.selectedSegmentIndex == 1
      render(balance: balance, owned: owned)
    }, for: .valueChanged)
    add(segments)
    if !unlockedOnly || owned {
      let caption = CoinStyle.panel([
        CoinStyle.row([CoinStyle.text(CoinGuide.title, 24, .bold), UIView(),
                       CoinStyle.symbol(owned ? "checkmark.seal.fill" : "lock.fill", size: 18, color: CoastStyle.muted)]),
        CoinStyle.row([CoinStyle.text("4 chapters · 20 min", 16, color: CoastStyle.muted), UIView(),
                       CoinStyle.text(owned ? "Unlocked" : "30 coins", 15, .medium, color: owned ? CoastStyle.brand : CoinStyle.gold)])
      ])
      caption.layer.borderWidth = 0
      let content = CoinStyle.column([CoinArtwork.view("coast", height: 225, rounded: false), caption], spacing: 0)
      content.layer.cornerRadius = 16; content.clipsToBounds = true
      content.layer.borderColor = CoinStyle.border.cgColor; content.layer.borderWidth = 0.7
      add(CoinStyle.tappable(content, id: "coins.guide.coastal-camping", label: "Coastal Camping, " + (owned ? "Unlocked" : "30 coins")) { [weak self] in
        guard let self else { return }
        push(CoinGuideController(env))
      })
    } else {
      add(CoinStyle.panel([CoinStyle.text("Your next chapter awaits", 21, .bold),
        CoinStyle.text("Guides you unlock will appear here. Explore a preview before you choose.", 16, color: CoastStyle.muted)]))
    }
    if !unlockedOnly {
      let photo = CoinArtwork.view("trail", height: 88)
      photo.widthAnchor.constraint(equalToConstant: 100).isActive = true
      let card = CoinStyle.panel([CoinStyle.row([photo,
        CoinStyle.column([CoinStyle.text("Trail essentials", 18, .bold),
                          CoinStyle.text("Free learning library", 14, color: CoastStyle.muted)], spacing: 5),
        CoinStyle.symbol("chevron.right", size: 16, color: CoastStyle.muted)])])
      add(CoinStyle.tappable(card, id: "coins.free-library", label: "Free learning library") { [weak self] in
        guard let self else { return }; push(FreeLearnController(env))
      })
    }
    let footnote = CoinStyle.text("Your unlocked guides stay on this device.", 13, color: CoastStyle.muted)
    footnote.textAlignment = .center; add(footnote)
  }
}

final class CoinGuideController: CoinScreen {
  private var owned = false
  private var chapter = 0
  private var preview = false
  private var busy = false
  override func viewDidLoad() { super.viewDidLoad(); renderDetail(balance: nil) }
  override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); refresh() }
  private func refresh() {
    Task { [weak self] in
      guard let self else { return }
      do {
        let state = try await env.coinWallet.snapshot()
        owned = state.unlockedGuideIDs.contains(CoinGuide.id)
        if owned { renderReading() } else if !preview { renderDetail(balance: state.balance) }
      } catch { showCoinError(error) }
    }
  }
  private func renderDetail(balance: Int?) {
    reset(); title = nil
    stack.spacing = 14
    navigationItem.rightBarButtonItem = UIBarButtonItem(title: balance.map { "◉ \($0)" } ?? "—",
      primaryAction: UIAction { [weak self] _ in
        guard let self else { return }; push(CoinWalletController(env))
      })
    add(CoinArtwork.fullBleed("coast", height: 188))
    add(CoinStyle.text(CoinGuide.title, 32, .bold))
    add(CoinStyle.text("4 chapters · 20 min", 16, color: CoastStyle.muted))
    add(CoinStyle.text("Build a calmer camp by the sea, from choosing a spot to packing out.", 16, color: CoastStyle.muted))
    add(CoinStyle.text("Inside this guide", 23, .bold))
    for (index, item) in CoinGuide.chapters.enumerated() {
      let number = CoinStyle.text("\(index + 1)", 19, .semibold, color: CoastStyle.brand)
      number.textAlignment = .center
      number.widthAnchor.constraint(equalToConstant: 32).isActive = true
      number.heightAnchor.constraint(equalToConstant: 32).isActive = true
      number.backgroundColor = CoastStyle.field; number.layer.cornerRadius = 16; number.clipsToBounds = true
      let row = CoinStyle.panel([CoinStyle.row([number, CoinStyle.text(item.title, 14, .medium),
        index == 0 ? CoinStyle.text("Preview", 13, .medium, color: CoastStyle.brand)
          : CoinStyle.symbol("lock", size: 17, color: CoastStyle.muted)])])
      row.layoutMargins = UIEdgeInsets(top: 9, left: 12, bottom: 9, right: 12)
      add(CoinStyle.tappable(row, id: "coins.chapter.\(index)", label: item.title + (index == 0 ? ", Preview" : ", Locked")) { [weak self] in
        guard let self else { return }
        if index == 0 { preview = true; chapter = 0; renderReading() } else { requestUnlock() }
      })
      stack.setCustomSpacing(8, after: stack.arrangedSubviews.last!)
    }
    let note = CoinStyle.text("One-time unlock · 30 coins", 14, color: CoastStyle.muted)
    note.textAlignment = .center
    pinFooter(CoinStyle.column([note, CoinStyle.button("Unlock for 30 coins", id: "coins.unlock") { [weak self] in self?.requestUnlock() }]))
  }
  private func requestUnlock() {
    guard !busy else { return }; busy = true
    Task { [weak self] in
      guard let self else { return }; defer { busy = false }
      do {
        let state = try await env.coinWallet.snapshot()
        if state.unlockedGuideIDs.contains(CoinGuide.id) { owned = true; preview = false; renderReading(); return }
        let enough = state.balance >= CoinGuide.price
        let sheet = CoinUnlockSheet(balance: state.balance, enough: enough) { [weak self] in
          guard let self else { return }
          if enough { confirmUnlock() }
          else { push(CoinPurchaseController(env, fromGuide: true)) }
        }
        present(sheet, animated: !UIAccessibility.isReduceMotionEnabled)
      } catch { showCoinError(error) }
    }
  }
  private func confirmUnlock() {
    guard !busy else { return }; busy = true
    Task { [weak self] in
      guard let self else { return }; defer { busy = false }
      do {
        try await env.coinWallet.unlock(guideID: CoinGuide.id)
        owned = true; preview = false; chapter = 0
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        renderReading(); scroll.setContentOffset(.zero, animated: false)
      } catch { showCoinError(error) }
    }
  }
  private func renderReading() {
    guard owned || preview else { return }
    if preview { chapter = 0 }
    reset(); title = nil
    stack.spacing = 14
    navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "list.bullet"),
      primaryAction: UIAction { [weak self] _ in self?.showContents() })
    navigationItem.rightBarButtonItem?.accessibilityLabel = "Chapters"
    let badge = CoinStyle.text(owned ? "✓  Unlocked" : "Preview", 14, .semibold, color: CoastStyle.brand)
    add(badge)
    add(CoinStyle.text(CoinGuide.title, 32, .bold))
    add(CoinStyle.text("CHAPTER \(chapter + 1) OF 4", 12, .medium, color: CoastStyle.muted))
    add(CoinArtwork.view("coast", height: 180))
    let value = CoinGuide.chapters[chapter]
    add(CoinStyle.text(value.title, 25, .bold))
    value.paragraphs.forEach { add(CoinStyle.text($0, 16, color: CoastStyle.muted)) }
    add(CoinStyle.panel([CoinStyle.text(value.tipTitle, 17, .semibold), CoinStyle.text(value.tip, 15, color: CoastStyle.muted)], fill: CoinStyle.surface))
    let count = CoinStyle.text("\(chapter + 1) / 4", 14, color: CoastStyle.muted); count.textAlignment = .center
    pinFooter(CoinStyle.column([count, CoinStyle.button(owned ? (chapter == 3 ? "Finish guide" : "Next chapter") : "Unlock for 30 coins",
      id: owned ? "coins.next-chapter" : "coins.unlock") { [weak self] in
        guard let self else { return }
        if !owned { requestUnlock() }
        else if chapter == 3 { navigationController?.popViewController(animated: true) }
        else { chapter += 1; renderReading(); scroll.setContentOffset(.zero, animated: false) }
      }]))
  }
  private func showContents() {
    let alert = UIAlertController(title: "Chapters", message: nil, preferredStyle: .actionSheet)
    for (index, item) in CoinGuide.chapters.enumerated() {
      alert.addAction(UIAlertAction(title: item.title, style: .default) { [weak self] _ in
        guard let self else { return }
        if owned || index == 0 { chapter = index; renderReading(); scroll.setContentOffset(.zero, animated: false) }
        else { requestUnlock() }
      })
    }
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
    present(alert, animated: true)
  }
}

private final class CoinUnlockSheet: UIViewController {
  let balance: Int
  let enough: Bool
  let action: () -> Void
  init(balance: Int, enough: Bool, action: @escaping () -> Void) {
    self.balance = balance; self.enough = enough; self.action = action
    super.init(nibName: nil, bundle: nil)
    modalPresentationStyle = .pageSheet
    if let sheet = sheetPresentationController {
      sheet.detents = [.custom(identifier: .init("coin-confirmation")) { context in min(470, context.maximumDetentValue) }, .large()]
      sheet.prefersGrabberVisible = true; sheet.preferredCornerRadius = 24
    }
  }
  required init?(coder: NSCoder) { fatalError() }
  override func viewDidLoad() {
    super.viewDidLoad(); view.backgroundColor = CoinStyle.background
    let scroll = UIScrollView(); scroll.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(scroll)
    let title = CoinStyle.text(enough ? "Unlock this guide?" : "A few more coins", 27, .bold)
    title.textAlignment = .center
    let subtitle = CoinStyle.text(enough ? CoinGuide.title : "Add coins to unlock Coastal Camping.", 16, color: CoastStyle.muted)
    subtitle.textAlignment = .center
    let art = CoinStyle.row([UIView(), CoinArtwork.coin(48), UIView()])
    art.arrangedSubviews.first!.widthAnchor.constraint(equalTo: art.arrangedSubviews.last!.widthAnchor).isActive = true
    let detail = CoinStyle.panel([
      CoinStyle.value("Your balance", "\(balance) coins"), CoinStyle.separator(),
      CoinStyle.value("Guide cost", "30 coins"), CoinStyle.separator(),
      CoinStyle.value(enough ? "After unlocking" : "You need",
        enough ? "\(balance - 30) coins" : "\(30 - balance) more coins",
        color: enough ? CoastStyle.ink : CoinStyle.gold)
    ], fill: CoinStyle.surface)
    let note = CoinStyle.text(enough ? "Unlock once. Read again on this device." : "After adding coins, return here to confirm your unlock.", 14, color: CoastStyle.muted)
    note.textAlignment = .center
    let confirm = CoinStyle.button(enough ? "Confirm unlock" : "Get coins",
      id: enough ? "coins.confirm-unlock" : "coins.top-up") { [weak self] in
        guard let self else { return }
        dismiss(animated: true, completion: action)
      }
    let cancel = CoinStyle.link("Not now") { [weak self] in self?.dismiss(animated: true) }
    let stack = CoinStyle.column([art, title, subtitle, detail, note, confirm, cancel], spacing: 12)
    stack.translatesAutoresizingMaskIntoConstraints = false; scroll.addSubview(stack)
    NSLayoutConstraint.activate([
      scroll.topAnchor.constraint(equalTo: view.topAnchor, constant: 26),
      scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
      stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
      stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -8),
      stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 20),
      stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -20),
      stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40)
    ])
  }
}
