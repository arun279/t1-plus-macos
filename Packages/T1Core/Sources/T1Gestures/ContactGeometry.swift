import T1Protocol

public struct T1Point: Equatable, Sendable {
  public let x: Double
  public let y: Double

  public init(x: Double, y: Double) {
    self.x = x
    self.y = y
  }
}

public enum ContactGeometry {
  public static func centroid(of frame: T1Frame) -> T1Point? {
    var x = 0.0
    var y = 0.0
    var count = 0

    for index in 0..<T1ReportDecoder.contactSlotCount {
      let contact = frame.contacts[index]
      guard contact.isActive else { continue }

      x += Double(contact.x)
      y += Double(contact.y)
      count += 1
    }

    guard count > 0 else { return nil }
    return T1Point(x: x / Double(count), y: y / Double(count))
  }
}
