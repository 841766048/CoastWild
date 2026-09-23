import UIKit

final class CoinWalletController: CoinScreen {
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    Task { [weak self] in
      guard let self else { return }
      do { render(try await env.coinWallet.snapshot()) }
      catch { showCoinError(error) }
    }
  }
  private func render(_ state: CoinWalletSnapshot) {
    reset(); title = nil
    add(CoinStyle.text("My coins", 34, .bold))
    let balance = CoinStyle.row([CoinArtwork.coin(74), CoinStyle.column([
      CoinStyle.text(String(state.balance), 56, .bold),
      CoinStyle.text("Available coins", 17, color: CoastStyle.muted)
    ], spacing: 0), UIView()])
    let topUp = CoinStyle.button("Get coins", id: "coins.top-up") { [weak self] in
      guard let self else { return }; push(CoinPurchaseController(env))
    }
    add(CoinScenicPanel(content: CoinStyle.panel([balance, topUp], fill: .clear)))
    let row = CoinStyle.panel([CoinStyle.row([CoinStyle.symbol("book", size: 26),
      CoinStyle.text("Unlocked guides", 18, .medium), UIView(), CoinStyle.symbol("chevron.right", size: 16, color: CoastStyle.muted)])])
    add(CoinStyle.tappable(row, id: "coins.unlocked-guides", label: "Unlocked guides") { [weak self] in
      guard let self else { return }
      if let learn = navigationController?.viewControllers.first(where: { $0 is LearnController }) as? LearnController {
        learn.unlockedOnly = true
        navigationController?.popToViewController(learn, animated: true)
      }
    })
    add(CoinStyle.text("Activity", 25, .bold))
    if state.entries.isEmpty {
      add(CoinStyle.panel([CoinStyle.text("No activity yet", 17, .semibold),
        CoinStyle.text("Your purchases and guide unlocks will appear here.", 15, color: CoastStyle.muted)]))
    } else {
      let date = DateFormatter(); date.locale = Locale(identifier: "en_US"); date.dateStyle = .medium
      let rows = state.entries.map { entry -> UIView in
        let positive = entry.amount > 0
        return CoinStyle.row([
          positive ? CoinArtwork.coin(34) : CoinStyle.symbol("book", size: 34),
          CoinStyle.column([
            CoinStyle.text(positive ? "Coins added" : entry.title, 17, .medium),
            CoinStyle.text((positive ? "App Store purchase" : "Guide unlocked") + " · " +
                           (Calendar.current.isDateInToday(entry.date) ? "Today" : date.string(from: entry.date)),
                           12, color: CoastStyle.muted)
          ], spacing: 5),
          UIView(),
          CoinStyle.text((positive ? "+" : "") + String(entry.amount), 22, .semibold,
                         color: positive ? CoastStyle.brand : CoastStyle.ink)
        ])
      }
      var content: [UIView] = []
      for row in rows { if !content.isEmpty { content.append(CoinStyle.separator()) }; content.append(row) }
      add(CoinStyle.panel(content))
    }
    add(CoinStyle.text("Coins unlock guides in Coast & Wild. Balance and unlocks are stored on this device only.", 14, color: CoastStyle.muted))
    add(CoinStyle.link("Purchase help") { [weak self] in self?.showPurchaseHelp() })
  }
}

extension CoinScreen {
  func showPurchaseHelp() {
    message("Purchase help",
      "Payment is handled by Apple. Coins are added only after verification. If a payment is still confirming, do not buy again; return to Get coins and tap Check again.\n\nCoins and unlocked guides are stored on this device, shared by the native app on this installation. They are not synced to another device or guaranteed after reinstalling. Consumable coins are not replenished by Restore Purchases. Keep the app installed if you need help with a pending payment.")
  }
}
