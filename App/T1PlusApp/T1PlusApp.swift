import SwiftUI

@main
struct T1PlusApplication: App {
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
