import AppKit

final class WorkspaceLifecycleMonitor: NSObject {
  private let onSuspend: (String) -> Void
  private let onResume: (String) -> Void
  private var started = false

  init(onSuspend: @escaping (String) -> Void, onResume: @escaping (String) -> Void) {
    self.onSuspend = onSuspend
    self.onResume = onResume
    super.init()
  }

  deinit {
    NSWorkspace.shared.notificationCenter.removeObserver(self)
  }

  func start() {
    guard !started else { return }
    let center = NSWorkspace.shared.notificationCenter
    center.addObserver(
      self,
      selector: #selector(systemWillSleep(_:)),
      name: NSWorkspace.willSleepNotification,
      object: nil
    )
    center.addObserver(
      self,
      selector: #selector(systemWillPowerOff(_:)),
      name: NSWorkspace.willPowerOffNotification,
      object: nil
    )
    center.addObserver(
      self,
      selector: #selector(sessionDidResign(_:)),
      name: NSWorkspace.sessionDidResignActiveNotification,
      object: nil
    )
    center.addObserver(
      self,
      selector: #selector(systemDidWake(_:)),
      name: NSWorkspace.didWakeNotification,
      object: nil
    )
    center.addObserver(
      self,
      selector: #selector(sessionDidBecomeActive(_:)),
      name: NSWorkspace.sessionDidBecomeActiveNotification,
      object: nil
    )
    started = true
  }

  func stop() {
    guard started else { return }
    NSWorkspace.shared.notificationCenter.removeObserver(self)
    started = false
  }

  @objc private func systemWillSleep(_: Notification) {
    onSuspend("system sleep")
  }

  @objc private func systemWillPowerOff(_: Notification) {
    onSuspend("system power off")
  }

  @objc private func sessionDidResign(_: Notification) {
    onSuspend("session inactive")
  }

  @objc private func systemDidWake(_: Notification) {
    onResume("system wake")
  }

  @objc private func sessionDidBecomeActive(_: Notification) {
    onResume("session active")
  }
}
