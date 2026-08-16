import Foundation

private let settingsKey = "settings"
private let suiteName = "io.github.arun279.t1plus.settings"

public enum T1SettingsStore {
  public static func load() -> T1Settings {
    load(from: makeDefaults())
  }

  public static func save(_ settings: T1Settings) throws {
    try save(settings, to: makeDefaults())
  }

  public static func reset() {
    makeDefaults().removeObject(forKey: settingsKey)
  }

  static func load(from defaults: UserDefaults) -> T1Settings {
    guard
      let data = defaults.data(forKey: settingsKey),
      let settings = try? JSONDecoder().decode(T1Settings.self, from: data)
    else {
      return T1Settings()
    }
    return settings.validated()
  }

  static func save(_ settings: T1Settings, to defaults: UserDefaults) throws {
    defaults.set(try JSONEncoder().encode(settings.validated()), forKey: settingsKey)
  }

}

public final class T1SettingsObserver: NSObject {
  private let defaults: UserDefaults
  private let onChange: () -> Void

  public convenience init(onChange: @escaping () -> Void) {
    self.init(defaults: makeDefaults(), onChange: onChange)
  }

  init(defaults: UserDefaults, onChange: @escaping () -> Void) {
    self.defaults = defaults
    self.onChange = onChange
    super.init()
    defaults.addObserver(self, forKeyPath: settingsKey, options: [], context: nil)
  }

  deinit {
    defaults.removeObserver(self, forKeyPath: settingsKey)
  }

  public override func observeValue(
    forKeyPath keyPath: String?,
    of object: Any?,
    change: [NSKeyValueChangeKey: Any]?,
    context: UnsafeMutableRawPointer?
  ) {
    guard keyPath == settingsKey else {
      super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
      return
    }
    onChange()
  }
}

private func makeDefaults() -> UserDefaults {
  guard let defaults = UserDefaults(suiteName: suiteName) else {
    preconditionFailure("Could not open the T1 Plus settings domain")
  }
  return defaults
}
