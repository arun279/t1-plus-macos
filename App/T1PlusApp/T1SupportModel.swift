import AppKit
import Combine
import CoreGraphics
import Foundation
import IOKit.hid
import ServiceManagement
import T1Protocol
import T1Settings

@MainActor
final class T1SupportModel: ObservableObject {
  enum ServiceState {
    case disabled
    case checking
    case enabled
    case unavailable
    case requiresApproval
  }

  @Published private(set) var inputMonitoringGranted = false
  @Published private(set) var eventPostingGranted = false
  @Published private(set) var serviceState = ServiceState.disabled
  @Published private(set) var deviceConnected = false
  @Published private(set) var settings = T1SettingsStore.load()
  @Published private(set) var errorMessage: String?
  @Published private(set) var noticeMessage: String?

  private let service = SMAppService.agent(
    plistName: "io.github.arun279.t1plus.helper.plist"
  )
  private var helperStatusProbe: T1HelperStatusProbe?
  private var relaunchAfterEventPostingRequest = false

  init() {
    refresh()
  }

  var supportEnabled: Bool {
    serviceState != .disabled
  }

  var supportOperational: Bool {
    serviceState == .enabled
  }

  var supportNeedsAttention: Bool {
    serviceState == .unavailable || serviceState == .requiresApproval
  }

  var canEnableSupport: Bool {
    inputMonitoringGranted && eventPostingGranted
  }

  var supportStatus: String {
    switch serviceState {
    case .disabled:
      "Disabled"
    case .checking:
      "Checking"
    case .enabled:
      "Enabled"
    case .unavailable:
      "Needs attention"
    case .requiresApproval:
      "Needs approval"
    }
  }

  func refresh() {
    inputMonitoringGranted =
      IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    eventPostingGranted = CGPreflightPostEventAccess()
    deviceConnected = Self.isDeviceConnected()
    helperStatusProbe?.cancel()
    helperStatusProbe = nil
    switch service.status {
    case .enabled:
      serviceState = .checking
      checkHelperStatus()
    case .requiresApproval:
      serviceState = .requiresApproval
    case .notRegistered, .notFound:
      serviceState = .disabled
    @unknown default:
      serviceState = .disabled
    }
  }

  func requestInputMonitoring() {
    errorMessage = nil
    noticeMessage = nil
    _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    refresh()
  }

  func requestEventPosting() {
    errorMessage = nil
    noticeMessage = nil
    relaunchAfterEventPostingRequest = !CGRequestPostEventAccess()
    refresh()
  }

  func applicationDidBecomeActive() {
    refresh()
    guard relaunchAfterEventPostingRequest, !eventPostingGranted else { return }
    relaunchAfterEventPostingRequest = false
    relaunch()
  }

  func setSupportEnabled(_ enabled: Bool) {
    errorMessage = nil
    noticeMessage = nil
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
    noticeMessage = nil
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
    noticeMessage = nil
    do {
      try T1SettingsStore.save(settings)
    } catch {
      errorMessage = "Settings could not be saved. \(error.localizedDescription)"
    }
  }

  func resetSettings() {
    errorMessage = nil
    noticeMessage = "Touchpad settings restored to defaults."
    T1SettingsStore.reset()
    settings = T1Settings()
  }

  func makeDiagnosticsReport() -> String {
    refresh()
    let generatedAt = ISO8601DateFormatter().string(from: Date())
    let version =
      Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
    let connected = deviceConnected ? "connected" : "not connected"
    let inputMonitoring = inputMonitoringGranted ? "granted" : "not granted"
    let accessibility = eventPostingGranted ? "granted" : "not granted"

    return """
      T1 Plus Touchpad Support Diagnostics
      Generated: \(generatedAt)
      App version: \(version) (\(build))
      macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
      Architecture: \(Self.architecture)
      Device: \(connected)
      Support: \(supportStatus.lowercased())
      Input Monitoring: \(inputMonitoring)
      Accessibility: \(accessibility)
      Backend: CoreGraphics CGEvent
      Settings schema: \(T1Settings.currentVersion)
      Tap to click: \(settings.tapsEnabled)
      Multi-finger gestures: \(settings.gesturesEnabled)
      Reverse scroll direction: \(settings.invertScroll)
      Pointer gain: \(settings.pointerGain)
      Scroll gain: \(settings.scrollGain)
      Raw touch data included: no
      User identity, paths, serial numbers, and logs included: no

      """
  }

  func completeDiagnosticsExport(_ result: Result<URL, any Error>) {
    switch result {
    case .success:
      errorMessage = nil
      noticeMessage = "Diagnostics saved."
    case let .failure(error):
      let cocoaError = error as NSError
      guard
        cocoaError.domain != NSCocoaErrorDomain || cocoaError.code != NSUserCancelledError
      else { return }
      noticeMessage = nil
      errorMessage = "Diagnostics could not be saved. \(error.localizedDescription)"
    }
  }

  func prepareForUninstall() {
    errorMessage = nil
    noticeMessage = nil
    do {
      if service.status == .enabled || service.status == .requiresApproval {
        try service.unregister()
      }
      T1SettingsStore.reset()
      settings = T1Settings()
      refresh()
      noticeMessage =
        "T1 Plus support stopped and app settings reset. Move this app to Trash to finish "
        + "uninstalling. macOS permissions remain until you remove them in System Settings."
    } catch {
      errorMessage = "The app could not prepare for uninstall. \(error.localizedDescription)"
      refresh()
    }
  }

  private func checkHelperStatus() {
    let probe = T1HelperStatusProbe()
    helperStatusProbe = probe
    probe.start { [weak self, weak probe] healthy in
      guard let self, self.helperStatusProbe === probe else { return }
      self.helperStatusProbe = nil
      self.serviceState = healthy ? .enabled : .unavailable
    }
  }

  private func relaunch() {
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true
    configuration.createsNewApplicationInstance = true
    NSWorkspace.shared.openApplication(
      at: Bundle.main.bundleURL,
      configuration: configuration
    ) { _, error in
      Task { @MainActor in
        if let error {
          self.errorMessage =
            "Quit and reopen the app to finish granting Accessibility. "
            + error.localizedDescription
          return
        }
        NSApplication.shared.terminate(nil)
      }
    }
  }

}

private extension T1SupportModel {
  static func isDeviceConnected() -> Bool {
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

  static var architecture: String {
    #if arch(arm64)
      "arm64"
    #elseif arch(x86_64)
      "x86_64"
    #else
      "unknown"
    #endif
  }
}
