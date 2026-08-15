import T1Gestures
import XCTest

final class T1MultiFingerGestureEngineTests: XCTestCase {
  func testThreeFingerSwipeRetainsReleasedContactUntilLift() {
    var engine = T1GestureEngine()
    var sink = ActionCollector()
    let start: UInt64 = 1_000_000_000

    engine.process(
      gestureFrame([(0, 500, 300), (1, 600, 400), (2, 700, 500)]),
      at: start,
      into: &sink
    )
    for step in 1...8 {
      let offset = UInt16(step * 25)
      engine.process(
        gestureFrame([(0, 500 - offset, 300), (1, 600 - offset, 400), (2, 700 - offset, 500)]),
        at: start + UInt64(step) * 20_000_000,
        into: &sink
      )
    }
    engine.process(
      gestureFrame([(0, 300, 300), (1, 400, 400)]),
      at: start + 180_000_000,
      into: &sink
    )
    engine.process(gestureFrame([]), at: start + 200_000_000, into: &sink)

    XCTAssertEqual(sink.actions, [.shortcut(.nextApplication)])
  }

  func testThreeAndFourFingerTapMappings() {
    let cases: [(fingers: Int, expected: T1Shortcut)] = [
      (3, .spotlight),
      (4, .notificationCenter),
    ]

    for testCase in cases {
      var engine = T1GestureEngine()
      var sink = ActionCollector()
      let start: UInt64 = 1_000_000_000
      let contacts = multiFingerContacts(count: testCase.fingers)

      engine.process(gestureFrame(contacts), at: start, into: &sink)
      engine.process(gestureFrame(contacts), at: start + 50_000_000, into: &sink)
      engine.process(gestureFrame(contacts), at: start + 90_000_000, into: &sink)
      engine.process(gestureFrame([]), at: start + 120_000_000, into: &sink)

      XCTAssertEqual(sink.actions, [.shortcut(testCase.expected)])
    }
  }

  func testThreeAndFourFingerSwipeMappings() {
    let cases = [
      SwipeCase(fingers: 3, deltaX: -25, deltaY: 0, expected: .nextApplication),
      SwipeCase(fingers: 3, deltaX: 25, deltaY: 0, expected: .previousApplication),
      SwipeCase(fingers: 3, deltaX: 0, deltaY: -25, expected: .missionControl),
      SwipeCase(fingers: 3, deltaX: 0, deltaY: 25, expected: .showDesktop),
      SwipeCase(fingers: 4, deltaX: -25, deltaY: 0, expected: .spaceRight),
      SwipeCase(fingers: 4, deltaX: 25, deltaY: 0, expected: .spaceLeft),
      SwipeCase(fingers: 4, deltaX: 0, deltaY: -25, expected: .missionControl),
      SwipeCase(fingers: 4, deltaX: 0, deltaY: 25, expected: .showDesktop),
    ]

    for testCase in cases {
      XCTAssertEqual(
        performMultiFingerSwipe(
          fingers: testCase.fingers,
          deltaXPerStep: testCase.deltaX,
          deltaYPerStep: testCase.deltaY
        ),
        [.shortcut(testCase.expected)]
      )
    }
  }

  func testAddingThirdFingerDoesNotLeakPendingTwoFingerAction() {
    var engine = T1GestureEngine()
    var sink = ActionCollector()
    let start: UInt64 = 1_000_000_000

    engine.process(
      gestureFrame([(0, 400, 300), (1, 600, 300)]),
      at: start,
      into: &sink
    )
    engine.process(
      gestureFrame([(0, 400, 320), (1, 600, 320)]),
      at: start + 50_000_000,
      into: &sink
    )
    let threeContacts: [ContactValue] = [(0, 400, 320), (1, 600, 320), (2, 800, 320)]
    engine.process(gestureFrame(threeContacts), at: start + 80_000_000, into: &sink)
    engine.process(gestureFrame(threeContacts), at: start + 110_000_000, into: &sink)
    engine.process(gestureFrame(threeContacts), at: start + 140_000_000, into: &sink)
    engine.process(gestureFrame([]), at: start + 170_000_000, into: &sink)

    XCTAssertEqual(sink.actions, [.shortcut(.spotlight)])
  }

  func testTrailingFingerAfterTwoFingerLiftDoesNotLeakPointerAction() {
    var engine = T1GestureEngine()
    var sink = ActionCollector()
    let start: UInt64 = 1_000_000_000
    let contacts: [ContactValue] = [(0, 400, 400), (1, 600, 400)]

    engine.process(gestureFrame(contacts), at: start, into: &sink)
    engine.process(gestureFrame(contacts), at: start + 50_000_000, into: &sink)
    engine.process(gestureFrame(contacts), at: start + 80_000_000, into: &sink)
    engine.process(gestureFrame([(0, 400, 400)]), at: start + 100_000_000, into: &sink)
    engine.process(gestureFrame([(0, 800, 700)]), at: start + 130_000_000, into: &sink)
    engine.process(gestureFrame([]), at: start + 160_000_000, into: &sink)

    XCTAssertEqual(
      sink.actions,
      [
        .button(.right, phase: .down, clickCount: 1),
        .button(.right, phase: .up, clickCount: 1),
      ]
    )
  }
}

private struct SwipeCase {
  let fingers: Int
  let deltaX: Int
  let deltaY: Int
  let expected: T1Shortcut
}
