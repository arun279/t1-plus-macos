import T1Gestures
import XCTest

final class T1GestureEngineTests: XCTestCase {
  func testConfigurationBoundsFiniteAndNonfiniteGains() {
    var configuration = T1GestureConfiguration(pointerGain: .nan, scrollGain: 10)

    XCTAssertEqual(configuration.pointerGain, 0.82)
    XCTAssertEqual(configuration.scrollGain, 2.50)

    configuration.pointerGain = -4
    configuration.scrollGain = .infinity
    XCTAssertEqual(configuration.pointerGain, 0.20)
    XCTAssertEqual(configuration.scrollGain, 0.85)
  }

  func testOneFingerMotionEmitsPointerDeltasWithoutTap() {
    var engine = T1GestureEngine()
    var sink = ActionCollector()
    let start: UInt64 = 1_000_000_000

    engine.process(gestureFrame([(0, 100, 100)]), at: start, into: &sink)
    engine.process(gestureFrame([(0, 110, 105)]), at: start + 20_000_000, into: &sink)
    engine.process(gestureFrame([(0, 140, 110)]), at: start + 40_000_000, into: &sink)
    engine.process(gestureFrame([]), at: start + 60_000_000, into: &sink)

    XCTAssertEqual(sink.actions.count, 2)
    XCTAssertTrue(
      sink.actions.allSatisfy { action in
        if case .pointer(_, _, .move) = action { return true }
        return false
      })
  }

  func testTapAndDoubleTapClickState() {
    var engine = T1GestureEngine()
    var sink = ActionCollector()
    let start: UInt64 = 1_000_000_000

    performTap(engine: &engine, sink: &sink, start: start, x: 500, y: 400)
    performTap(engine: &engine, sink: &sink, start: start + 200_000_000, x: 900, y: 700)

    XCTAssertTrue(sink.actions.contains(.button(.left, phase: .down, clickCount: 1)))
    XCTAssertTrue(sink.actions.contains(.button(.left, phase: .down, clickCount: 2)))
  }

  func testTapDragEmitsHeldClickAndDragMotion() {
    var engine = T1GestureEngine()
    var sink = ActionCollector()
    let start: UInt64 = 1_000_000_000

    performTap(engine: &engine, sink: &sink, start: start, x: 502, y: 401)
    engine.process(gestureFrame([(0, 502, 401)]), at: start + 200_000_000, into: &sink)
    engine.process(gestureFrame([(0, 525, 401)]), at: start + 240_000_000, into: &sink)
    engine.process(gestureFrame([]), at: start + 280_000_000, into: &sink)

    XCTAssertTrue(sink.actions.contains(.button(.left, phase: .down, clickCount: 2)))
    XCTAssertTrue(
      sink.actions.contains { action in
        if case .pointer(_, _, .leftDrag) = action { return true }
        return false
      })
    XCTAssertEqual(
      Array(sink.actions.suffix(1)),
      [.button(.left, phase: .up, clickCount: 2)]
    )
  }

  func testDisablingTapsAlsoSuppressesTapDragCandidate() {
    var engine = T1GestureEngine()
    var sink = ActionCollector()
    let start: UInt64 = 1_000_000_000

    performTap(engine: &engine, sink: &sink, start: start, x: 500, y: 400)
    let actionsBeforeDisabledTouch = sink.actions.count
    engine.configuration.tapsEnabled = false
    engine.process(gestureFrame([(0, 500, 400)]), at: start + 200_000_000, into: &sink)
    engine.process(gestureFrame([(0, 525, 400)]), at: start + 240_000_000, into: &sink)
    engine.process(gestureFrame([]), at: start + 280_000_000, into: &sink)

    let disabledTouchActions = sink.actions.dropFirst(actionsBeforeDisabledTouch)
    XCTAssertEqual(disabledTouchActions.count, 1)
    XCTAssertTrue(
      disabledTouchActions.allSatisfy { action in
        if case .pointer(_, _, .move) = action { return true }
        return false
      })
  }

  func testDisablingTapsSuppressesPrimaryAndSecondaryTap() {
    var engine = T1GestureEngine(
      configuration: T1GestureConfiguration(tapsEnabled: false)
    )
    var sink = ActionCollector()
    let start: UInt64 = 1_000_000_000

    performTap(engine: &engine, sink: &sink, start: start, x: 500, y: 400)
    let contacts: [ContactValue] = [(0, 400, 400), (1, 600, 400)]
    engine.process(gestureFrame(contacts), at: start + 200_000_000, into: &sink)
    engine.process(gestureFrame(contacts), at: start + 250_000_000, into: &sink)
    engine.process(gestureFrame(contacts), at: start + 290_000_000, into: &sink)
    engine.process(gestureFrame([]), at: start + 320_000_000, into: &sink)

    XCTAssertTrue(sink.actions.isEmpty)
  }

  func testPhysicalButtonUsesDeepestContactAndFinishReleasesIt() {
    var engine = T1GestureEngine()
    var sink = ActionCollector()
    let start: UInt64 = 1_000_000_000

    engine.process(
      gestureFrame([(0, 2_000, 1_000)], isButtonPressed: true),
      at: start,
      into: &sink
    )
    engine.finish(at: start + 20_000_000, into: &sink)

    XCTAssertEqual(
      sink.actions,
      [
        .button(.right, phase: .down, clickCount: 1),
        .button(.right, phase: .up, clickCount: 1),
      ]
    )
  }
}
