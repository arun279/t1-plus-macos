import AppKit
import T1Gestures

final class WorkspaceLifecycleMonitor: NSObject {
  private let onSuspend: (T1InputSuspensionReason, String) -> Void
  private let onResume: (T1InputSuspensionReason, String) -> Void
  private var started = false

  init(
    onSuspend: @escaping (T1InputSuspensionReason, String) -> Void,
    onResume: @escaping (T1InputSuspensionReason, String) -> Void
  ) {
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
    if Self.currentSessionIsInactive {
      onSuspend(.session, "session inactive at startup")
    }
    started = true
  }

  func stop() {
    guard started else { return }
    NSWorkspace.shared.notificationCenter.removeObserver(self)
    started = false
  }

  @objc
  private func systemWillSleep(_: Notification) {
    onSuspend(.system, "system sleep")
  }

  @objc
  private func systemWillPowerOff(_: Notification) {
    onSuspend(.system, "system power off")
  }

  @objc
  private func sessionDidResign(_: Notification) {
    onSuspend(.session, "session inactive")
  }

  @objc
  private func systemDidWake(_: Notification) {
    onResume(.system, "system wake")
  }

  @objc
  private func sessionDidBecomeActive(_: Notification) {
    onResume(.session, "session active")
  }

  private static var currentSessionIsInactive: Bool {
    guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
    return session[kCGSessionOnConsoleKey as String] as? Bool == false
  }
}
