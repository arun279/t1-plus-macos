import SwiftUI

struct SupportView: View {
  @ObservedObject var model: T1SupportModel
  @Environment(\.scenePhase)
  private var scenePhase

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      header
      permissions
      support
      privacy
    }
    .padding(24)
    .frame(width: 560, alignment: .topLeading)
    .fixedSize(horizontal: false, vertical: true)
    .onChange(of: scenePhase) { phase in
      if phase == .active {
        model.refresh()
      }
    }
  }

  private var header: some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: "hand.draw")
        .font(.system(size: 30))
        .foregroundStyle(.tint)
        .frame(width: 38, height: 38)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 4) {
        Text("T1 Plus Touchpad Support")
          .font(.title2.weight(.semibold))
        Text("Grant two macOS permissions once, then enable support.")
          .foregroundStyle(.secondary)
      }
    }
  }

  private var permissions: some View {
    GroupBox("Permissions") {
      VStack(spacing: 0) {
        PermissionRow(
          title: "Input Monitoring",
          explanation: "Reads touch reports only from the exact T1 Plus device.",
          granted: model.inputMonitoringGranted,
          actionTitle: "Request Access",
          action: model.requestInputMonitoring
        )
        Divider()
          .padding(.vertical, 12)
        PermissionRow(
          title: "Accessibility",
          explanation: "Posts pointer, click, scroll, and gesture events to macOS.",
          granted: model.eventPostingGranted,
          actionTitle: "Request Access",
          action: model.requestEventPosting
        )
      }
      .padding(.top, 4)
    }
  }

  private var support: some View {
    GroupBox("Support") {
      VStack(alignment: .leading, spacing: 12) {
        Toggle(
          isOn: Binding(
            get: { model.supportEnabled },
            set: model.setSupportEnabled
          )
        ) {
          VStack(alignment: .leading, spacing: 2) {
            Text("Enable T1 Plus support")
            Text("Runs a small background helper while you are signed in.")
              .font(.callout)
              .foregroundStyle(.secondary)
          }
        }
        .toggleStyle(.switch)
        .disabled(!model.supportEnabled && !model.canEnableSupport)

        if !model.canEnableSupport {
          Text("Grant both permissions to enable support.")
            .font(.callout)
            .foregroundStyle(.secondary)
        }

        if model.serviceState == .requiresApproval {
          HStack {
            Text("macOS requires approval for this background item.")
              .font(.callout)
            Spacer()
            Button("Open Login Items", action: model.openLoginItemSettings)
          }
        }

        if let errorMessage = model.errorMessage {
          Text(errorMessage)
            .font(.callout)
            .foregroundStyle(.red)
            .textSelection(.enabled)
        }

        Text(
          "The T1 Plus can be paired before or after support is enabled. "
            + "The helper waits for it and reconnects automatically."
        )
        .font(.callout)
        .foregroundStyle(.secondary)
      }
      .padding(.top, 4)
    }
  }

  private var privacy: some View {
    Label(
      "Touch data is processed locally and is never recorded or sent anywhere.",
      systemImage: "lock.shield"
    )
    .font(.callout)
    .foregroundStyle(.secondary)
  }
}

private struct PermissionRow: View {
  let title: String
  let explanation: String
  let granted: Bool
  let actionTitle: String
  let action: () -> Void

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      Image(systemName: granted ? "checkmark.circle.fill" : "circle")
        .foregroundStyle(granted ? .green : .secondary)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
        Text(explanation)
          .font(.callout)
          .foregroundStyle(.secondary)
      }
      Spacer(minLength: 16)
      if granted {
        Text("Granted")
          .font(.callout.weight(.medium))
          .foregroundStyle(.secondary)
      } else {
        Button(actionTitle, action: action)
      }
    }
  }
}
