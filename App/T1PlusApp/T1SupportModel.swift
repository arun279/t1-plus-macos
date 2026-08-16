import Combine
import CoreGraphics
import IOKit.hid
import ServiceManagement
import T1Protocol
import T1Settings

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
  @Published private(set) var deviceConnected = false
  @Published private(set) var settings = T1SettingsStore.load()
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

  var supportStatus: String {
    switch serviceState {
    case .disabled:
      "Disabled"
    case .enabled:
      "Enabled"
    case .requiresApproval:
      "Needs approval"
    }
  }

  func refresh() {
    inputMonitoringGranted =
      IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    eventPostingGranted = CGPreflightPostEventAccess()
    deviceConnected = Self.isDeviceConnected()
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

  func updateSettings(
    persist: Bool = true,
    _ update: (inout T1Settings) -> Void
  ) {
    errorMessage = nil
    var updated = settings
    update(&updated)
    updated = updated.validated()
    settings = updated
    if persist {
      saveSettings()
    }
  }

  func saveSettings() {
    errorMessage = nil
    do {
      try T1SettingsStore.save(settings)
    } catch {
      errorMessage = "Settings could not be saved. \(error.localizedDescription)"
    }
  }

  func resetSettings() {
    errorMessage = nil
    T1SettingsStore.reset()
    settings = T1Settings()
  }

  private static func isDeviceConnected() -> Bool {
    let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    let matching: [String: Any] = [
      kIOHIDVendorIDKey as String: T1DeviceIdentity.vendorID,
      kIOHIDProductIDKey as String: T1DeviceIdentity.productID,
      kIOHIDPrimaryUsagePageKey as String: T1DeviceIdentity.usagePage,
      kIOHIDPrimaryUsageKey as String: T1DeviceIdentity.usage,
    ]
    IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
    guard let devices = IOHIDManagerCopyDevices(manager) else { return false }
    return CFSetGetCount(devices) > 0
  }
}
