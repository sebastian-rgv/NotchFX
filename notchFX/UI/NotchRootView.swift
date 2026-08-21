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
                HStack(spacing: 6) {
                    Image(systemName: activity.kind.symbolName)
                        .font(.system(size: 11, weight: .regular))
                    Text(activity.kind.displayName)
                        .font(.system(size: 11, weight: .regular))
                        .monospacedDigit()
                }
                .foregroundStyle(.white.opacity(0.9))
            }
            .frame(height: ScreenGeometry.defaultAnchorHeight)
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
}
