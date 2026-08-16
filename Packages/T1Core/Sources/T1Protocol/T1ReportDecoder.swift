public enum T1ReportDecodeError: Error, Equatable, Sendable {
  case unsupportedReportID(UInt32)
  case invalidReportLength(Int)
  case invalidActiveContact(slot: Int, x: UInt16, y: UInt16)
  case invalidReportedContactCount(UInt8)
}

public enum T1ReportDecoder {
  public static let reportID: UInt32 = 5
  public static let contactSlotCount = 4
  public static let payloadSize = 19

  public static func decode(reportID: UInt32, bytes: [UInt8]) throws -> T1Frame {
    try bytes.withUnsafeBytes { buffer in
      try decode(reportID: reportID, bytes: buffer)
    }
  }

  public static func decode(
    reportID: UInt32,
    bytes: UnsafeRawBufferPointer
  ) throws -> T1Frame {
    guard reportID == self.reportID else {
      throw T1ReportDecodeError.unsupportedReportID(reportID)
    }

    let payload: UnsafeRawBufferPointer
    if bytes.count == payloadSize + 1, bytes[0] == UInt8(self.reportID) {
      payload = UnsafeRawBufferPointer(rebasing: bytes[1...])
    } else if bytes.count == payloadSize {
      payload = bytes
    } else {
      throw T1ReportDecodeError.invalidReportLength(bytes.count)
    }

    func contact(at slot: Int) -> T1Contact {
      let offset = slot * 4
      let flags = payload[offset]
      let x = UInt16(payload[offset + 1]) | (UInt16(payload[offset + 2] & 0x0F) << 8)
      let y = UInt16(payload[offset + 2] >> 4) | (UInt16(payload[offset + 3]) << 4)

      return T1Contact(
        slot: slot,
        isConfident: flags & 0x01 != 0,
        isTouching: flags & 0x02 != 0,
        identifier: flags >> 2 & 0x07,
        x: x,
        y: y
      )
    }

    let contacts = T1ContactSlots(
      first: contact(at: 0),
      second: contact(at: 1),
      third: contact(at: 2),
      fourth: contact(at: 3)
    )
    try validate(contacts)

    let frameFlags = payload[18]
    let reportedContactCount = frameFlags & 0x7F
    guard reportedContactCount <= T1DeviceIdentity.maximumContacts else {
      throw T1ReportDecodeError.invalidReportedContactCount(reportedContactCount)
    }
    return T1Frame(
      contacts: contacts,
      scanTime: UInt16(payload[16]) | (UInt16(payload[17]) << 8),
      reportedContactCount: reportedContactCount,
      isPrimaryButtonPressed: frameFlags & 0x80 != 0
    )
  }

  private static func validate(_ contacts: T1ContactSlots) throws {
    for slot in 0..<contactSlotCount {
      let contact = contacts[slot]
      guard
        !contact.isActive
          || (contact.x <= T1DeviceIdentity.maximumX && contact.y <= T1DeviceIdentity.maximumY)
      else {
        throw T1ReportDecodeError.invalidActiveContact(
          slot: slot,
          x: contact.x,
          y: contact.y
        )
      }
    }
  }
}
