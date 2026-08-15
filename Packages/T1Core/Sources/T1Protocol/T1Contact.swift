public struct T1Contact: Equatable, Sendable {
  public let slot: Int
  public let isConfident: Bool
  public let isTouching: Bool
  public let identifier: UInt8
  public let x: UInt16
  public let y: UInt16

  public init(
    slot: Int,
    isConfident: Bool,
    isTouching: Bool,
    identifier: UInt8,
    x: UInt16,
    y: UInt16
  ) {
    self.slot = slot
    self.isConfident = isConfident
    self.isTouching = isTouching
    self.identifier = identifier
    self.x = x
    self.y = y
  }

  public var isActive: Bool {
    isConfident && isTouching
  }
}

public struct T1ContactSlots: Equatable, Sendable {
  public let first: T1Contact
  public let second: T1Contact
  public let third: T1Contact
  public let fourth: T1Contact

  public init(
    first: T1Contact,
    second: T1Contact,
    third: T1Contact,
    fourth: T1Contact
  ) {
    self.first = first
    self.second = second
    self.third = third
    self.fourth = fourth
  }

  public subscript(index: Int) -> T1Contact {
    switch index {
    case 0: first
    case 1: second
    case 2: third
    case 3: fourth
    default: preconditionFailure("T1 contact slot index must be in 0..<4")
    }
  }
}

public struct T1Frame: Equatable, Sendable {
  public let contacts: T1ContactSlots
  public let scanTime: UInt16
  public let reportedContactCount: UInt8
  public let isPrimaryButtonPressed: Bool

  public init(
    contacts: T1ContactSlots,
    scanTime: UInt16,
    reportedContactCount: UInt8,
    isPrimaryButtonPressed: Bool
  ) {
    self.contacts = contacts
    self.scanTime = scanTime
    self.reportedContactCount = reportedContactCount
    self.isPrimaryButtonPressed = isPrimaryButtonPressed
  }

  public var activeContactCount: Int {
    var count = 0
    for index in 0..<T1ReportDecoder.contactSlotCount where contacts[index].isActive {
      count += 1
    }
    return count
  }
}
