public enum T1PointerKind: Equatable, Sendable {
  case move
  case leftDrag
  case rightDrag
}

public enum T1Button: Equatable, Sendable {
  case left
  case right
}

public enum T1ButtonPhase: Equatable, Sendable {
  case pressed
  case released
}

public enum T1ScrollPhase: Equatable, Sendable {
  case began
  case changed
  case ended
}

public enum T1Shortcut: Equatable, Sendable {
  case missionControl
  case nextApplication
  case notificationCenter
  case previousApplication
  case showDesktop
  case spaceLeft
  case spaceRight
  case spotlight
  case zoomIn
  case zoomOut
}

public enum T1GestureAction: Equatable, Sendable {
  case pointer(deltaX: Int32, deltaY: Int32, kind: T1PointerKind)
  case button(T1Button, phase: T1ButtonPhase, clickCount: Int)
  case scroll(deltaX: Int32, deltaY: Int32, phase: T1ScrollPhase)
  case shortcut(T1Shortcut)
}

public protocol T1GestureActionSink {
  mutating func record(_ action: T1GestureAction)
}

public struct T1GestureConfiguration: Equatable, Sendable {
  public var tapsEnabled: Bool
  public var gesturesEnabled: Bool
  public var invertScroll: Bool
  public var pointerGain: Double {
    get { pointerGainValue }
    set { pointerGainValue = Self.validatedGain(newValue, fallback: Self.defaultPointerGain) }
  }
  public var scrollGain: Double {
    get { scrollGainValue }
    set { scrollGainValue = Self.validatedGain(newValue, fallback: Self.defaultScrollGain) }
  }

  private var pointerGainValue: Double
  private var scrollGainValue: Double
  private static let defaultPointerGain = 0.82
  private static let defaultScrollGain = 0.85
  private static let minimumGain = 0.20
  private static let maximumGain = 2.50

  public init(
    tapsEnabled: Bool = true,
    gesturesEnabled: Bool = true,
    invertScroll: Bool = false,
    pointerGain: Double = 0.82,
    scrollGain: Double = 0.85
  ) {
    self.tapsEnabled = tapsEnabled
    self.gesturesEnabled = gesturesEnabled
    self.invertScroll = invertScroll
    self.pointerGainValue = Self.validatedGain(pointerGain, fallback: Self.defaultPointerGain)
    self.scrollGainValue = Self.validatedGain(scrollGain, fallback: Self.defaultScrollGain)
  }

  private static func validatedGain(_ value: Double, fallback: Double) -> Double {
    guard value.isFinite else { return fallback }
    return min(max(value, minimumGain), maximumGain)
  }
}
