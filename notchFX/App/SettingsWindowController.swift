import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    init(settingsModel: SettingsModel) {
        let hosting = NSHostingController(
            rootView: SettingsView(settingsModel: settingsModel)
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

    func present() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
