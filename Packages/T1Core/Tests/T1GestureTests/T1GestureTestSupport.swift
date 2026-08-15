import T1Gestures
import T1Protocol

// The compact fixture value mirrors the three scalar fields needed to build a contact.
// swiftlint:disable:next large_tuple
typealias ContactValue = (identifier: UInt8, x: UInt16, y: UInt16)

struct ActionCollector: T1GestureActionSink {
  var actions: [T1GestureAction] = []

  mutating func record(_ action: T1GestureAction) {
    actions.append(action)
  }
}

func performTap(
  engine: inout T1GestureEngine,
  sink: inout ActionCollector,
  start: UInt64,
  x: UInt16,
  y: UInt16
) {
  let touch = gestureFrame([(0, x, y)])
  engine.process(touch, at: start, into: &sink)
  engine.process(touch, at: start + 40_000_000, into: &sink)
  engine.process(touch, at: start + 80_000_000, into: &sink)
  engine.process(gestureFrame([]), at: start + 100_000_000, into: &sink)
}

func performMultiFingerSwipe(
  fingers: Int,
  deltaXPerStep: Int,
  deltaYPerStep: Int
) -> [T1GestureAction] {
  var engine = T1GestureEngine()
  var sink = ActionCollector()
  let start: UInt64 = 1_000_000_000

  engine.process(
    gestureFrame(multiFingerContacts(count: fingers)),
    at: start,
    into: &sink
  )
  for step in 1...8 {
    engine.process(
      gestureFrame(
        multiFingerContacts(
          count: fingers,
          offsetX: step * deltaXPerStep,
          offsetY: step * deltaYPerStep
        )
      ),
      at: start + UInt64(step) * 20_000_000,
      into: &sink
    )
  }
  engine.process(gestureFrame([]), at: start + 200_000_000, into: &sink)
  return sink.actions
}

func multiFingerContacts(
  count: Int,
  offsetX: Int = 0,
  offsetY: Int = 0
) -> [ContactValue] {
  (0..<count).map { index in
    (
      identifier: UInt8(index),
      x: UInt16(1_000 + index * 120 + offsetX),
      y: UInt16(600 + index * 30 + offsetY)
    )
  }
}

func scrollPhases(in actions: [T1GestureAction]) -> [T1ScrollPhase] {
  actions.compactMap { action in
    if case .scroll(_, _, let phase) = action { return phase }
    return nil
  }
}

func scrollDeltas(in actions: [T1GestureAction]) -> [Int32] {
  actions.compactMap { action in
    if case .scroll(_, let deltaY, _) = action { return deltaY }
    return nil
  }
}

func gestureFrame(
  _ values: [ContactValue],
  isButtonPressed: Bool = false
) -> T1Frame {
  let contacts = values.enumerated().map { index, value in
    T1Contact(
      slot: index,
      isConfident: true,
      isTouching: true,
      identifier: value.identifier,
      x: value.x,
      y: value.y
    )
  }
  let inactive = T1Contact(
    slot: 0,
    isConfident: false,
    isTouching: false,
    identifier: 0,
    x: 0,
    y: 0
  )
  return T1Frame(
    contacts: T1ContactSlots(
      first: contacts.indices.contains(0) ? contacts[0] : inactive,
      second: contacts.indices.contains(1) ? contacts[1] : inactive,
      third: contacts.indices.contains(2) ? contacts[2] : inactive,
      fourth: contacts.indices.contains(3) ? contacts[3] : inactive
    ),
    scanTime: 0,
    reportedContactCount: UInt8(contacts.count),
    isPrimaryButtonPressed: isButtonPressed
  )
}
