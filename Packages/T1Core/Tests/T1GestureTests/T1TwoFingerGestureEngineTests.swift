import T1Gestures
import XCTest

final class T1TwoFingerGestureEngineTests: XCTestCase {
  func testTwoFingerTapEmitsSecondaryClick() {
    var engine = T1GestureEngine()
    var sink = ActionCollector()
    let start: UInt64 = 1_000_000_000
    let contacts: [ContactValue] = [(0, 400, 400), (1, 600, 400)]

    engine.process(gestureFrame(contacts), at: start, into: &sink)
    engine.process(gestureFrame(contacts), at: start + 50_000_000, into: &sink)
    engine.process(gestureFrame(contacts), at: start + 90_000_000, into: &sink)
    engine.process(gestureFrame([]), at: start + 120_000_000, into: &sink)

    XCTAssertEqual(
      sink.actions,
      [
        .button(.right, phase: .pressed, clickCount: 1),
        .button(.right, phase: .released, clickCount: 1),
      ]
    )
  }

  func testTwoFingerTranslationCommitsScrollWithPhases() {
    var engine = T1GestureEngine()
    var sink = ActionCollector()
    let start: UInt64 = 1_000_000_000

    processScrollTrace(engine: &engine, sink: &sink, start: start)
    engine.process(gestureFrame([]), at: start + 180_000_000, into: &sink)

    XCTAssertEqual(scrollPhases(in: sink.actions), [.began, .changed, .ended])
    XCTAssertFalse(
      sink.actions.contains { action in
        if case .shortcut = action { return true }
        return false
      })
  }

  func testCancelEndsActiveScroll() {
    var engine = T1GestureEngine()
    var sink = ActionCollector()
    let start: UInt64 = 1_000_000_000

    processScrollTrace(engine: &engine, sink: &sink, start: start)
    engine.cancel(at: start + 180_000_000, into: &sink)

    XCTAssertEqual(scrollPhases(in: sink.actions), [.began, .changed, .ended])
  }

  func testTwoFingerRadiusChangeEmitsZoomWithoutScroll() {
    var engine = T1GestureEngine()
    var sink = ActionCollector()
    let start: UInt64 = 1_000_000_000

    processPinchTrace(engine: &engine, sink: &sink, start: start, expanding: true)
    engine.process(gestureFrame([]), at: start + 180_000_000, into: &sink)

    XCTAssertEqual(sink.actions.filter { $0 == .shortcut(.zoomIn) }.count, 1)
    XCTAssertTrue(scrollPhases(in: sink.actions).isEmpty)
  }

  func testTwoFingerContractionEmitsZoomOutWithoutScroll() {
    var engine = T1GestureEngine()
    var sink = ActionCollector()
    let start: UInt64 = 1_000_000_000

    processPinchTrace(engine: &engine, sink: &sink, start: start, expanding: false)
    engine.process(gestureFrame([]), at: start + 180_000_000, into: &sink)

    XCTAssertEqual(sink.actions.filter { $0 == .shortcut(.zoomOut) }.count, 1)
    XCTAssertTrue(scrollPhases(in: sink.actions).isEmpty)
  }

  func testDisablingGesturesSuppressesPinchShortcuts() {
    var engine = T1GestureEngine(
      configuration: T1GestureConfiguration(gesturesEnabled: false)
    )
    var sink = ActionCollector()
    let start: UInt64 = 1_000_000_000

    processPinchTrace(engine: &engine, sink: &sink, start: start, expanding: true)
    engine.process(gestureFrame([]), at: start + 180_000_000, into: &sink)

    XCTAssertTrue(sink.actions.isEmpty)
  }

  func testSlowHorizontalTranslationDoesNotBecomePinch() {
    var engine = T1GestureEngine()
    var sink = ActionCollector()
    let start: UInt64 = 1_000_000_000
    let frames = [
      gestureFrame([(0, 400, 300), (1, 800, 300)]),
      gestureFrame([(0, 412, 300), (1, 836, 300)]),
      gestureFrame([(0, 500, 300), (1, 930, 300)]),
      gestureFrame([(0, 560, 300), (1, 990, 300)]),
    ]
    let offsets: [UInt64] = [0, 180_000_000, 220_000_000, 260_000_000]

    for (frame, offset) in zip(frames, offsets) {
      engine.process(frame, at: start + offset, into: &sink)
    }
    engine.process(gestureFrame([]), at: start + 300_000_000, into: &sink)

    XCTAssertFalse(
      sink.actions.contains { action in
        if case .shortcut(.zoomIn) = action { return true }
        if case .shortcut(.zoomOut) = action { return true }
        return false
      })
    XCTAssertEqual(scrollPhases(in: sink.actions), [.began, .changed, .ended])
  }

  func testPinchOutputIsRateLimited() {
    var engine = T1GestureEngine()
    var sink = ActionCollector()
    let start: UInt64 = 1_000_000_000
    let frames = [
      gestureFrame([(0, 600, 400), (1, 1_000, 400)]),
      gestureFrame([(0, 500, 400), (1, 1_100, 400)]),
      gestureFrame([(0, 400, 400), (1, 1_200, 400)]),
      gestureFrame([(0, 300, 400), (1, 1_300, 400)]),
      gestureFrame([(0, 200, 400), (1, 1_400, 400)]),
      gestureFrame([(0, 200, 400), (1, 1_400, 400)]),
    ]
    let offsets: [UInt64] = [
      0,
      130_000_000,
      140_000_000,
      150_000_000,
      160_000_000,
      210_000_000,
    ]

    for (frame, offset) in zip(frames, offsets) {
      engine.process(frame, at: start + offset, into: &sink)
    }

    XCTAssertEqual(sink.actions.filter { $0 == .shortcut(.zoomIn) }.count, 2)
  }

  func testInvertScrollReversesOutputDeltas() {
    var regularEngine = T1GestureEngine()
    var invertedEngine = T1GestureEngine(
      configuration: T1GestureConfiguration(invertScroll: true)
    )
    var regularSink = ActionCollector()
    var invertedSink = ActionCollector()
    let start: UInt64 = 1_000_000_000

    processScrollTrace(engine: &regularEngine, sink: &regularSink, start: start)
    processScrollTrace(engine: &invertedEngine, sink: &invertedSink, start: start)

    XCTAssertEqual(
      scrollDeltas(in: regularSink.actions).map { -$0 },
      scrollDeltas(in: invertedSink.actions)
    )
  }

  private func processScrollTrace(
    engine: inout T1GestureEngine,
    sink: inout ActionCollector,
    start: UInt64
  ) {
    let frames = [
      gestureFrame([(0, 400, 300), (1, 600, 300)]),
      gestureFrame([(0, 400, 320), (1, 600, 320)]),
      gestureFrame([(0, 400, 350), (1, 600, 350)]),
      gestureFrame([(0, 400, 365), (1, 600, 365)]),
    ]
    let offsets: [UInt64] = [0, 50_000_000, 130_000_000, 160_000_000]
    for (frame, offset) in zip(frames, offsets) {
      engine.process(frame, at: start + offset, into: &sink)
    }
  }

  private func processPinchTrace(
    engine: inout T1GestureEngine,
    sink: inout ActionCollector,
    start: UInt64,
    expanding: Bool
  ) {
    let positions: [(UInt16, UInt16)] =
      expanding
      ? [(400, 600), (380, 620), (340, 660), (300, 700)]
      : [(300, 700), (320, 680), (360, 640), (400, 600)]
    let offsets: [UInt64] = [0, 50_000_000, 130_000_000, 160_000_000]
    for (position, offset) in zip(positions, offsets) {
      engine.process(
        gestureFrame([(0, position.0, 400), (1, position.1, 400)]),
        at: start + offset,
        into: &sink
      )
    }
  }
}
