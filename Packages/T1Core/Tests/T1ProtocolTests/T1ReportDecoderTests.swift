import T1Protocol
import XCTest

final class T1ReportDecoderTests: XCTestCase {
  func testDecodesFourSlotsAndFrameMetadata() throws {
    let payload =
      packContact(isConfident: true, isTouching: true, identifier: 3, x: 2557, y: 1154)
      + packContact(isConfident: true, isTouching: true, identifier: 6, x: 1234, y: 567)
      + packContact(isConfident: false, isTouching: false, identifier: 0, x: 0, y: 0)
      + packContact(isConfident: false, isTouching: false, identifier: 0, x: 0, y: 0)
      + [0x34, 0x12, 0x82]

    let frame = try T1ReportDecoder.decode(reportID: 5, bytes: payload)

    XCTAssertEqual(frame.scanTime, 0x1234)
    XCTAssertEqual(frame.reportedContactCount, 2)
    XCTAssertTrue(frame.isPrimaryButtonPressed)
    XCTAssertEqual(frame.activeContactCount, 2)
    XCTAssertEqual(
      frame.contacts.first,
      T1Contact(
        slot: 0,
        isConfident: true,
        isTouching: true,
        identifier: 3,
        x: 2557,
        y: 1154
      )
    )
    XCTAssertEqual(frame.contacts.second.x, 1234)
    XCTAssertEqual(frame.contacts.second.y, 567)
  }

  func testAcceptsLeadingReportID() throws {
    let frame = try T1ReportDecoder.decode(reportID: 5, bytes: [5] + Array(repeating: 0, count: 19))

    XCTAssertEqual(frame.reportedContactCount, 0)
  }

  func testRejectsUnsupportedReportID() {
    XCTAssertThrowsError(
      try T1ReportDecoder.decode(reportID: 4, bytes: Array(repeating: 0, count: 19))
    ) {
      XCTAssertEqual($0 as? T1ReportDecodeError, .unsupportedReportID(4))
    }
  }

  func testRejectsMalformedLength() {
    XCTAssertThrowsError(
      try T1ReportDecoder.decode(reportID: 5, bytes: Array(repeating: 0, count: 18))
    ) {
      XCTAssertEqual($0 as? T1ReportDecodeError, .invalidReportLength(18))
    }
  }

  func testRejectsActiveContactOutsideDescriptorSurface() {
    let payload =
      packContact(isConfident: true, isTouching: true, identifier: 1, x: 2558, y: 1154)
      + Array(repeating: 0, count: 15)

    XCTAssertThrowsError(try T1ReportDecoder.decode(reportID: 5, bytes: payload)) {
      XCTAssertEqual(
        $0 as? T1ReportDecodeError,
        .invalidActiveContact(slot: 0, x: 2558, y: 1154)
      )
    }
  }

  func testAllowsInactiveCoordinatesOutsideDescriptorSurface() throws {
    let payload =
      packContact(isConfident: false, isTouching: false, identifier: 1, x: 4095, y: 4095)
      + Array(repeating: 0, count: 15)

    let frame = try T1ReportDecoder.decode(reportID: 5, bytes: payload)

    XCTAssertEqual(frame.activeContactCount, 0)
  }

  func testRejectsReportedContactCountAboveCapacity() {
    var payload = Array(repeating: UInt8(0), count: 19)
    payload[18] = 5

    XCTAssertThrowsError(try T1ReportDecoder.decode(reportID: 5, bytes: payload)) {
      XCTAssertEqual($0 as? T1ReportDecodeError, .invalidReportedContactCount(5))
    }
  }

  private func packContact(
    isConfident: Bool,
    isTouching: Bool,
    identifier: UInt8,
    x: UInt16,
    y: UInt16
  ) -> [UInt8] {
    let flags = UInt8(isConfident ? 1 : 0) | UInt8(isTouching ? 2 : 0) | (identifier & 0x07) << 2
    return [
      flags,
      UInt8(truncatingIfNeeded: x),
      UInt8(truncatingIfNeeded: x >> 8) & 0x0F | UInt8(truncatingIfNeeded: y) << 4,
      UInt8(truncatingIfNeeded: y >> 4),
    ]
  }
}
