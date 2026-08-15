import SwiftUI

@main
struct T1PlusApplication: App {
  var body: some Scene {
    WindowGroup {
      VStack(alignment: .leading, spacing: 12) {
        Text("T1 Plus Touchpad Support")
          .font(.title2)
        Text("The production helper is not enabled in this development build.")
          .foregroundStyle(.secondary)
      }
      .padding(24)
      .frame(minWidth: 440, minHeight: 180, alignment: .topLeading)
    }
    .windowResizability(.contentSize)
  }
}
