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
    private let nowPlaying: NowPlayingActivityController

    init(
        stateModel: NotchStateModel,
        engine: ActivityEngine,
        settingsModel: SettingsModel,
        nowPlaying: NowPlayingActivityController
    ) {
        self.stateModel = stateModel
        self.engine = engine
        self.settingsModel = settingsModel
        self.nowPlaying = nowPlaying
        panel = NotchPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)

        let view = PassthroughHostingView(rootView: Self.makeRootView(
            stateModel: stateModel,
            engine: engine,
            settingsModel: settingsModel,
            surfaceStyle: .notch,
            nowPlaying: nowPlaying
        ))
        view.opaqueRectProvider = { [weak stateModel, weak settingsModel] in
            guard let stateModel else { return .zero }
            return ScreenGeometry.opaqueRectInWindow(
                for: stateModel.state,
                islandWidth: settingsModel?.settings.islandWidth ?? ScreenGeometry.defaultCompactWidth,
                islandHeight: settingsModel?.settings.islandHeight ?? ScreenGeometry.defaultCompactHeight
            )
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
        nfxTrace("SHOW inicio")
        if positionOverBestScreen() {
            nfxTrace("SHOW posición ok")
            panel.orderFrontRegardless()
        } else {
            nfxTrace("SHOW sin pantalla válida")
        }

        if ProcessInfo.processInfo.environment["NFX_DEBUG"] == "1" {
            let line = "\(Date()) panel wn=\(panel.windowNumber) ignores=\(panel.ignoresMouseEvents) frame=\(panel.frame) canBecomeKey=\(panel.canBecomeKey)\n"
            if let handle = FileHandle(forWritingAtPath: "/tmp/nfx_events.log") {
                handle.seekToEndOfFile()
                handle.write(line.data(using: .utf8)!)
                handle.closeFile()
            } else {
                try? line.write(toFile: "/tmp/nfx_events.log", atomically: true, encoding: .utf8)
            }
        }
    }

    func hide() {
        panel.orderOut(nil)
    }

    func isPointOverIsland(_ screenLocation: NSPoint) -> Bool {
        stateModel.state.isPresented && panel.frame.contains(screenLocation)
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
                surfaceStyle: currentSurfaceStyle,
                nowPlaying: nowPlaying
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

        if ProcessInfo.processInfo.environment["NFX_DEBUG"] == "1" {
            nfxTrace("POS pantalla=\(index) inset=\(inset) estilo=\(currentSurfaceStyle.rawValue) anchor=\(anchor) screenMaxY=\(screen.frame.maxY)")
        }
        return true
    }

    private static func makeRootView(
        stateModel: NotchStateModel,
        engine: ActivityEngine,
        settingsModel: SettingsModel,
        surfaceStyle: NotchSettings.SurfaceStyle,
        nowPlaying: NowPlayingActivityController
    ) -> NotchRootView {
        NotchRootView(
            stateModel: stateModel,
            engine: engine,
            settingsModel: settingsModel,
            surfaceStyle: surfaceStyle,
            nowPlaying: nowPlaying
        )
    }

    private static func makePanel() -> NSPanel {
        let panel = NotchPanel(
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
        if let notch = panel as? NotchPanel {
            notch.acceptsMouseMovedEvents = true
        }
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

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private var pendingClickLocation: NSPoint?

    override func mouseDown(with event: NSEvent) {
        pendingClickLocation = convert(event.locationInWindow, from: nil)
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        if let start = pendingClickLocation {
            let end = convert(event.locationInWindow, from: nil)
            let distance = hypot(end.x - start.x, end.y - start.y)

            if distance < 6 {
                if ProcessInfo.processInfo.environment["NFX_DEBUG"] == "1" {
                    nfxTrace("NATIVE CLICK en (\(Int(end.x)),\(Int(end.y)))")
                }
                NotificationCenter.default.post(name: .notchTapReceived, object: nil)
            }

            pendingClickLocation = nil
        }

        super.mouseUp(with: event)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        let rect = opaqueRectProvider()

        let accepted = rect.insetBy(dx: -6, dy: -6).contains(local)

        if ProcessInfo.processInfo.environment["NFX_DEBUG"] == "1" {
            let global = (window != nil) ? window!.convertToScreen(NSRect(origin: point, size: .zero)).origin : point
            nfxTrace("HITTEST local=(\(Int(local.x)),\(Int(local.y))) rect=\(rect) ok=\(accepted) global=(\(Int(global.x)),\(Int(global.y)))")
        }

        guard accepted else { return nil }
        return super.hitTest(point)
    }
}


final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    private var downLocation: NSPoint?

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            downLocation = event.locationInWindow

        case .leftMouseUp:
            if let down = downLocation {
                let up = event.locationInWindow
                let dragged = hypot(up.x - down.x, up.y - down.y) > 6
                if !dragged {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .notchTapReceived, object: nil)
                    }
                }
                downLocation = nil
            }

        default:
            break
        }

        super.sendEvent(event)
    }
}
