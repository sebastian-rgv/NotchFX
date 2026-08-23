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
    private var lastScreenFrame: CGRect = .zero
    private var lastTopInset: CGFloat = 0
    private var lastHandledTapAt = Date.distantPast
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
        panel = NotchPanel(contentRect: .zero, styleMask: [.titled, .nonactivatingPanel, .fullSizeContentView], backing: .buffered, defer: false)

        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.toolbarStyle = .unifiedCompact
        panel.isFloatingPanel = true
        panel.animationBehavior = .none
        panel.isMovable = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.acceptsMouseMovedEvents = true
        panel.level = NSWindow.Level.mainMenu + 3
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

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
            let line = "\(Date()) panel wn=\(panel.windowNumber) level=\(panel.level.rawValue) ignores=\(panel.ignoresMouseEvents) frame=\(panel.frame)\n"
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

    func handleGlobalClick(at screenLocation: NSPoint) {
        guard stateModel.state.isPresented else { return }

        let now = Date()
        guard now.timeIntervalSince(lastHandledTapAt) > 0.25 else { return }
        lastHandledTapAt = now

        guard case .expanded = stateModel.state else {
            nfxTrace("global click compacto -> expandir")
            stateModel.expand()
            return
        }

        let islandWidth = settingsModel.settings.islandWidth
        let duration = currentMediaDuration()

        let origin = ScreenGeometry.windowOrigin(
            screenFrame: lastScreenFrame,
            topSafeAreaInset: lastTopInset,
            style: currentSurfaceStyle,
            width: ScreenGeometry.windowWidth,
            height: ScreenGeometry.windowHeight
        )

        switch ScreenGeometry.expandedZone(
            at: screenLocation,
            windowOrigin: origin,
            islandWidth: islandWidth,
            duration: duration,
            elapsed: 0
        ) {
        case .previous:
            nowPlaying.previousTrack()
        case .playPause:
            nowPlaying.togglePlayPause()
        case .next:
            nowPlaying.nextTrack()
        case .scrubber(let fraction):
            nowPlaying.seek(to: fraction * duration)
        case .background:
            stateModel.collapse()
        }
    }

    private func currentMediaDuration() -> Double {
        if case .nowPlaying(let detail) = stateModel.state.activity?.detail {
            return detail.duration
        }
        return 0
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

        lastScreenFrame = screen.frame
        lastTopInset = inset

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
    override var canBecomeMain: Bool { true }
    override var isKeyWindow: Bool { true }

    private var downLocation: NSPoint?

    override func constrainFrameRect(_ frameRect: NSRect, to screenRect: NSScreen?) -> NSRect {
        frameRect
    }

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
