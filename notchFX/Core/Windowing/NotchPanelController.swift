import AppKit
import SwiftUI

@MainActor
final class NotchPanelController {
    private let panel: NSPanel
    private let stateModel: NotchStateModel

    init(stateModel: NotchStateModel, engine: ActivityEngine) {
        self.stateModel = stateModel
        panel = Self.makePanel()

        let hostingView = PassthroughHostingView(rootView: NotchRootView(
            stateModel: stateModel,
            engine: engine
        ))
        hostingView.opaqueRectProvider = { [weak stateModel] in
            guard let stateModel else { return .zero }
            return ScreenGeometry.opaqueRectInWindow(for: stateModel.state)
        }
        panel.contentView = hostingView
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

    func handleOutsideClick(at screenLocation: NSPoint) {
        guard case .expanded = stateModel.state else { return }
        if !panel.frame.contains(screenLocation) {
            stateModel.collapse()
        }
    }

    private func positionOverNotch() {
        let screen = NSScreen.screens.first {
            ScreenGeometry.isNotchedDisplay(topSafeAreaInset: $0.safeAreaInsets.top)
        } ?? NSScreen.main

        guard let screen else { return }

        let anchor = ScreenGeometry.surfaceAnchorFrame(screenFrame: screen.frame)
        panel.setFrame(anchor, display: true)
    }

    private static func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: CGRect(x: 0, y: 0, width: ScreenGeometry.windowWidth, height: ScreenGeometry.windowHeight),
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

private final class PassthroughHostingView: NSHostingView<NotchRootView> {
    var opaqueRectProvider: () -> CGRect = { .zero }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        let generousRect = opaqueRectProvider().insetBy(dx: -6, dy: -6)
        guard generousRect.contains(local) else { return nil }
        return super.hitTest(point)
    }
}
