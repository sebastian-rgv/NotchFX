import SwiftUI

struct NotchRootView: View {
    @ObservedObject var stateModel: NotchStateModel
    let engine: ActivityEngine
    @ObservedObject var settingsModel: SettingsModel
    let surfaceStyle: NotchSettings.SurfaceStyle

    var body: some View {
        ZStack(alignment: .top) {
            if let activity = stateModel.state.activity {
                surface(for: activity)
                    .transition(.asymmetric(
                        insertion: .offset(y: -ScreenGeometry.compactHeight),
                        removal: .opacity
                    ))
            }
        }
        .frame(
            width: ScreenGeometry.windowWidth,
            height: ScreenGeometry.windowHeight,
            alignment: .top
        )
        .animation(.notchMorph, value: stateModel.state)
        .animation(.notchShowHide, value: stateModel.state.isPresented)
    }

    @ViewBuilder
    private func surface(for activity: NotchActivity) -> some View {
        let isExpanded = isExpandedState

        NotchSurface(
            width: isExpanded ? ScreenGeometry.expandedWidth : ScreenGeometry.compactWidth,
            height: isExpanded ? ScreenGeometry.expandedHeight : ScreenGeometry.compactHeight,
            style: surfaceStyle,
            content: AnyView(
                content(for: activity, expanded: isExpanded)
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            )
        )
        .notchGestures(
            onTap: { stateModel.toggleExpanded() },
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
