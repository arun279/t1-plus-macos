import Combine
import Sparkle
import SwiftUI

@MainActor
final class CheckForUpdatesViewModel: ObservableObject {
  @Published private(set) var canCheckForUpdates = false

  init(updater: SPUUpdater) {
    updater.publisher(for: \.canCheckForUpdates)
      .assign(to: &$canCheckForUpdates)
  }
}

struct CheckForUpdatesView: View {
  @ObservedObject private var model: CheckForUpdatesViewModel
  private let updater: SPUUpdater

  init(updater: SPUUpdater) {
    self.updater = updater
    model = CheckForUpdatesViewModel(updater: updater)
  }

  var body: some View {
    Button("Check for Updates…", action: updater.checkForUpdates)
      .disabled(!model.canCheckForUpdates)
  }
}

struct UpdaterSettingsView: View {
  private let updater: SPUUpdater
  @State private var automaticallyChecksForUpdates: Bool
  @State private var automaticallyDownloadsUpdates: Bool

  init(updater: SPUUpdater) {
    self.updater = updater
    automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
    automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
  }

  var body: some View {
    GroupBox("Updates") {
      VStack(alignment: .leading, spacing: 14) {
        Toggle(
          "Automatically check for updates",
          isOn: $automaticallyChecksForUpdates
        )
        .accessibilityIdentifier("automatically-check-updates-toggle")
        .onChange(of: automaticallyChecksForUpdates) { enabled in
          updater.automaticallyChecksForUpdates = enabled
        }
        Toggle(
          "Automatically download and install updates",
          isOn: $automaticallyDownloadsUpdates
        )
        .accessibilityIdentifier("automatically-install-updates-toggle")
        .disabled(!automaticallyChecksForUpdates)
        .onChange(of: automaticallyDownloadsUpdates) { enabled in
          updater.automaticallyDownloadsUpdates = enabled
        }
        Divider()
        HStack {
          Text("Updates are signed and verified. Automatic checks run only while this app is open.")
            .font(.callout)
            .foregroundStyle(.secondary)
          Spacer()
          CheckForUpdatesView(updater: updater)
        }
      }
      .padding(.horizontal, 4)
      .padding(.vertical, 6)
    }
  }
}
