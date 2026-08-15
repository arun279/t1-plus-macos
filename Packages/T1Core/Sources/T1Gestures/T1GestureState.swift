enum InteractionMode: Sendable {
  case idle
  case pointer
  case twoPending
  case twoScroll
  case twoPinch
  case multi
}

enum ScrollAxis: Sendable {
  case free
  case horizontal
  case vertical
}

struct Interaction: Sendable {
  var mode = InteractionMode.idle
  var fingers = 0
  var startedAt: UInt64 = 0
  var startX = 0.0
  var startY = 0.0
  var previousX = 0.0
  var previousY = 0.0
  var startDistance = 0.0
  var maxCentroidDistance = 0.0
  var maxRadiusChange = 0.0
  var pinchStepsEmitted = 0
  var samples = 0
  var scrollAxis = ScrollAxis.free
  var scrollStarted = false
  var pendingScrollX = 0.0
  var pendingScrollY = 0.0
  var tapDragCandidate = false
  var sawPhysicalButton = false
  var trackedContacts = T1TrackedContacts()
}

struct TapRecord: Sendable {
  let timestampNanoseconds: UInt64
  let cursorX: Double
  let cursorY: Double
}

struct FrameGeometry {
  let centroidX: Double
  let centroidY: Double
  let distance: Double
}

enum Threshold {
  static let surfaceMidpointX = 2557.0 / 2.0
  static let buttonZoneY = 930.0
  static let tapMaxSeconds = 0.28
  static let twoFingerTapMaxSeconds = 0.32
  static let tapMaxDistance = 30.0
  static let twoFingerTapMaxDistance = 36.0
  static let scrollStartDistance = 9.0
  static let pinchStartDistance = 18.0
  static let twoFingerCommitSeconds = 0.12
  static let tapDragStartDistance = 14.0
  static let tapDragCommitSeconds = 0.55
  static let swipeMinDistance = 150.0
}

func contactGeometry(_ contacts: T1ContactBuffer) -> FrameGeometry {
  var centroidX = 0.0
  var centroidY = 0.0
  for index in 0..<contacts.count {
    centroidX += Double(contacts[index].x)
    centroidY += Double(contacts[index].y)
  }
  centroidX /= Double(contacts.count)
  centroidY /= Double(contacts.count)

  let distance: Double
  if contacts.count == 2 {
    distance = magnitude(
      Double(contacts[0].x) - Double(contacts[1].x),
      Double(contacts[0].y) - Double(contacts[1].y)
    )
  } else {
    distance = 0
  }
  return FrameGeometry(centroidX: centroidX, centroidY: centroidY, distance: distance)
}

func magnitude(_ x: Double, _ y: Double) -> Double {
  (x * x + y * y).squareRoot()
}

func elapsedSeconds(from start: UInt64, to end: UInt64) -> Double {
  guard end >= start else { return 0 }
  return Double(end - start) / 1_000_000_000
}
