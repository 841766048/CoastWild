import Foundation
import Network

final class ConnectivityMonitor: @unchecked Sendable {
  private let monitor = NWPathMonitor()
  private let queue = DispatchQueue(label: "com.coastwild.connectivity")
  private let lock = NSLock()
  private var reachable = true
  var onChange: (@MainActor (Bool) -> Void)?

  var isConnected: Bool {
    lock.lock(); defer { lock.unlock() }
    return reachable
  }

  func start() {
    monitor.pathUpdateHandler = { [weak self] path in
      guard let self else { return }
      let value = path.status == .satisfied
      self.lock.lock(); self.reachable = value; self.lock.unlock()
      Task { @MainActor [weak self] in self?.onChange?(value) }
    }
    monitor.start(queue: queue)
  }

  func cancel() { monitor.cancel() }
}
