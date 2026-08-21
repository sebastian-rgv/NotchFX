import AppKit
import Combine
import SwiftUI

@MainActor
final class NotchPanelController {
    private let panel: NSPanel
    private let stateModel: NotchStateModel
    private let engine: ActivityEngine
    private let settingsModel: SettingsModel
    private let hostingView: PassthroughHostingView

    private var currentSurfaceStyle: NotchSettings.SurfaceStyle = .notch
    private var settingsCancellable: AnyCancellable?

    init(
        stateModel: NotchStateModel,
        engine: ActivityEngine,
        settingsModel: SettingsModel
    ) {
        self.stateModel = stateModel
        self.engine = engine
        self.settingsModel = settingsModel
        panel = Self.makePanel()

        let view = PassthroughHostingView(rootView: Self.makeRootView(
            stateModel: stateModel,
            engine: engine,
            settingsModel: settingsModel,
            surfaceStyle: .notch
        ))
        view.opaqueRectProvider = { [weak stateModel] in
            guard let stateModel else { return .zero }
            return ScreenGeometry.opaqueRectInWindow(for: stateModel.state)
        }

        hostingView = view
        panel.contentView = view

        settingsCancellable = settingsModel.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshLayout()
            }
        }

        _ = positionOverBestScreen()
    }

    func show() {
        if positionOverBestScreen() {
            panel.orderFrontRegardless()
        }
    }

    func hide() {
        panel.orderOut(nil)
    }

    func handleOutsideClick(at screenLocation: NSPoint) {
        guard case .expanded = stateModel.state else { return }
        if !panel.frame.contains(screenLocation) {
            stateModel.collapse()
        }
    }

    private func refreshLayout() {
        if positionOverBestScreen() && panel.isVisible {
            hostingView.rootView = Self.makeRootView(
                stateModel: stateModel,
                engine: engine,
                settingsModel: settingsModel,
                surfaceStyle: currentSurfaceStyle
            )
        }
    }

    @discardableResult
    private func positionOverBestScreen() -> Bool {
        let screens = NSScreen.screens
        let candidates = screens.map {
            ScreenCandidate(
                topSafeAreaInset: $0.safeAreaInsets.top,
                isMain: $0 == NSScreen.main
            )
        }

        guard let index = DisplayTargetResolver.pickIndex(
            mode: settingsModel.settings.displayMode,
            screens: candidates
        ) else {
            hide()
            return false
        }

        let screen = screens[index]
        let inset = candidates[index].topSafeAreaInset

        currentSurfaceStyle = DisplayTargetResolver.effectiveStyle(
            preferred: settingsModel.settings.surfaceStyle,
            topSafeAreaInset: inset
        )

        let anchor = ScreenGeometry.surfaceAnchorFrame(
            screenFrame: screen.frame,
            topSafeAreaInset: inset,
            style: currentSurfaceStyle
        )
        panel.setFrame(anchor, display: true)
        return true
    }

    private static func makeRootView(
        stateModel: NotchStateModel,
        engine: ActivityEngine,
        settingsModel: SettingsModel,
        surfaceStyle: NotchSettings.SurfaceStyle
    ) -> NotchRootView {
        NotchRootView(
            stateModel: stateModel,
            engine: engine,
            settingsModel: settingsModel,
            surfaceStyle: surfaceStyle
        )
    }

    private static func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: CGRect(
                x: 0,
                y: 0,
                width: ScreenGeometry.windowWidth,
                height: ScreenGeometry.windowHeight
            ),
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
