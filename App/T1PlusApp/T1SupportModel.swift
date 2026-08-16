import Combine
import CoreGraphics
import IOKit.hid
import ServiceManagement

@MainActor
final class T1SupportModel: ObservableObject {
  enum ServiceState {
    case disabled
    case enabled
    case requiresApproval
  }

  @Published private(set) var inputMonitoringGranted = false
  @Published private(set) var eventPostingGranted = false
  @Published private(set) var serviceState = ServiceState.disabled
  @Published private(set) var errorMessage: String?

  private let service = SMAppService.loginItem(identifier: "io.github.arun279.t1plus.helper")

  init() {
    refresh()
  }

  var supportEnabled: Bool {
    serviceState != .disabled
  }

  var canEnableSupport: Bool {
    inputMonitoringGranted && eventPostingGranted
  }

  func refresh() {
    inputMonitoringGranted =
      IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    eventPostingGranted = CGPreflightPostEventAccess()
    serviceState =
      switch service.status {
      case .enabled:
        .enabled
      case .requiresApproval:
        .requiresApproval
      case .notRegistered, .notFound:
        .disabled
      @unknown default:
        .disabled
      }
  }

  func requestInputMonitoring() {
    errorMessage = nil
    _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    refresh()
  }

  func requestEventPosting() {
    errorMessage = nil
    _ = CGRequestPostEventAccess()
    refresh()
  }

  func setSupportEnabled(_ enabled: Bool) {
    errorMessage = nil
    do {
      if enabled {
        guard canEnableSupport else {
          errorMessage = "Grant both permissions before enabling support."
          return
        }
        guard service.status != .enabled else { return }
        try service.register()
      } else if service.status == .enabled || service.status == .requiresApproval {
        try service.unregister()
      }
      refresh()
    } catch {
      errorMessage =
        enabled
        ? "Support could not be enabled. \(error.localizedDescription)"
        : "Support could not be disabled. \(error.localizedDescription)"
      refresh()
    }
  }

  func openLoginItemSettings() {
    SMAppService.openSystemSettingsLoginItems()
  }
}
