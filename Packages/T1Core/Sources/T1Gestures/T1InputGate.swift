public enum T1InputSuspensionReason: UInt8, Sendable {
  case system = 1
  case session = 2
}

public struct T1InputGate: Sendable {
  private var suspensionMask: UInt8 = 0
  private var requiresLift = false

  public init() {}

  public mutating func suspend(
    _ reason: T1InputSuspensionReason,
    interactionActive: Bool
  ) {
    suspensionMask |= reason.rawValue
    requiresLift = requiresLift || interactionActive
  }

  @discardableResult
  public mutating func resume(_ reason: T1InputSuspensionReason) -> Bool {
    suspensionMask &= ~reason.rawValue
    return suspensionMask == 0
  }

  public mutating func requireLift(interactionActive: Bool) {
    requiresLift = requiresLift || interactionActive
  }

  public mutating func shouldProcess(hasInteraction: Bool) -> Bool {
    if suspensionMask != 0 {
      requiresLift = hasInteraction
      return false
    }
    if requiresLift {
      requiresLift = hasInteraction
      return false
    }
    return true
  }
}
