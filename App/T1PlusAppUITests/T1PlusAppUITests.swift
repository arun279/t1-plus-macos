import XCTest

@MainActor
final class T1PlusAppUITests: XCTestCase {
  func testEssentialControlsAndRemovalDisclosure() {
    let app = launchApp()
    defer { app.terminate() }

    assertExists(app.staticTexts["T1 Plus Touchpad Support"])
    assertExists(app.staticTexts["Permissions"])
    assertExists(app.staticTexts["Support"])
    assertExists(app.staticTexts["Touchpad"])
    assertExists(app.staticTexts["Diagnostics and Removal"])

    let enableSupportToggle =
      app.descendants(matching: .any).matching(identifier: "enable-support-toggle").firstMatch
    assertExists(enableSupportToggle)
    XCTAssertTrue(
      enableSupportToggle.elementType == .switch || enableSupportToggle.elementType == .checkBox,
      "The Enable T1 Plus support control is not exposed as a toggle."
    )

    assertExists(app.sliders["Pointer speed"])
    assertExists(app.sliders["Scroll speed"])
    assertExists(app.buttons["Save Diagnostics…"])

    let removeSupport = app.buttons["Remove Support…"]
    let scrollView = app.scrollViews.firstMatch
    for _ in 0..<4 where !removeSupport.isHittable {
      scrollView.swipeUp()
    }
    XCTAssertTrue(removeSupport.isHittable, "The Remove Support button is not reachable.")
    removeSupport.click()
    let removalAlert = app.sheets.firstMatch
    assertExists(removalAlert)
    let cancel = removalAlert.buttons["Cancel"]
    assertExists(cancel)
    assertExists(removalAlert.buttons["Remove Support"])
    let removalDisclosure =
      "This unregisters the background helper and clears app settings. "
      + "It does not change the touchpad or its firmware. macOS keeps granted permissions "
      + "until you remove them in System Settings."
    assertExists(
      removalAlert.staticTexts.matching(
        NSPredicate(format: "value == %@", removalDisclosure)
      ).firstMatch
    )
    cancel.click()
  }

  func testClosingLastWindowTerminatesApp() {
    let app = launchApp()

    let closeButton = app.windows.firstMatch.buttons[XCUIIdentifierCloseWindow]
    assertExists(closeButton)
    closeButton.click()
    XCTAssertTrue(
      app.wait(for: .notRunning, timeout: 5),
      "The app remained running after its last window closed."
    )
  }

  private func launchApp() -> XCUIApplication {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launch()
    XCTAssertTrue(
      app.windows.firstMatch.waitForExistence(timeout: 5),
      "The app did not present its main window."
    )
    return app
  }

  private func assertExists(
    _ element: XCUIElement,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertTrue(
      element.waitForExistence(timeout: 2),
      "Missing UI element: \(element)",
      file: file,
      line: line
    )
  }
}
