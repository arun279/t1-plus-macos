import CoreGraphics
import Dispatch
import Foundation
import IOKit.hid
import T1Gestures
import T1Protocol
import T1Settings

import struct OSLog.Logger

enum T1HelperStartResult {
  case started
  case permissionDenied
  case failed
}

final class T1HelperRuntime: NSObject, T1HIDInputDelegate {
  private let logger = Logger(subsystem: "io.github.arun279.t1plus", category: "helper")
  private var output = CGEventOutput()
  private lazy var input = T1HIDInput(delegate: self)
  private lazy var lifecycle = WorkspaceLifecycleMonitor(
    onSuspend: { [weak self] reason, description in
      self?.suspendInput(reason, description: description)
    },
    onResume: { [weak self] reason, description in
      self?.resumeInput(reason, description: description)
    }
  )
  private var engine = T1GestureEngine()
  private var inputGate = T1InputGate()
  private var interactionActive = false
  private var settingsObserver: T1SettingsObserver?
  private var signalSources: [DispatchSourceSignal] = []
  private let statusServer = T1HelperStatusServer()
  private var started = false

  func start() -> T1HelperStartResult {
    guard !started else { return .started }
    guard IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted else {
      logger.error("Input Monitoring permission is not granted")
      return .permissionDenied
    }
    guard CGPreflightPostEventAccess() else {
      logger.error("Accessibility event-posting permission is not granted")
      return .permissionDenied
    }
    inputGate = T1InputGate()
    engine.configuration = T1SettingsStore.load().gestureConfiguration
    lifecycle.start()
    guard input.start() else {
      lifecycle.stop()
      return .failed
    }

    settingsObserver = T1SettingsObserver()
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(settingsDidChange),
      name: T1SettingsObserver.changedNotification,
      object: nil
    )
    installSignalSources()
    started = true
    statusServer.start()
    logger.notice("T1 Plus helper started")
    return .started
  }

  func run() {
    CFRunLoopRun()
  }

  func stop() {
    guard started else { return }
    statusServer.stop()
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
    guard inputGate.shouldProcess(hasInteraction: hasInteraction) else { return }
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

  @objc
  private func settingsDidChange(_: Notification) {
    reloadSettings()
  }

  private func reloadSettings() {
    let configuration = T1SettingsStore.load().gestureConfiguration
    guard configuration != engine.configuration else { return }
    inputGate.requireLift(interactionActive: interactionActive)
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

  private func suspendInput(_ reason: T1InputSuspensionReason, description: String) {
    inputGate.suspend(reason, interactionActive: interactionActive)
    releaseOutputState(reason: description)
  }

  private func resumeInput(_ reason: T1InputSuspensionReason, description: String) {
    if inputGate.resume(reason) {
      logger.info("Resumed input after: \(description, privacy: .public)")
    } else {
      logger.info("Input remains suspended after: \(description, privacy: .public)")
    }
  }
}
