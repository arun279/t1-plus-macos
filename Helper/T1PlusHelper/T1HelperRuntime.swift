import CoreGraphics
import Dispatch
import Foundation
import IOKit.hid
import T1Gestures
import T1Protocol
import T1Settings

import struct OSLog.Logger

final class T1HelperRuntime: NSObject, T1HIDInputDelegate {
  private let logger = Logger(subsystem: "io.github.arun279.t1plus", category: "helper")
  private var output = CGEventOutput()
  private lazy var input = T1HIDInput(delegate: self)
  private lazy var lifecycle = WorkspaceLifecycleMonitor(
    onSuspend: { [weak self] reason in
      self?.suspendInput(reason: reason)
    },
    onResume: { [weak self] reason in
      self?.resumeInput(reason: reason)
    }
  )
  private var engine = T1GestureEngine()
  private var interactionActive = false
  private var inputSuspended = false
  private var requiresLiftBeforeInput = false
  private var settingsObserver: T1SettingsObserver?
  private var signalSources: [DispatchSourceSignal] = []
  private var started = false

  func start() -> Bool {
    guard !started else { return true }
    guard IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted else {
      logger.error("Input Monitoring permission is not granted")
      return false
    }
    guard CGPreflightPostEventAccess() else {
      logger.error("Accessibility event-posting permission is not granted")
      return false
    }
    inputSuspended = false
    requiresLiftBeforeInput = false
    engine.configuration = T1SettingsStore.load().gestureConfiguration
    guard input.start() else { return false }

    settingsObserver = T1SettingsObserver()
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(settingsDidChange),
      name: T1SettingsObserver.changedNotification,
      object: nil
    )
    lifecycle.start()
    installSignalSources()
    started = true
    logger.notice("T1 Plus helper started")
    return true
  }

  func run() {
    CFRunLoopRun()
  }

  func stop() {
    guard started else { return }
    NotificationCenter.default.removeObserver(
      self,
      name: T1SettingsObserver.changedNotification,
      object: nil
    )
    settingsObserver = nil
    input.stop()
    releaseOutputState(reason: "helper stop")
    lifecycle.stop()
    signalSources.forEach { $0.cancel() }
    signalSources.removeAll(keepingCapacity: false)
    started = false
    logger.notice("T1 Plus helper stopped")
  }

  func hidInput(_: T1HIDInput, didReceive frame: T1Frame, at timestampNanoseconds: UInt64) {
    let hasInteraction = frame.activeContactCount > 0 || frame.isPrimaryButtonPressed
    if inputSuspended {
      requiresLiftBeforeInput = hasInteraction
      return
    }
    if requiresLiftBeforeInput {
      requiresLiftBeforeInput = hasInteraction
      return
    }
    if hasInteraction, !interactionActive {
      output.beginInteraction()
    }
    engine.process(frame, at: timestampNanoseconds, into: &output)
    interactionActive = hasInteraction
  }

  func hidInputDidConnect(_: T1HIDInput) {
    logger.notice("T1 Plus connected")
  }

  func hidInputDidDisconnect(_: T1HIDInput) {
    releaseOutputState(reason: "device disconnect")
    logger.notice("T1 Plus disconnected; waiting for reconnection")
  }

  private func installSignalSources() {
    for signalNumber in [SIGINT, SIGTERM] {
      signal(signalNumber, SIG_IGN)
      let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
      source.setEventHandler { [weak self] in
        self?.requestStop()
      }
      source.resume()
      signalSources.append(source)
    }
  }

  private func requestStop() {
    stop()
    CFRunLoopStop(CFRunLoopGetMain())
  }

  @objc private func settingsDidChange(_: Notification) {
    reloadSettings()
  }

  private func reloadSettings() {
    let configuration = T1SettingsStore.load().gestureConfiguration
    guard configuration != engine.configuration else { return }
    requiresLiftBeforeInput = interactionActive
    releaseOutputState(reason: "settings changed")
    engine.configuration = configuration
    logger.notice("T1 Plus settings reloaded")
  }

  private func releaseOutputState(reason: String) {
    engine.cancel(at: DispatchTime.now().uptimeNanoseconds, into: &output)
    output.releaseAllState()
    interactionActive = false
    logger.info("Released output state: \(reason, privacy: .public)")
  }

  private func suspendInput(reason: String) {
    inputSuspended = true
    requiresLiftBeforeInput = interactionActive
    releaseOutputState(reason: reason)
  }

  private func resumeInput(reason: String) {
    inputSuspended = false
    logger.info("Resumed input after: \(reason, privacy: .public)")
  }
}
