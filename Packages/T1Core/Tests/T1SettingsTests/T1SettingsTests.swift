import Foundation
import Testing

@testable import T1Settings

@Suite("T1 settings")
struct T1SettingsTests {
  @Test("Settings clamp gains and map to the gesture engine")
  func clampsAndMaps() {
    let settings = T1Settings(
      tapsEnabled: false,
      gesturesEnabled: false,
      invertScroll: true,
      pointerGain: 100,
      scrollGain: .nan
    )

    #expect(settings.pointerGain == T1Settings.pointerGainRange.upperBound)
    #expect(settings.scrollGain == 0.85)
    #expect(settings.gestureConfiguration.tapsEnabled == false)
    #expect(settings.gestureConfiguration.gesturesEnabled == false)
    #expect(settings.gestureConfiguration.invertScroll == true)
  }

  @Test("Store round-trips validated settings and resets to defaults")
  func storeRoundTrip() throws {
    let suiteName = "io.github.arun279.t1plus.tests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    var settings = T1Settings(tapsEnabled: false)
    settings.pointerGain = -50
    try T1SettingsStore.save(settings, to: defaults)

    let loaded = T1SettingsStore.load(from: defaults)
    #expect(loaded.tapsEnabled == false)
    #expect(loaded.pointerGain == T1Settings.pointerGainRange.lowerBound)

    defaults.removeObject(forKey: T1SettingsStore.settingsKey)
    #expect(T1SettingsStore.load(from: defaults) == T1Settings())
  }

  @Test("Unsupported settings versions fall back safely")
  func unsupportedVersion() throws {
    let suiteName = "io.github.arun279.t1plus.tests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set(
      Data(
        """
        {
          "version": 2,
          "tapsEnabled": false,
          "gesturesEnabled": false,
          "invertScroll": true,
          "pointerGain": 2,
          "scrollGain": 2
        }
        """.utf8
      ),
      forKey: T1SettingsStore.settingsKey
    )

    #expect(T1SettingsStore.load(from: defaults) == T1Settings())
  }

  @Test("Observer receives a specific settings-key change")
  func observesSettingsKey() throws {
    let suiteName = "io.github.arun279.t1plus.tests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let recorder = SettingsChangeRecorder()
    NotificationCenter.default.addObserver(
      recorder,
      selector: #selector(SettingsChangeRecorder.recordChange),
      name: T1SettingsObserver.changedNotification,
      object: nil
    )
    defer { NotificationCenter.default.removeObserver(recorder) }
    let observer = T1SettingsObserver(defaults: defaults)

    try T1SettingsStore.save(T1Settings(tapsEnabled: false), to: defaults)

    #expect(recorder.changeCount == 1)
    withExtendedLifetime(observer) {}
  }
}

private final class SettingsChangeRecorder: NSObject {
  private(set) var changeCount = 0

  @objc
  func recordChange() {
    changeCount += 1
  }
}
