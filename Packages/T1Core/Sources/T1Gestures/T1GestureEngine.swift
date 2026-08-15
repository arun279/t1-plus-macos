import T1Protocol

public struct T1GestureEngine: Sendable {
  public var configuration: T1GestureConfiguration

  var interaction = Interaction()
  var physicalButtonDown = false
  var physicalButton = T1Button.left
  var tapDragDown = false
  var suppressTapUntilLift = false
  var ignoreUntilAllLift = false
  var pointerRemainderX = 0.0
  var pointerRemainderY = 0.0
  var logicalCursorX = 0.0
  var logicalCursorY = 0.0
  var scrollRemainderX = 0.0
  var scrollRemainderY = 0.0
  var lastTap: TapRecord?

  public init(configuration: T1GestureConfiguration = T1GestureConfiguration()) {
    self.configuration = configuration
  }

  // Recognition order is intentionally linear so arbitration and state changes remain auditable.
  // swiftlint:disable:next cyclomatic_complexity function_body_length
  public mutating func process<Sink: T1GestureActionSink>(
    _ frame: T1Frame,
    at timestampNanoseconds: UInt64,
    into sink: inout Sink
  ) {
    handlePhysicalButton(frame, sink: &sink)

    let contacts = collectSurfaceContacts(frame)
    let contactCount = contacts.count
    if ignoreUntilAllLift {
      if contactCount == 0 {
        ignoreUntilAllLift = false
        if !frame.isPrimaryButtonPressed {
          suppressTapUntilLift = false
        }
      }
      return
    }

    if contactCount == 0 {
      finishInteraction(at: timestampNanoseconds, lifted: true, sink: &sink)
      if !frame.isPrimaryButtonPressed {
        suppressTapUntilLift = false
      }
      return
    }

    var geometry = contactGeometry(contacts)
    if interaction.mode == .idle || interaction.fingers != contactCount {
      let contactReleased = interaction.mode != .idle && interaction.fingers > contactCount
      if contactReleased, interaction.mode == .multi {
        remember(contacts)
        var trackedContacts = T1ContactBuffer()
        interaction.trackedContacts.copy(into: &trackedContacts)
        if trackedContacts.count >= interaction.fingers {
          geometry = contactGeometry(trackedContacts)
        }
      } else {
        finishInteraction(at: timestampNanoseconds, lifted: contactReleased, sink: &sink)
        if contactReleased {
          ignoreUntilAllLift = true
          return
        }
        beginInteraction(
          fingers: contactCount,
          geometry: geometry,
          at: timestampNanoseconds
        )
        remember(contacts)
        return
      }
    } else if interaction.mode == .multi {
      remember(contacts)
      var trackedContacts = T1ContactBuffer()
      interaction.trackedContacts.copy(into: &trackedContacts)
      if trackedContacts.count >= interaction.fingers {
        geometry = contactGeometry(trackedContacts)
      }
    }

    let deltaX = geometry.centroidX - interaction.previousX
    let deltaY = geometry.centroidY - interaction.previousY
    let fromStart = magnitude(
      geometry.centroidX - interaction.startX,
      geometry.centroidY - interaction.startY
    )
    let radiusChange = geometry.distance - interaction.startDistance
    if interaction.fingers == 2 {
      interaction.pendingScrollX += deltaX
      interaction.pendingScrollY += deltaY
    }
    interaction.maxCentroidDistance = max(interaction.maxCentroidDistance, fromStart)
    interaction.maxRadiusChange = max(interaction.maxRadiusChange, abs(radiusChange))
    interaction.samples += 1

    if interaction.mode == .pointer {
      if interaction.tapDragCandidate, !tapDragDown,
        fromStart >= Threshold.tapDragStartDistance,
        elapsedSeconds(from: interaction.startedAt, to: timestampNanoseconds)
          < Threshold.tapDragCommitSeconds
      {
        emitButton(.left, phase: .down, clickCount: 2, sink: &sink)
        tapDragDown = true
        lastTap = nil
      }
      emitPointer(deltaX: deltaX, deltaY: deltaY, sink: &sink)
    } else if interaction.mode == .twoPending {
      if abs(radiusChange) >= Threshold.pinchStartDistance,
        abs(radiusChange) > fromStart * 0.80
      {
        interaction.mode = .twoPinch
      } else if fromStart >= Threshold.scrollStartDistance * 1.7,
        fromStart > abs(radiusChange) * 1.15
      {
        interaction.mode = .twoScroll
        let totalX = geometry.centroidX - interaction.startX
        let totalY = geometry.centroidY - interaction.startY
        if abs(totalY) > abs(totalX) * 1.35 {
          interaction.scrollAxis = .vertical
        } else if abs(totalX) > abs(totalY) * 1.35 {
          interaction.scrollAxis = .horizontal
        }
      }
    }

    let twoFingerCommitted =
      elapsedSeconds(from: interaction.startedAt, to: timestampNanoseconds)
      >= Threshold.twoFingerCommitSeconds
    if interaction.mode == .twoScroll, twoFingerCommitted {
      var scrollX = interaction.pendingScrollX
      var scrollY = interaction.pendingScrollY
      interaction.pendingScrollX = 0
      interaction.pendingScrollY = 0
      if interaction.scrollAxis == .vertical {
        scrollX = 0
      } else if interaction.scrollAxis == .horizontal {
        scrollY = 0
      }
      emitScroll(deltaX: scrollX, deltaY: scrollY, sink: &sink)
    } else if interaction.mode == .twoPinch,
      configuration.gesturesEnabled,
      twoFingerCommitted
    {
      let stepPosition = radiusChange / 68.0
      while stepPosition >= Double(interaction.pinchStepsEmitted) + 0.80 {
        sink.record(.shortcut(.zoomIn))
        interaction.pinchStepsEmitted += 1
      }
      while stepPosition <= Double(interaction.pinchStepsEmitted) - 0.80 {
        sink.record(.shortcut(.zoomOut))
        interaction.pinchStepsEmitted -= 1
      }
    }

    interaction.previousX = geometry.centroidX
    interaction.previousY = geometry.centroidY
  }

  public mutating func finish<Sink: T1GestureActionSink>(
    at timestampNanoseconds: UInt64,
    into sink: inout Sink
  ) {
    finishInteraction(at: timestampNanoseconds, lifted: true, sink: &sink)
    if physicalButtonDown {
      emitButton(physicalButton, phase: .up, clickCount: 1, sink: &sink)
    }
    physicalButtonDown = false
    tapDragDown = false
    suppressTapUntilLift = false
    ignoreUntilAllLift = false
  }
}

private extension T1GestureEngine {
  private mutating func handlePhysicalButton<Sink: T1GestureActionSink>(
    _ frame: T1Frame,
    sink: inout Sink
  ) {
    guard frame.isPrimaryButtonPressed != physicalButtonDown else { return }

    if frame.isPrimaryButtonPressed {
      if tapDragDown {
        emitButton(.left, phase: .up, clickCount: 2, sink: &sink)
        tapDragDown = false
      }
      var pressX = Threshold.surfaceMidpointX - 1
      var deepestY = -1.0
      for index in 0..<T1ReportDecoder.contactSlotCount {
        let contact = frame.contacts[index]
        let contactY = Double(contact.y)
        if contact.isActive, contactY > deepestY {
          deepestY = contactY
          pressX = Double(contact.x)
        }
      }
      physicalButton = pressX < Threshold.surfaceMidpointX ? .left : .right
      physicalButtonDown = true
      suppressTapUntilLift = true
      interaction.sawPhysicalButton = true
      emitButton(physicalButton, phase: .down, clickCount: 1, sink: &sink)
    } else {
      emitButton(physicalButton, phase: .up, clickCount: 1, sink: &sink)
      physicalButtonDown = false
    }
  }

  private func collectSurfaceContacts(_ frame: T1Frame) -> T1ContactBuffer {
    var output = T1ContactBuffer()
    for index in 0..<T1ReportDecoder.contactSlotCount {
      let contact = frame.contacts[index]
      guard contact.isActive else { continue }
      guard !frame.isPrimaryButtonPressed || Double(contact.y) < Threshold.buttonZoneY else {
        continue
      }
      output.append(contact)
    }
    return output
  }

  private mutating func remember(_ contacts: T1ContactBuffer) {
    for index in 0..<contacts.count {
      interaction.trackedContacts.remember(contacts[index])
    }
  }

  private mutating func beginInteraction(
    fingers: Int,
    geometry: FrameGeometry,
    at timestampNanoseconds: UInt64
  ) {
    interaction = Interaction()
    interaction.fingers = fingers
    interaction.startedAt = timestampNanoseconds
    interaction.startX = geometry.centroidX
    interaction.startY = geometry.centroidY
    interaction.previousX = geometry.centroidX
    interaction.previousY = geometry.centroidY
    interaction.startDistance = geometry.distance
    interaction.samples = 1
    interaction.sawPhysicalButton = suppressTapUntilLift

    if fingers == 1 {
      interaction.mode = .pointer
      interaction.tapDragCandidate =
        configuration.tapsEnabled
        && isNearLastTap(at: timestampNanoseconds)
      pointerRemainderX = 0
      pointerRemainderY = 0
    } else if fingers == 2 {
      interaction.mode = .twoPending
      scrollRemainderX = 0
      scrollRemainderY = 0
    } else {
      interaction.mode = .multi
    }
  }

  // Completion predicates are ordered because only the first matching gesture may emit an action.
  // swiftlint:disable:next cyclomatic_complexity function_body_length
  private mutating func finishInteraction<Sink: T1GestureActionSink>(
    at timestampNanoseconds: UInt64,
    lifted: Bool,
    sink: inout Sink
  ) {
    guard interaction.mode != .idle else { return }

    let duration = elapsedSeconds(from: interaction.startedAt, to: timestampNanoseconds)
    if tapDragDown, interaction.mode == .pointer {
      emitButton(.left, phase: .up, clickCount: 2, sink: &sink)
      tapDragDown = false
      interaction = Interaction()
      return
    }

    let cleanLift = lifted && !interaction.sawPhysicalButton && !suppressTapUntilLift
    if interaction.mode == .twoScroll, interaction.scrollStarted {
      sink.record(.scroll(deltaX: 0, deltaY: 0, phase: .ended))
    }

    if interaction.mode == .pointer,
      configuration.tapsEnabled,
      cleanLift,
      interaction.samples >= 3,
      duration >= 0.035,
      duration <= Threshold.tapMaxSeconds,
      interaction.maxCentroidDistance <= Threshold.tapMaxDistance
    {
      emitTap(
        .left,
        at: timestampNanoseconds,
        sink: &sink
      )
    } else if interaction.mode == .twoPending,
      configuration.tapsEnabled,
      cleanLift,
      interaction.samples >= 3,
      duration >= 0.045,
      duration <= Threshold.twoFingerTapMaxSeconds,
      interaction.maxCentroidDistance <= Threshold.twoFingerTapMaxDistance,
      interaction.maxRadiusChange <= Threshold.twoFingerTapMaxDistance
    {
      emitTap(
        .right,
        at: timestampNanoseconds,
        sink: &sink
      )
    } else if interaction.mode == .multi,
      configuration.gesturesEnabled,
      cleanLift,
      interaction.samples >= 3,
      duration <= 0.36,
      interaction.maxCentroidDistance <= 42
    {
      if interaction.fingers == 3 {
        sink.record(.shortcut(.spotlight))
      } else if interaction.fingers == 4 {
        sink.record(.shortcut(.notificationCenter))
      }
    } else if interaction.mode == .multi,
      lifted,
      configuration.gesturesEnabled,
      interaction.samples >= 8,
      duration >= 0.10
    {
      emitSwipe(sink: &sink)
    }
    interaction = Interaction()
  }
}
