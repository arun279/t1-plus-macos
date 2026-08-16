import Foundation

private let suiteName = "io.github.arun279.t1plus.settings"

public enum T1SettingsStore {
  static let settingsKey = "t1PlusSettingsData"

  public static func load() -> T1Settings {
    load(from: makeDefaults())
  }

  public static func save(_ settings: T1Settings) throws {
    try save(settings, to: makeDefaults())
  }

  public static func reset() {
    makeDefaults().removeObject(forKey: Self.settingsKey)
  }

  static func load(from defaults: UserDefaults) -> T1Settings {
    guard
      let data = defaults.data(forKey: Self.settingsKey),
      let settings = try? JSONDecoder().decode(T1Settings.self, from: data)
    else {
      return T1Settings()
    }
    return settings.validated()
  }

  static func save(_ settings: T1Settings, to defaults: UserDefaults) throws {
    defaults.set(try JSONEncoder().encode(settings.validated()), forKey: Self.settingsKey)
  }
}

public final class T1SettingsObserver {
  public static let changedNotification = Notification.Name(
    "io.github.arun279.t1plus.settings.changed"
  )

  private let defaults: UserDefaults
  private var observation: NSKeyValueObservation?

  public convenience init() {
    self.init(defaults: makeDefaults())
  }

  init(defaults: UserDefaults) {
    self.defaults = defaults
    observation = defaults.observe(\.t1PlusSettingsData, options: []) { _, _ in
      NotificationCenter.default.post(name: Self.changedNotification, object: nil)
    }
  }
}

extension UserDefaults {
  @objc fileprivate dynamic var t1PlusSettingsData: Data? {
    data(forKey: T1SettingsStore.settingsKey)
  }
}

private func makeDefaults() -> UserDefaults {
  guard let defaults = UserDefaults(suiteName: suiteName) else {
    preconditionFailure("Could not open the T1 Plus settings domain")
  }
  return defaults
}
