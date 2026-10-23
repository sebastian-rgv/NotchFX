import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    private let settingsModel: SettingsModel
    private let characters: CharacterSessionController

    init(settingsModel: SettingsModel, characters: CharacterSessionController) {
        self.settingsModel = settingsModel
        self.characters = characters

        let hosting = NSHostingController(
            rootView: SettingsView(
                settingsModel: settingsModel,
                characters: characters
            )
        )

        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable]
        window.title = "NotchFX — Ajustes"
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.setContentSize(NSSize(width: 620, height: 400))
        window.center()

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) no está soportado")
    }

    func present(section: SettingsSection = .general) {
        if let window {
            window.contentViewController = NSHostingController(
                rootView: SettingsView(
                    settingsModel: settingsModel,
                    characters: characters,
                    initialSection: section
                )
            )
            window.setContentSize(NSSize(width: 620, height: 400))
        }

        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
