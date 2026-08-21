import AppKit
import Sparkle
import SwiftUI

@main
struct T1PlusApplication: App {
  // SwiftUI reads the adapter through the property wrapper.
  // swiftlint:disable unused_declaration
  @NSApplicationDelegateAdaptor(AppDelegate.self)
  private var appDelegate
  // swiftlint:enable unused_declaration
  @StateObject private var model = T1SupportModel()
  private let updaterController = SPUStandardUpdaterController(
    startingUpdater: true,
    updaterDelegate: nil,
    userDriverDelegate: nil
  )

  var body: some Scene {
    WindowGroup {
      SupportView(model: model, updater: updaterController.updater)
    }
    .windowResizability(.contentSize)
    .commands {
      CommandGroup(replacing: .newItem) {}
      CommandGroup(after: .appInfo) {
        CheckForUpdatesView(updater: updaterController.updater)
      }
    }
  }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
    true
  }
}
