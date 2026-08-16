import CoreGraphics
import Dispatch
import T1Gestures

final class CGEventOutput: T1GestureActionSink {
  private let source = CGEventSource(stateID: .hidSystemState)
  private var cursor = CGEvent(source: nil)?.location ?? .zero
  private var leftButtonDown = false
  private var rightButtonDown = false
  private var leftClickCount = 1
  private var rightClickCount = 1
  private var momentumX = 0.0
  private var momentumY = 0.0
  private var momentumStarted = false
  private var momentumTimer: DispatchSourceTimer?

  func record(_ action: T1GestureAction) {
    switch action {
    case .pointer(let deltaX, let deltaY, let kind):
      postPointer(deltaX: deltaX, deltaY: deltaY, kind: kind)
    case .button(let button, let phase, let clickCount):
      postButton(button, phase: phase, clickCount: clickCount)
    case .scroll(let deltaX, let deltaY, let phase):
      postScroll(deltaX: deltaX, deltaY: deltaY, phase: phase)
    case .shortcut(let shortcut):
      postShortcut(shortcut)
    }
  }

  func beginInteraction() {
    cancelMomentum(postEnd: true)
    if let currentLocation = CGEvent(source: nil)?.location {
      cursor = currentLocation
    }
  }

  func releaseAllState() {
    cancelMomentum(postEnd: true)
    if leftButtonDown {
      postButton(.left, phase: .released, clickCount: leftClickCount)
    }
    if rightButtonDown {
      postButton(.right, phase: .released, clickCount: rightClickCount)
    }
  }

  private func postPointer(deltaX: Int32, deltaY: Int32, kind: T1PointerKind) {
    cursor.x += CGFloat(deltaX)
    cursor.y += CGFloat(deltaY)
    let eventType: CGEventType
    let button: CGMouseButton
    switch kind {
    case .move:
      eventType = .mouseMoved
      button = .left
    case .leftDrag:
      eventType = .leftMouseDragged
      button = .left
    case .rightDrag:
      eventType = .rightMouseDragged
      button = .right
    }
    guard
      let event = CGEvent(
        mouseEventSource: source,
        mouseType: eventType,
        mouseCursorPosition: cursor,
        mouseButton: button
      )
    else { return }
    event.setIntegerValueField(.mouseEventDeltaX, value: Int64(deltaX))
    event.setIntegerValueField(.mouseEventDeltaY, value: Int64(deltaY))
    event.post(tap: .cghidEventTap)
  }

  private func postButton(_ button: T1Button, phase: T1ButtonPhase, clickCount: Int) {
    let isPressed = phase == .pressed
    let eventType: CGEventType
    let mouseButton: CGMouseButton
    if button == .right {
      eventType = isPressed ? .rightMouseDown : .rightMouseUp
      mouseButton = .right
      rightButtonDown = isPressed
      rightClickCount = clickCount
    } else {
      eventType = isPressed ? .leftMouseDown : .leftMouseUp
      mouseButton = .left
      leftButtonDown = isPressed
      leftClickCount = clickCount
    }
    guard
      let event = CGEvent(
        mouseEventSource: source,
        mouseType: eventType,
        mouseCursorPosition: cursor,
        mouseButton: mouseButton
      )
    else { return }
    event.setIntegerValueField(.mouseEventClickState, value: Int64(clickCount))
    event.post(tap: .cghidEventTap)
  }

  private func postScroll(deltaX: Int32, deltaY: Int32, phase: T1ScrollPhase) {
    let scrollPhase: CGScrollPhase
    switch phase {
    case .began: scrollPhase = .began
    case .changed: scrollPhase = .changed
    case .ended: scrollPhase = .ended
    }
    postScrollEvent(
      deltaX: deltaX,
      deltaY: deltaY,
      scrollPhase: scrollPhase,
      momentumPhase: .none
    )
    if phase == .ended {
      startMomentum()
    } else {
      momentumX = momentumX * 0.55 + Double(deltaX) * 0.45
      momentumY = momentumY * 0.55 + Double(deltaY) * 0.45
    }
  }

  private func postShortcut(_ shortcut: T1Shortcut) {
    let keyAndFlags: (CGKeyCode, CGEventFlags)
    switch shortcut {
    case .missionControl: keyAndFlags = (126, .maskControl)
    case .nextApplication: keyAndFlags = (48, .maskCommand)
    case .notificationCenter: keyAndFlags = (45, .maskSecondaryFn)
    case .previousApplication: keyAndFlags = (48, [.maskCommand, .maskShift])
    case .showDesktop: keyAndFlags = (103, .maskSecondaryFn)
    case .spaceLeft: keyAndFlags = (123, .maskControl)
    case .spaceRight: keyAndFlags = (124, .maskControl)
    case .spotlight: keyAndFlags = (49, .maskCommand)
    case .zoomIn: keyAndFlags = (24, .maskCommand)
    case .zoomOut: keyAndFlags = (27, .maskCommand)
    }
    guard
      let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyAndFlags.0, keyDown: true),
      let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyAndFlags.0, keyDown: false)
    else { return }
    keyDown.flags = keyAndFlags.1
    keyUp.flags = keyAndFlags.1
    keyDown.post(tap: .cghidEventTap)
    keyUp.post(tap: .cghidEventTap)
  }

  private func postScrollEvent(
    deltaX: Int32,
    deltaY: Int32,
    scrollPhase: CGScrollPhase?,
    momentumPhase: CGMomentumScrollPhase
  ) {
    guard
      let event = CGEvent(
        scrollWheelEvent2Source: source,
        units: .pixel,
        wheelCount: 2,
        wheel1: deltaY,
        wheel2: deltaX,
        wheel3: 0
      )
    else { return }
    event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
    event.setIntegerValueField(
      .scrollWheelEventScrollPhase,
      value: Int64(scrollPhase?.rawValue ?? 0)
    )
    event.setIntegerValueField(
      .scrollWheelEventMomentumPhase,
      value: Int64(momentumPhase.rawValue)
    )
    event.post(tap: .cghidEventTap)
  }

  private func startMomentum() {
    guard magnitude(momentumX, momentumY) >= 2 else {
      resetMomentum()
      return
    }
    momentumTimer?.cancel()
    momentumStarted = false
    let timer = DispatchSource.makeTimerSource(queue: .main)
    timer.schedule(deadline: .now() + 1.0 / 60.0, repeating: 1.0 / 60.0, leeway: .milliseconds(2))
    timer.setEventHandler { [weak self] in
      self?.advanceMomentum()
    }
    momentumTimer = timer
    timer.resume()
  }

  private func advanceMomentum() {
    momentumX *= 0.90
    momentumY *= 0.90
    guard abs(momentumX) >= 0.75 || abs(momentumY) >= 0.75 else {
      cancelMomentum(postEnd: true)
      return
    }
    let phase: CGMomentumScrollPhase = momentumStarted ? .continuous : .begin
    momentumStarted = true
    postScrollEvent(
      deltaX: Int32(momentumX.rounded()),
      deltaY: Int32(momentumY.rounded()),
      scrollPhase: nil,
      momentumPhase: phase
    )
  }

  private func cancelMomentum(postEnd: Bool) {
    momentumTimer?.cancel()
    momentumTimer = nil
    if postEnd, momentumStarted {
      postScrollEvent(
        deltaX: 0,
        deltaY: 0,
        scrollPhase: nil,
        momentumPhase: .end
      )
    }
    resetMomentum()
  }

  private func resetMomentum() {
    momentumX = 0
    momentumY = 0
    momentumStarted = false
  }

  private func magnitude(_ x: Double, _ y: Double) -> Double {
    (x * x + y * y).squareRoot()
  }
}
