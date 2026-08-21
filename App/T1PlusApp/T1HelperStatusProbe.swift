import Foundation

@MainActor
final class T1HelperStatusProbe {
  private let connection = NSXPCConnection(
    machServiceName: T1HelperMachService.name
  )
  private var timeoutTask: Task<Void, Never>?
  private var completion: ((Bool) -> Void)?

  func start(completion: @escaping (Bool) -> Void) {
    self.completion = completion
    connection.remoteObjectInterface = NSXPCInterface(
      with: T1HelperStatusProtocol.self
    )
    connection.interruptionHandler = { [weak self] in
      Task { @MainActor in
        self?.finish(false)
      }
    }
    connection.invalidationHandler = { [weak self] in
      Task { @MainActor in
        self?.finish(false)
      }
    }
    connection.resume()

    guard
      let proxy = connection.remoteObjectProxyWithErrorHandler({ [weak self] _ in
        Task { @MainActor in
          self?.finish(false)
        }
      }) as? T1HelperStatusProtocol
    else {
      finish(false)
      return
    }

    proxy.ping { [weak self] in
      Task { @MainActor in
        self?.finish(true)
      }
    }
    timeoutTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(1))
      guard !Task.isCancelled else { return }
      self?.finish(false)
    }
  }

  func cancel() {
    completion = nil
    invalidate()
  }

  private func finish(_ healthy: Bool) {
    guard let completion else { return }
    self.completion = nil
    invalidate()
    completion(healthy)
  }

  private func invalidate() {
    timeoutTask?.cancel()
    timeoutTask = nil
    connection.interruptionHandler = nil
    connection.invalidationHandler = nil
    connection.invalidate()
  }
}
