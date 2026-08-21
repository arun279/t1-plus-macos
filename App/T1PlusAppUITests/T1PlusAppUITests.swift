import XCTest

@MainActor
final class T1PlusAppUITests: XCTestCase {
  func testEssentialControlsAndUninstallDisclosure() {
    let app = launchApp()
    defer { app.terminate() }

    assertExists(app.staticTexts["T1 Plus Touchpad Support"])
    assertExists(app.staticTexts["Permissions"])
    assertExists(app.staticTexts["Touchpad"])
    assertExists(app.staticTexts["Settings"])
    assertExists(app.staticTexts["Updates"])
    assertExists(app.staticTexts["Diagnostics and Uninstall"])

    let touchpadToggle =
      app.descendants(matching: .any).matching(identifier: "touchpad-enabled-toggle").firstMatch
    assertExists(touchpadToggle)
    XCTAssertTrue(
      touchpadToggle.elementType == .switch || touchpadToggle.elementType == .checkBox,
      "The touchpad control is not exposed as a toggle."
    )

    assertExists(app.sliders["Pointer speed"])
    assertExists(app.sliders["Scroll speed"])
    assertExists(app.buttons["Save Diagnostics…"])

    assertUpdateControls(app)

    let prepareForUninstall = app.buttons["Prepare for Uninstall…"]
    let scrollView = app.scrollViews.firstMatch
    for _ in 0..<4 where !prepareForUninstall.isHittable {
      scrollView.swipeUp()
    }
    XCTAssertTrue(
      prepareForUninstall.isHittable,
      "The Prepare for Uninstall button is not reachable."
    )
    prepareForUninstall.click()
    let uninstallAlert = app.sheets.firstMatch
    assertExists(uninstallAlert)
    let cancel = uninstallAlert.buttons["Cancel"]
    assertExists(cancel)
    assertExists(uninstallAlert.buttons["Prepare for Uninstall"])
    let uninstallDisclosure =
      "This stops and unregisters the background agent and resets app settings. "
      + "It does not change the touchpad, remove macOS permissions, or delete the app. "
      + "Afterward, move the app to Trash."
    assertExists(
      uninstallAlert.staticTexts.matching(
        NSPredicate(format: "value == %@", uninstallDisclosure)
      ).firstMatch
    )
    cancel.click()
  }

  private func assertUpdateControls(_ app: XCUIApplication) {
    let checkForUpdates = app.buttons["Check for Updates…"]
    let automaticChecks =
      app.descendants(matching: .any).matching(
        identifier: "automatically-check-updates-toggle"
      ).firstMatch
    let automaticInstall =
      app.descendants(matching: .any).matching(
        identifier: "automatically-install-updates-toggle"
      ).firstMatch
    let scrollView = app.scrollViews.firstMatch
    for _ in 0..<4 where !checkForUpdates.isHittable {
      scrollView.swipeUp()
    }
    XCTAssertTrue(checkForUpdates.isHittable, "The update action is not reachable.")
    assertExists(automaticChecks)
    assertExists(automaticInstall)
    assertExists(
      app.staticTexts[
        "Updates are signed and verified. Automatic checks run only while this app is open."
      ]
    )
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
