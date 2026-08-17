import AppKit
import SwiftUI

@main
struct T1PlusApplication: App {
  // SwiftUI reads the adapter through the property wrapper.
  // swiftlint:disable unused_declaration
  @NSApplicationDelegateAdaptor(AppDelegate.self)
  private var appDelegate
  // swiftlint:enable unused_declaration
  @StateObject private var model = T1SupportModel()

  var body: some Scene {
    WindowGroup {
      SupportView(model: model)
    }
    .windowResizability(.contentSize)
    .commands {
      CommandGroup(replacing: .newItem) {}
    }
  }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
    true
  }
}
