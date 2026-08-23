import SwiftUI

struct NotchRootView: View {
    @ObservedObject var stateModel: NotchStateModel
    let engine: ActivityEngine
    @ObservedObject var settingsModel: SettingsModel
    let surfaceStyle: NotchSettings.SurfaceStyle
    @ObservedObject var nowPlaying: NowPlayingActivityController

    var body: some View {
        ZStack(alignment: .top) {
            if let activity = stateModel.state.activity {
                surface(for: activity)
                    .transition(.opacity)
            }
        }
        .frame(
            width: ScreenGeometry.windowWidth,
            height: ScreenGeometry.windowHeight,
            alignment: .top
        )
        .background(Color.clear)
        .ignoresSafeArea()
        .animation(.notchMorph, value: stateModel.state)
        .animation(.notchShowHide, value: stateModel.state.isPresented)
        .onReceive(NotificationCenter.default.publisher(for: .notchTapReceived)) { _ in
            guard case .compact = stateModel.state else { return }
            nfxTrace("TAP NATIVO -> expand")
            stateModel.expand()
        }
    }

    @ViewBuilder
    private func surface(for activity: NotchActivity) -> some View {
        let isExpanded = isExpandedState
        let debugWidth = isExpanded ? ScreenGeometry.expandedWidth : settingsModel.settings.islandWidth
        let debugHeight = isExpanded ? ScreenGeometry.expandedHeight : settingsModel.settings.islandHeight

        if ProcessInfo.processInfo.environment["NFX_DEBUG"] == "1" {
            let _ = Self.appendRenderLog(width: debugWidth, height: debugHeight)
        }

        NotchSurface(
            width: debugWidth,
            height: debugHeight,
            style: surfaceStyle,
            content: AnyView(
                content(for: activity, expanded: isExpanded)
                    .transition(.opacity)
            )
        )
        .notchGestures(
            onTap: {
                nfxTrace("TAP recibido (estado antes: \(stateModel.state))")
                stateModel.toggleExpanded()
                nfxTrace("estado después: \(stateModel.state)")
            },
            onDismiss: settingsModel.settings.swipeDismissEnabled
                ? { engine.dismissTop() }
                : {}
        )
    }

    private var isExpandedState: Bool {
        if case .expanded = stateModel.state {
            return true
        }
        return false
    }

    @ViewBuilder
    private func content(for activity: NotchActivity, expanded: Bool) -> some View {
        switch activity.detail {
        case .nowPlaying(let display):
            if expanded {
                NowPlayingExpandedContent(
                    display: display,
                    artwork: nowPlaying.artwork,
                    onTogglePlayPause: { nowPlaying.togglePlayPause() },
                    onNext: { nowPlaying.nextTrack() },
                    onPrevious: { nowPlaying.previousTrack() },
                    onSeek: { seconds in nowPlaying.seek(to: seconds) },
                    onOpenSourceApp: { nowPlaying.openSourceApp() }
                )
            } else {
                NowPlayingCompactContent(display: display, artwork: nowPlaying.artwork)
            }

        case .timer(let endDate):
            if expanded {
                TimerExpandedContent(endDate: endDate) {
                    engine.finish(LocalTimerController.activityID)
                }
            } else {
                TimerCompactContent(endDate: endDate)
            }

        case .battery(let percent, let isCharging):
            if expanded {
                BatteryExpandedContent(percent: percent, isCharging: isCharging)
            } else {
                BatteryCompactContent(percent: percent, isCharging: isCharging)
            }

        case .timerFinished(let label):
            FinishedCompactContent(label: label)

        case .info(let symbol, let label):
            InfoCompactContent(symbol: symbol, label: label, fallback: activity.kind.displayName)
        }
    }

    static func formatCountdown(from date: Date, to endDate: Date) -> String {
        let remaining = max(0, Int(endDate.timeIntervalSince(date).rounded(.up)))
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

extension NotchRootView {
    static func appendRenderLog(width: CGFloat, height: CGFloat) {
        let line = "\(Date()) render w=\(Int(width)) h=\(Int(height))\n"
        if let handle = FileHandle(forWritingAtPath: "/tmp/nfx_render.log") {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8)!)
            handle.closeFile()
        } else {
            try? line.write(toFile: "/tmp/nfx_render.log", atomically: true, encoding: .utf8)
        }
    }
}


extension NotchRootView {
    static func appendEventLog(_ message: String) {
        guard ProcessInfo.processInfo.environment["NFX_DEBUG"] == "1" else { return }
        let line = "\(Date()) \(message)\n"
        if let handle = FileHandle(forWritingAtPath: "/tmp/nfx_events.log") {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8)!)
            handle.closeFile()
        } else {
            try? line.write(toFile: "/tmp/nfx_events.log", atomically: true, encoding: .utf8)
        }
    }
}
