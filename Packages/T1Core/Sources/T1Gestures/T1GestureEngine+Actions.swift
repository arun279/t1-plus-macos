extension T1GestureEngine {
  mutating func emitTap<Sink: T1GestureActionSink>(
    _ button: T1Button,
    at timestampNanoseconds: UInt64,
    sink: inout Sink
  ) {
    var clickCount = 1
    if button == .left, isNearLastTap(at: timestampNanoseconds) {
      clickCount = 2
      lastTap = nil
    } else if button == .left {
      lastTap = TapRecord(
        timestampNanoseconds: timestampNanoseconds,
        cursorX: logicalCursorX,
        cursorY: logicalCursorY
      )
    }
    emitButton(button, phase: .down, clickCount: clickCount, sink: &sink)
    emitButton(button, phase: .up, clickCount: clickCount, sink: &sink)
  }

  func isNearLastTap(at timestampNanoseconds: UInt64) -> Bool {
    guard let lastTap else { return false }
    return elapsedSeconds(from: lastTap.timestampNanoseconds, to: timestampNanoseconds) < 0.48
      && magnitude(logicalCursorX - lastTap.cursorX, logicalCursorY - lastTap.cursorY) < 28
  }

  func emitButton<Sink: T1GestureActionSink>(
    _ button: T1Button,
    phase: T1ButtonPhase,
    clickCount: Int,
    sink: inout Sink
  ) {
    sink.record(.button(button, phase: phase, clickCount: clickCount))
  }

  mutating func emitPointer<Sink: T1GestureActionSink>(
    deltaX: Double,
    deltaY: Double,
    sink: inout Sink
  ) {
    let speed = magnitude(deltaX, deltaY)
    guard speed >= 0.75 else { return }

    let acceleration = 0.58 + min(speed / 10, 1.72)
    pointerRemainderX += deltaX * configuration.pointerGain * acceleration
    pointerRemainderY += deltaY * configuration.pointerGain * acceleration
    let outputX = Int32(pointerRemainderX.rounded(.towardZero))
    let outputY = Int32(pointerRemainderY.rounded(.towardZero))
    pointerRemainderX -= Double(outputX)
    pointerRemainderY -= Double(outputY)
    guard outputX != 0 || outputY != 0 else { return }
    logicalCursorX += Double(outputX)
    logicalCursorY += Double(outputY)

    let kind: T1PointerKind
    if physicalButtonDown {
      kind = physicalButton == .left ? .leftDrag : .rightDrag
    } else if tapDragDown {
      kind = .leftDrag
    } else {
      kind = .move
    }
    sink.record(.pointer(deltaX: outputX, deltaY: outputY, kind: kind))
  }

  mutating func emitScroll<Sink: T1GestureActionSink>(
    deltaX: Double,
    deltaY: Double,
    sink: inout Sink
  ) {
    let direction = configuration.invertScroll ? -1.0 : 1.0
    scrollRemainderX += deltaX * configuration.scrollGain * direction
    scrollRemainderY += deltaY * configuration.scrollGain * direction
    let outputX = Int32(scrollRemainderX.rounded(.towardZero))
    let outputY = Int32(scrollRemainderY.rounded(.towardZero))
    scrollRemainderX -= Double(outputX)
    scrollRemainderY -= Double(outputY)
    guard outputX != 0 || outputY != 0 else { return }

    let phase: T1ScrollPhase = interaction.scrollStarted ? .changed : .began
    interaction.scrollStarted = true
    sink.record(.scroll(deltaX: outputX, deltaY: outputY, phase: phase))
  }

  func emitSwipe<Sink: T1GestureActionSink>(sink: inout Sink) {
    let deltaX = interaction.previousX - interaction.startX
    let deltaY = interaction.previousY - interaction.startY
    guard max(abs(deltaX), abs(deltaY)) >= Threshold.swipeMinDistance else { return }

    if interaction.fingers == 3, abs(deltaX) > abs(deltaY) {
      sink.record(.shortcut(deltaX < 0 ? .nextApplication : .previousApplication))
    } else if interaction.fingers == 3, deltaY < 0 {
      sink.record(.shortcut(.missionControl))
    } else if interaction.fingers == 3 {
      sink.record(.shortcut(.showDesktop))
    } else if abs(deltaX) > abs(deltaY) {
      sink.record(.shortcut(deltaX < 0 ? .spaceRight : .spaceLeft))
    } else {
      sink.record(.shortcut(deltaY < 0 ? .missionControl : .showDesktop))
    }
  }
}
