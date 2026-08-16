import T1Gestures

public struct T1Settings: Codable, Equatable, Sendable {
  public static let currentVersion = 1
  public static let pointerGainRange = 0.20...2.50
  public static let scrollGainRange = 0.20...2.50

  public var tapsEnabled: Bool
  public var gesturesEnabled: Bool
  public var invertScroll: Bool
  public var pointerGain: Double
  public var scrollGain: Double

  private let version: Int

  public init(
    tapsEnabled: Bool = true,
    gesturesEnabled: Bool = true,
    invertScroll: Bool = false,
    pointerGain: Double = 0.82,
    scrollGain: Double = 0.85
  ) {
    version = Self.currentVersion
    self.tapsEnabled = tapsEnabled
    self.gesturesEnabled = gesturesEnabled
    self.invertScroll = invertScroll
    self.pointerGain = Self.validated(
      pointerGain,
      in: Self.pointerGainRange,
      fallback: 0.82
    )
    self.scrollGain = Self.validated(
      scrollGain,
      in: Self.scrollGainRange,
      fallback: 0.85
    )
  }

  public var gestureConfiguration: T1GestureConfiguration {
    T1GestureConfiguration(
      tapsEnabled: tapsEnabled,
      gesturesEnabled: gesturesEnabled,
      invertScroll: invertScroll,
      pointerGain: pointerGain,
      scrollGain: scrollGain
    )
  }

  public func validated() -> T1Settings {
    T1Settings(
      tapsEnabled: tapsEnabled,
      gesturesEnabled: gesturesEnabled,
      invertScroll: invertScroll,
      pointerGain: pointerGain,
      scrollGain: scrollGain
    )
  }

  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    let version = try values.decode(Int.self, forKey: .version)
    guard version == Self.currentVersion else {
      throw DecodingError.dataCorruptedError(
        forKey: .version,
        in: values,
        debugDescription: "Unsupported settings version"
      )
    }
    self.init(
      tapsEnabled: try values.decode(Bool.self, forKey: .tapsEnabled),
      gesturesEnabled: try values.decode(Bool.self, forKey: .gesturesEnabled),
      invertScroll: try values.decode(Bool.self, forKey: .invertScroll),
      pointerGain: try values.decode(Double.self, forKey: .pointerGain),
      scrollGain: try values.decode(Double.self, forKey: .scrollGain)
    )
  }

  private static func validated(
    _ value: Double,
    in range: ClosedRange<Double>,
    fallback: Double
  ) -> Double {
    guard value.isFinite else { return fallback }
    return min(max(value, range.lowerBound), range.upperBound)
  }
}
