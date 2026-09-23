import UIKit

final class CoinPurchaseController: CoinScreen {
  private let fromGuide: Bool
  private var monitor: Task<Void, Never>?
  private var renderedState: NativeCoinPurchaseModel.State?
  private var renderedPrice: String?
  private var shownNotice: NativeCoinPurchaseModel.State?
  private var model: NativeCoinPurchaseModel { env.nativeCoins }
  init(_ env: CoastEnvironment, fromGuide: Bool = false) {
    self.fromGuide = fromGuide
    super.init(env)
  }
  required init?(coder: NSCoder) { fatalError() }
  override func viewDidLoad() {
    super.viewDidLoad()
    render()
    Task { [weak self] in
      guard let self else { return }
      await model.loadProduct()
      render()
    }
  }
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    monitor?.cancel()
    monitor = Task { [weak self] in
      while !Task.isCancelled {
        guard let self else { return }
        await model.refreshPending()
        if renderedState != model.state || renderedPrice != model.product?.displayPrice { render() }
        do { try await Task.sleep(nanoseconds: 400_000_000) } catch { return }
      }
    }
  }
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    monitor?.cancel(); monitor = nil
  }
  deinit { monitor?.cancel() }

  private func render() {
    reset()
    renderedState = model.state; renderedPrice = model.product?.displayPrice
    navigationItem.rightBarButtonItem = nil
    switch model.state {
    case .succeeded: renderSuccess()
    case .confirming, .awaitingApproval, .purchasing: renderProgress()
    default: renderPurchase()
    }
    switch model.state {
    case .cancelled where shownNotice != model.state:
      shownNotice = model.state
      message("Purchase cancelled", "You haven’t been charged and no coins were added.")
      model.acknowledge()
    case let .failed(text) where shownNotice != model.state:
      shownNotice = model.state
      message("Purchase unavailable", text)
    default: break
    }
  }
  private func renderPurchase() {
    title = nil
    navigationItem.hidesBackButton = false
    add(CoinStyle.text("Get coins", 34, .bold))
    add(CoinStyle.text("A little extra for your next adventure.", 18, color: CoastStyle.muted))
    add(CoinArtwork.fullBleed("purchase", height: 200))
    let pack = CoinStyle.panel([CoinStyle.row([
      CoinArtwork.coin(64),
      CoinStyle.column([CoinStyle.text("100 coins", 21, .bold),
                        CoinStyle.text("One-time purchase", 14, color: CoastStyle.muted)], spacing: 4),
      UIView(),
      CoinStyle.text(model.product?.displayPrice ?? "—", 21, .medium),
      CoinStyle.symbol("checkmark.circle.fill", size: 28)
    ])])
    pack.layer.borderColor = CoastStyle.brand.cgColor; pack.layer.borderWidth = 1
    add(pack)
    add(CoinStyle.panel([
      CoinStyle.text("Make room for a new skill", 17, .semibold),
      CoinStyle.text("Use coins to unlock outdoor guides. An unlocked guide can be read again on this device.", 15, color: CoastStyle.muted)
    ], fill: CoinStyle.surface))
    if let error = model.productError {
      add(CoinStyle.text(error, 15, color: CoastStyle.red))
      add(CoinStyle.link("Try again", id: "coins.retry-price") { [weak self] in
        guard let self else { return }
        Task { await self.model.loadProduct(); self.render() }
      })
    }
    add(CoinStyle.link("Purchase help") { [weak self] in self?.showPurchaseHelp() })
    let buy = CoinStyle.button(model.product.map { "Buy for \($0.displayPrice)" } ?? "Loading App Store price…",
      id: "coins.buy") { [weak self] in
        guard let self else { return }; shownNotice = nil; model.purchase(); render()
      }
    buy.isEnabled = model.product != nil; buy.alpha = buy.isEnabled ? 1 : 0.5
    let payment = CoinStyle.text("Payment confirmed by Apple.", 12, color: CoastStyle.muted)
    payment.textAlignment = .center
    let legal = CoinStyle.row([
      UIView(),
      CoinStyle.link("Terms") { [weak self] in guard let self else { return }; push(LegalWebController(env, document: .terms)) },
      CoinStyle.text("|", 13, color: CoastStyle.muted),
      CoinStyle.link("Privacy") { [weak self] in guard let self else { return }; push(LegalWebController(env, document: .privacy)) },
      UIView()
    ], spacing: 10)
    legal.arrangedSubviews.first!.widthAnchor.constraint(equalTo: legal.arrangedSubviews.last!.widthAnchor).isActive = true
    pinFooter(CoinStyle.column([buy, payment, legal], spacing: 8))
  }
  private var returnTitle: String { fromGuide ? "Back to guide" : "Back to My coins" }
  private func returnToOrigin() {
    model.acknowledge()
    navigationController?.popViewController(animated: true)
  }
  private func renderProgress() {
    title = "Purchase status"
    let confirming = model.state == .confirming
    let approval = model.state == .awaitingApproval
    let coin = CoinArtwork.coin(90)
    let spinner = UIActivityIndicatorView(style: .large); spinner.color = CoastStyle.brand; spinner.startAnimating()
    let art = CoinStyle.column([coin, spinner], spacing: 12); art.alignment = .center
    add(art)
    let heading = CoinStyle.text(confirming ? "Confirming your coins" : (approval ? "Waiting for approval" : "Continue with Apple"), 29, .bold)
    heading.textAlignment = .center; add(heading)
    let body = CoinStyle.text(confirming
      ? "Your payment was received. We’re checking your purchase. Please don’t buy again."
      : (approval ? "Apple is waiting for approval. Coins will be added after the purchase is approved and verified."
        : "Complete your purchase in Apple’s payment sheet. No coins are added until payment is verified."),
      17, color: CoastStyle.muted)
    body.textAlignment = .center; add(body)
    add(CoinStyle.panel([
      progressRow(confirming ? "checkmark.circle.fill" : "circle", "Payment received", confirming ? "Received" : "Waiting for Apple"),
      progressRow("circle.inset.filled", "Confirming purchase", confirming ? "In progress…" : "Waiting"),
      progressRow("circle", "Coins added", "Pending")
    ]))
    add(CoinStyle.panel([CoinStyle.text("You can leave this page.", 17, .semibold),
      CoinStyle.text("Unfinished payments are checked again when the app opens. Keep this app installed.", 15, color: CoastStyle.muted)], fill: CoastStyle.field))
    if confirming {
      add(CoinStyle.link("Check again", id: "coins.retry-verification") { [weak self] in self?.model.retryVerification() })
    }
    pinFooter(CoinStyle.column([
      CoinStyle.button(returnTitle, id: "coins.return") { [weak self] in self?.returnToOrigin() },
      CoinStyle.link("Purchase help") { [weak self] in self?.showPurchaseHelp() }
    ], spacing: 6))
  }
  private func progressRow(_ symbol: String, _ title: String, _ subtitle: String) -> UIView {
    CoinStyle.row([CoinStyle.symbol(symbol, size: 26),
      CoinStyle.column([CoinStyle.text(title, 18, .semibold),
                        CoinStyle.text(subtitle, 14, color: CoastStyle.muted)], spacing: 4)])
  }
  private func renderSuccess() {
    title = "Purchase complete"
    navigationItem.hidesBackButton = true
    navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in self?.returnToOrigin() })
    add(CoinArtwork.view("success", height: 185, rounded: false))
    let heading = CoinStyle.text("Your coins are ready", 28, .bold); heading.textAlignment = .center; add(heading)
    let amount = CoinStyle.text("+100", 64, .bold, color: CoastStyle.brand); amount.textAlignment = .center; add(amount)
    let subtitle = CoinStyle.text("coins added", 20); subtitle.textAlignment = .center; add(subtitle)
    var summary: [UIView] = [CoinStyle.value("Coin pack", "100 coins")]
    // A recovered transaction may have a historical price different from today's product price.
    summary.append(CoinStyle.separator())
    summary.append(CoinStyle.value("Status", "Completed", color: CoastStyle.brand))
    add(CoinStyle.panel(summary))
    add(CoinStyle.text(fromGuide ? "Return to your guide to confirm the unlock. No coins have been spent yet." : "Your coins are ready to unlock a guide.", 15, color: CoastStyle.muted))
    pinFooter(CoinStyle.column([
      CoinStyle.button(returnTitle, id: "coins.return") { [weak self] in self?.returnToOrigin() },
      CoinStyle.link("Purchase help") { [weak self] in self?.showPurchaseHelp() }
    ], spacing: 6))
  }
}
