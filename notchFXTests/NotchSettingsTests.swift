import Foundation
import Testing
@testable import notchFXApp

@MainActor
struct NotchSettingsTests {
    private func makeDefaults(name: String) -> UserDefaults {
        let suite = "notchfx.tests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func emptyStorageYieldsStandardSettings() {
        let store = SettingsStore(defaults: makeDefaults(name: "empty"))
        #expect(store.load() == .standard)
    }

    @Test func corruptedBlobFallsBackToStandard() {
        let defaults = makeDefaults(name: "corrupt")
        defaults.set(Data("{{{ not json".utf8), forKey: "settings.config.v1")
        let store = SettingsStore(defaults: defaults)
        #expect(store.load() == .standard)
    }

    @Test func unknownEnumValueFallsBackToStandard() {
        let defaults = makeDefaults(name: "unknownenum")
        defaults.set(Data(#"{"displayMode":"hologram"}"#.utf8), forKey: "settings.config.v1")
        let store = SettingsStore(defaults: defaults)
        #expect(store.load().displayMode == .auto)
    }

    @Test func roundtripPreservesValues() {
        let defaults = makeDefaults(name: "roundtrip")
        let store = SettingsStore(defaults: defaults)

        var custom = NotchSettings.standard
        custom.displayMode = .mainScreen
        custom.surfaceStyle = .capsule
        custom.swipeDismissEnabled = false
        custom.alertDuration = 8
        store.save(custom)

        #expect(store.load() == custom)
    }

    @Test func sanitizeClampsAlertDuration() {
        var low = NotchSettings.standard
        low.alertDuration = 0.5
        #expect(low.sanitized().alertDuration == 2)

        var high = NotchSettings.standard
        high.alertDuration = 999
        #expect(high.sanitized().alertDuration == 15)
    }

    @Test func updatePersistsAndPublishes() {
        final class Recorder {
            var count = 0
        }
        let recorder = Recorder()

        let defaults = makeDefaults(name: "update")
        let model = SettingsModel(store: SettingsStore(defaults: defaults))
        let cancellable = model.objectWillChange.sink { _ in
            recorder.count += 1
        }

        model.update { $0.displayMode = .notchedScreen }
        _ = cancellable

        #expect(recorder.count >= 1)
        #expect(model.settings.displayMode == .notchedScreen)

        let reloaded = SettingsStore(defaults: defaults).load()
        #expect(reloaded.displayMode == .notchedScreen)
    }

    @Test func updateClampsInvalidDuration() {
        let model = SettingsModel(store: SettingsStore(defaults: makeDefaults(name: "clamp")))

        model.update { $0.alertDuration = 99 }
        #expect(model.settings.alertDuration == 15)

        model.update { $0.alertDuration = 0 }
        #expect(model.settings.alertDuration == 2)

        model.update { $0.alertDuration = 7 }
        #expect(model.settings.alertDuration == 7)
    }

    @Test func updateTransformsSurfaceStyle() {
        let defaults = makeDefaults(name: "style")
        let model = SettingsModel(store: SettingsStore(defaults: defaults))

        model.update { $0.surfaceStyle = .capsule }
        #expect(model.settings.surfaceStyle == .capsule)

        model.update { $0.surfaceStyle = .notch }
        #expect(model.settings.surfaceStyle == .notch)
        #expect(SettingsStore(defaults: defaults).load().surfaceStyle == .notch)
    }

    @Test func updatePersistsSwipeDismiss() {
        let defaults = makeDefaults(name: "swipe")
        let model = SettingsModel(store: SettingsStore(defaults: defaults))

        model.update { $0.swipeDismissEnabled = false }
        #expect(model.settings.swipeDismissEnabled == false)
        #expect(SettingsStore(defaults: defaults).load().swipeDismissEnabled == false)
    }
}
