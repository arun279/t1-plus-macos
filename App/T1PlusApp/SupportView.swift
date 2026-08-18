import Foundation
import SwiftUI
import T1Settings
import UniformTypeIdentifiers

struct SupportView: View {
  @ObservedObject var model: T1SupportModel
  @Environment(\.scenePhase)
  private var scenePhase
  @State private var diagnosticsDocument = DiagnosticsDocument(text: "")
  @State private var exportingDiagnostics = false
  @State private var confirmingUninstall = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        header
        status
        permissions
        support
        error
        notice
        touchpadSettings
        diagnosticsAndUninstall
        privacy
      }
      .padding(24)
    }
    .frame(width: 560, height: 720)
    .onChange(of: scenePhase) { phase in
      if phase == .active {
        model.applicationDidBecomeActive()
      }
    }
    .fileExporter(
      isPresented: $exportingDiagnostics,
      document: diagnosticsDocument,
      contentType: .plainText,
      defaultFilename: "t1-plus-diagnostics"
    ) { result in
      model.completeDiagnosticsExport(result)
    }
    .alert(
      "Prepare T1 Plus for uninstall?",
      isPresented: $confirmingUninstall
    ) {
      Button("Prepare for Uninstall", role: .destructive) {
        model.prepareForUninstall()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "This stops and unregisters the background agent and resets app settings. "
          + "It does not change the touchpad, remove macOS permissions, or delete the app. "
          + "Afterward, move the app to Trash."
      )
    }
  }
}

private extension SupportView {
  private var status: some View {
    GroupBox("Status") {
      HStack(spacing: 20) {
        StatusValue(
          title: model.deviceConnected ? "T1 Plus connected" : "T1 Plus not connected",
          systemImage: model.deviceConnected ? "checkmark.circle.fill" : "circle.dashed",
          active: model.deviceConnected
        )
        Divider()
        StatusValue(
          title: "Support \(model.supportStatus.lowercased())",
          systemImage: model.supportEnabled ? "checkmark.circle.fill" : "circle",
          active: model.supportEnabled
        )
        Spacer()
        Button("Refresh") {
          model.refresh()
        }
      }
      .frame(minHeight: 34)
      .padding(.horizontal, 4)
      .padding(.vertical, 6)
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
      .padding(.horizontal, 4)
      .padding(.vertical, 6)
    }
  }

  private var support: some View {
    GroupBox("Support") {
      VStack(alignment: .leading, spacing: 12) {
        Toggle(
          isOn: Binding(
            get: { model.supportEnabled },
            set: { enabled in model.setSupportEnabled(enabled) }
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
        .accessibilityIdentifier("enable-support-toggle")
        .accessibilityLabel("Enable T1 Plus support")
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

        Text(
          "The T1 Plus can be paired before or after support is enabled. "
            + "The helper waits for it and reconnects automatically."
        )
        .font(.callout)
        .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 4)
      .padding(.vertical, 6)
    }
  }

  @ViewBuilder private var error: some View {
    if let errorMessage = model.errorMessage {
      Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
        .font(.callout)
        .foregroundStyle(.red)
        .textSelection(.enabled)
    }
  }

  @ViewBuilder private var notice: some View {
    if let noticeMessage = model.noticeMessage {
      Label(noticeMessage, systemImage: "checkmark.circle.fill")
        .font(.callout)
        .foregroundStyle(.green)
        .textSelection(.enabled)
    }
  }

  private var touchpadSettings: some View {
    GroupBox("Touchpad") {
      VStack(alignment: .leading, spacing: 14) {
        SettingsSlider(
          title: "Pointer speed",
          value: Binding(
            get: { model.settings.pointerGain },
            set: { value in
              model.updateSettings(persist: false) { $0.pointerGain = value }
            }
          ),
          range: T1Settings.pointerGainRange,
          onEditingChanged: { editing in
            if !editing {
              model.saveSettings()
            }
          }
        )
        Divider()
        Toggle(
          "Tap to click",
          isOn: Binding(
            get: { model.settings.tapsEnabled },
            set: { enabled in
              model.updateSettings { $0.tapsEnabled = enabled }
            }
          )
        )
        Divider()
        SettingsSlider(
          title: "Scroll speed",
          value: Binding(
            get: { model.settings.scrollGain },
            set: { value in
              model.updateSettings(persist: false) { $0.scrollGain = value }
            }
          ),
          range: T1Settings.scrollGainRange,
          onEditingChanged: { editing in
            if !editing {
              model.saveSettings()
            }
          }
        )
        Divider()
        Toggle(
          "Reverse scroll direction",
          isOn: Binding(
            get: { model.settings.invertScroll },
            set: { enabled in
              model.updateSettings { $0.invertScroll = enabled }
            }
          )
        )
        Toggle(
          "Pinch and three- or four-finger gestures",
          isOn: Binding(
            get: { model.settings.gesturesEnabled },
            set: { enabled in
              model.updateSettings { $0.gesturesEnabled = enabled }
            }
          )
        )
        HStack {
          Spacer()
          Button("Restore Defaults") {
            model.resetSettings()
          }
        }
      }
      .padding(.horizontal, 4)
      .padding(.vertical, 6)
    }
  }

  private var diagnosticsAndUninstall: some View {
    GroupBox("Diagnostics and Uninstall") {
      VStack(alignment: .leading, spacing: 12) {
        Text(
          "Diagnostics include only version, architecture, permission, device, support, "
            + "backend, and bounded settings status. They never include touch data, logs, "
            + "user identity, paths, or serial numbers."
        )
        .font(.callout)
        .foregroundStyle(.secondary)

        HStack {
          Button("Save Diagnostics…") {
            diagnosticsDocument = DiagnosticsDocument(text: model.makeDiagnosticsReport())
            exportingDiagnostics = true
          }
          Spacer()
          Button("Prepare for Uninstall…", role: .destructive) {
            confirmingUninstall = true
          }
        }
      }
      .padding(.horizontal, 4)
      .padding(.vertical, 6)
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

private struct DiagnosticsDocument: FileDocument {
  static let readableContentTypes: [UTType] = [.plainText]

  let text: String

  init(text: String) {
    self.text = text
  }

  init(configuration: ReadConfiguration) throws {
    guard
      let data = configuration.file.regularFileContents,
      let text = String(data: data, encoding: .utf8)
    else {
      throw CocoaError(.fileReadCorruptFile)
    }
    self.text = text
  }

  func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: Data(text.utf8))
  }
}

private struct StatusValue: View {
  let title: String
  let systemImage: String
  let active: Bool

  var body: some View {
    Label(title, systemImage: systemImage)
      .foregroundStyle(active ? .green : .secondary)
  }
}

private struct SettingsSlider: View {
  let title: String
  @Binding var value: Double
  let range: ClosedRange<Double>
  let onEditingChanged: (Bool) -> Void

  var body: some View {
    HStack(spacing: 12) {
      Text(title)
        .frame(width: 100, alignment: .leading)
      Slider(value: $value, in: range, onEditingChanged: onEditingChanged)
        .accessibilityLabel(title)
      Text(value, format: .number.precision(.fractionLength(2)))
        .monospacedDigit()
        .frame(width: 36, alignment: .trailing)
    }
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
          .frame(minWidth: 108, alignment: .trailing)
      } else {
        Button(actionTitle, action: action)
          .frame(minWidth: 108, alignment: .trailing)
      }
    }
  }
}
