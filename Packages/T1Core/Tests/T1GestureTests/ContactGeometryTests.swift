import T1Gestures
import T1Protocol
import XCTest

final class ContactGeometryTests: XCTestCase {
  func testCentroidUsesOnlyActiveContacts() {
    let inactive = T1Contact(
      slot: 2,
      isConfident: false,
      isTouching: true,
      identifier: 2,
      x: 4_000,
      y: 4_000
    )
    let frame = T1Frame(
      contacts: T1ContactSlots(
        first: activeContact(slot: 0, identifier: 0, x: 100, y: 300),
        second: activeContact(slot: 1, identifier: 1, x: 300, y: 500),
        third: inactive,
        fourth: T1Contact(
          slot: 3,
          isConfident: false,
          isTouching: false,
          identifier: 0,
          x: 0,
          y: 0
        )
      ),
      scanTime: 0,
      reportedContactCount: 2,
      isPrimaryButtonPressed: false
    )

    XCTAssertEqual(ContactGeometry.centroid(of: frame), T1Point(x: 200, y: 400))
  }

  func testCentroidIsNilWithoutActiveContacts() throws {
    let frame = try T1ReportDecoder.decode(reportID: 5, bytes: Array(repeating: 0, count: 19))

    XCTAssertNil(ContactGeometry.centroid(of: frame))
  }

  private func activeContact(
    slot: Int,
    identifier: UInt8,
    x: UInt16,
    y: UInt16
  ) -> T1Contact {
    T1Contact(
      slot: slot,
      isConfident: true,
      isTouching: true,
      identifier: identifier,
      x: x,
      y: y
    )
  }
}
