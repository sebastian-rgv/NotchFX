import AppKit
import SwiftUI

@MainActor
final class NotchPanelController {
    private let panel: NSPanel
    private let stateModel: NotchStateModel

    init(stateModel: NotchStateModel) {
        self.stateModel = stateModel
        panel = Self.makePanel()
        panel.contentView = NSHostingView(rootView: NotchRootView(stateModel: stateModel))
        positionOverNotch()
    }

    func show() {
        positionOverNotch()
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    func reposition() {
        positionOverNotch()
    }

    private func positionOverNotch() {
        let screen = NSScreen.screens.first {
            ScreenGeometry.isNotchedDisplay(topSafeAreaInset: $0.safeAreaInsets.top)
        } ?? NSScreen.main

        guard let screen else { return }

        let anchor = ScreenGeometry.notchAnchorFrame(screenFrame: screen.frame)
        panel.setFrame(anchor, display: true)
    }

    private static func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.ignoresMouseEvents = false
        panel.hidesOnDeactivate = false
        return panel
    }
}
