import Foundation
import IOKit.hid
import OSLog
import T1Protocol

protocol T1HIDInputDelegate: AnyObject {
  func hidInput(_ input: T1HIDInput, didReceive frame: T1Frame, at timestampNanoseconds: UInt64)
  func hidInputDidConnect(_ input: T1HIDInput)
  func hidInputDidDisconnect(_ input: T1HIDInput)
}

final class T1HIDInput {
  private enum Device {
    static let vendorID = 0x04E8
    static let productID = 0x7021
    static let usagePage = 0x0D
    static let usage = 0x05
  }

  private static let reportBufferCapacity = 64

  private let logger = Logger(subsystem: "io.github.arun279.t1plus", category: "hid")
  private weak var delegate: T1HIDInputDelegate?
  private let manager: IOHIDManager
  private let reportBuffer = UnsafeMutablePointer<UInt8>.allocate(
    capacity: T1HIDInput.reportBufferCapacity
  )
  private var activeDevice: IOHIDDevice?
  private var malformedReportCount: UInt64 = 0
  private var started = false

  init(delegate: T1HIDInputDelegate) {
    self.delegate = delegate
    manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
  }

  deinit {
    stop()
    reportBuffer.deallocate()
  }

  func start() -> Bool {
    guard !started else { return true }

    let matching: [String: Any] = [
      kIOHIDVendorIDKey as String: Device.vendorID,
      kIOHIDProductIDKey as String: Device.productID,
      kIOHIDPrimaryUsagePageKey as String: Device.usagePage,
      kIOHIDPrimaryUsageKey as String: Device.usage,
    ]
    let context = Unmanaged.passUnretained(self).toOpaque()
    IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
    IOHIDManagerRegisterDeviceMatchingCallback(manager, t1DeviceMatchedCallback, context)
    IOHIDManagerRegisterDeviceRemovalCallback(manager, t1DeviceRemovedCallback, context)
    IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

    let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    guard result == kIOReturnSuccess else {
      IOHIDManagerUnscheduleFromRunLoop(
        manager,
        CFRunLoopGetMain(),
        CFRunLoopMode.defaultMode.rawValue
      )
      logger.error("Could not open HID manager: \(result, privacy: .public)")
      return false
    }
    started = true
    return true
  }

  func stop() {
    guard started else { return }
    closeActiveDevice()
    IOHIDManagerUnscheduleFromRunLoop(
      manager,
      CFRunLoopGetMain(),
      CFRunLoopMode.defaultMode.rawValue
    )
    IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    started = false
  }

  fileprivate func didMatch(device: IOHIDDevice, result: IOReturn) {
    guard result == kIOReturnSuccess, activeDevice == nil, matchesExpectedIdentity(device) else {
      return
    }

    let openResult = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
    guard openResult == kIOReturnSuccess else {
      logger.error("Could not open matched T1 Plus: \(openResult, privacy: .public)")
      return
    }
    activeDevice = device
    malformedReportCount = 0
    IOHIDDeviceRegisterInputReportCallback(
      device,
      reportBuffer,
      Self.reportBufferCapacity,
      t1InputReportCallback,
      Unmanaged.passUnretained(self).toOpaque()
    )
    delegate?.hidInputDidConnect(self)
  }

  fileprivate func didRemove(device: IOHIDDevice) {
    guard device == activeDevice else { return }
    closeActiveDevice()
    delegate?.hidInputDidDisconnect(self)
  }

  fileprivate func didReceiveReport(
    result: IOReturn,
    type: IOHIDReportType,
    reportID: UInt32,
    report: UnsafeMutablePointer<UInt8>,
    length: CFIndex
  ) {
    guard result == kIOReturnSuccess, type == kIOHIDReportTypeInput else { return }
    let bytes = UnsafeRawBufferPointer(start: report, count: length)
    guard let frame = try? T1ReportDecoder.decode(reportID: reportID, bytes: bytes) else {
      if malformedReportCount == 0 {
        logger.error("Discarding malformed T1 Plus input reports")
      }
      malformedReportCount &+= 1
      return
    }
    delegate?.hidInput(self, didReceive: frame, at: DispatchTime.now().uptimeNanoseconds)
  }

  private func closeActiveDevice() {
    guard let activeDevice else { return }
    IOHIDDeviceClose(activeDevice, IOOptionBits(kIOHIDOptionsTypeNone))
    self.activeDevice = nil
    if malformedReportCount > 0 {
      logger.info(
        "Discarded \(self.malformedReportCount, privacy: .public) malformed input reports"
      )
      malformedReportCount = 0
    }
  }

  private func matchesExpectedIdentity(_ device: IOHIDDevice) -> Bool {
    integerProperty(device, key: kIOHIDVendorIDKey) == Device.vendorID
      && integerProperty(device, key: kIOHIDProductIDKey) == Device.productID
      && integerProperty(device, key: kIOHIDPrimaryUsagePageKey) == Device.usagePage
      && integerProperty(device, key: kIOHIDPrimaryUsageKey) == Device.usage
  }

  private func integerProperty(_ device: IOHIDDevice, key: String) -> Int? {
    IOHIDDeviceGetProperty(device, key as CFString) as? Int
  }
}

private func t1DeviceMatchedCallback(
  context: UnsafeMutableRawPointer?,
  result: IOReturn,
  sender _: UnsafeMutableRawPointer?,
  device: IOHIDDevice
) {
  guard let context else { return }
  Unmanaged<T1HIDInput>.fromOpaque(context).takeUnretainedValue().didMatch(
    device: device,
    result: result
  )
}

private func t1DeviceRemovedCallback(
  context: UnsafeMutableRawPointer?,
  result: IOReturn,
  sender _: UnsafeMutableRawPointer?,
  device: IOHIDDevice
) {
  guard let context, result == kIOReturnSuccess else { return }
  Unmanaged<T1HIDInput>.fromOpaque(context).takeUnretainedValue().didRemove(device: device)
}

private func t1InputReportCallback(
  context: UnsafeMutableRawPointer?,
  result: IOReturn,
  sender _: UnsafeMutableRawPointer?,
  type: IOHIDReportType,
  reportID: UInt32,
  report: UnsafeMutablePointer<UInt8>,
  reportLength: CFIndex
) {
  guard let context else { return }
  Unmanaged<T1HIDInput>.fromOpaque(context).takeUnretainedValue().didReceiveReport(
    result: result,
    type: type,
    reportID: reportID,
    report: report,
    length: reportLength
  )
}
