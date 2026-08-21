import SwiftUI

struct NotchRootView: View {
    @ObservedObject var stateModel: NotchStateModel

    var body: some View {
        GeometryReader { proxy in
            content(size: proxy.size)
        }
    }

    @ViewBuilder
    private func content(size: CGSize) -> some View {
        switch stateModel.state {
        case .hidden:
            Color.clear
        case .compact(let activity):
            compactBadge(activity)
                .frame(width: size.width, height: size.height, alignment: .top)
        case .expanded(let activity):
            expandedPanel(activity)
                .frame(width: size.width, height: size.height, alignment: .top)
        }
    }

    private func compactBadge(_ activity: NotchActivity) -> some View {
        NotchShape(cornerRadius: ScreenGeometry.defaultAnchorHeight / 2.6)
            .fill(.black)
            .overlay(alignment: .center) {
                compactContent(activity)
            }
            .frame(height: ScreenGeometry.defaultAnchorHeight)
    }

    @ViewBuilder
    private func compactContent(_ activity: NotchActivity) -> some View {
        switch activity.detail {
        case .timer(let endDate):
            HStack(spacing: 6) {
                Image(systemName: "timer")
                    .font(.system(size: 11, weight: .regular))
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(Self.formatCountdown(from: context.date, to: endDate))
                        .font(.system(size: 11, weight: .regular))
                        .monospacedDigit()
                }
            }
            .foregroundStyle(.white.opacity(0.9))

        case .battery(let percent, let isCharging):
            HStack(spacing: 5) {
                Image(systemName: isCharging ? "battery.bolt" : "battery.75percent")
                    .font(.system(size: 12, weight: .regular))
                Text("\(percent)%")
                    .font(.system(size: 11, weight: .regular))
                    .monospacedDigit()
            }
            .foregroundStyle(.white.opacity(0.9))

        case .timerFinished(let label):
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 11, weight: .regular))
                Text(label)
                    .font(.system(size: 11, weight: .regular))
            }
            .foregroundStyle(.white.opacity(0.9))

        case .info(let symbol, let label):
            HStack(spacing: 6) {
                if !symbol.isEmpty {
                    Image(systemName: symbol)
                        .font(.system(size: 11, weight: .regular))
                }
                Text(label.isEmpty ? activity.kind.displayName : label)
                    .font(.system(size: 11, weight: .regular))
                    .monospacedDigit()
            }
            .foregroundStyle(.white.opacity(0.9))
        }
    }

    private func expandedPanel(_ activity: NotchActivity) -> some View {
        NotchShape(cornerRadius: 16)
            .fill(.black)
            .overlay(alignment: .center) {
                VStack(spacing: 4) {
                    Image(systemName: activity.kind.symbolName)
                        .font(.system(size: 14, weight: .regular))
                    Text(activity.kind.displayName)
                        .font(.system(size: 12, weight: .regular))
                        .monospacedDigit()
                }
                .foregroundStyle(.white.opacity(0.9))
            }
            .frame(height: ScreenGeometry.defaultAnchorHeight * 2)
    }

    static func formatCountdown(from date: Date, to endDate: Date) -> String {
        let remaining = max(0, Int(endDate.timeIntervalSince(date).rounded(.up)))
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
