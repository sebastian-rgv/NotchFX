import Combine
import Foundation

struct SettingsStore {
    private let defaults: UserDefaults
    private let storageKey = "settings.config.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> NotchSettings {
        guard let data = defaults.data(forKey: storageKey) else {
            return .standard
        }
        guard let decoded = try? JSONDecoder().decode(NotchSettings.self, from: data) else {
            return .standard
        }
        return decoded.sanitized()
    }

    func save(_ settings: NotchSettings) {
        let valid = settings.sanitized()
        guard let data = try? JSONEncoder().encode(valid) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

@MainActor
final class SettingsModel: ObservableObject {
    @Published private(set) var settings: NotchSettings

    private let store: SettingsStore

    init(store: SettingsStore = SettingsStore()) {
        self.store = store
        self.settings = store.load()
    }

    func update(_ transform: (inout NotchSettings) -> Void) {
        var next = settings
        transform(&next)
        next = next.sanitized()
        settings = next
        store.save(next)

        if ProcessInfo.processInfo.environment["NFX_DEBUG"] == "1" {
            let line = "update w=\(Int(next.islandWidth)) h=\(Int(next.islandHeight)) modo=\(next.displayMode.rawValue)\n"
            if let handle = FileHandle(forWritingAtPath: "/tmp/nfx_settings.log") {
                handle.seekToEndOfFile()
                handle.write(line.data(using: .utf8)!)
                handle.closeFile()
            } else {
                try? line.write(toFile: "/tmp/nfx_settings.log", atomically: true, encoding: .utf8)
            }
        }
    }
}
