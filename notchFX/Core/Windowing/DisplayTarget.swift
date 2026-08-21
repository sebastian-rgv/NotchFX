import CoreGraphics
import Foundation

struct ScreenCandidate: Equatable {
    let topSafeAreaInset: CGFloat
    let isMain: Bool
}

enum DisplayTargetResolver {
    static let floatingGap: CGFloat = 8

    static func isFloating(topSafeAreaInset: CGFloat) -> Bool {
        !ScreenGeometry.isNotchedDisplay(topSafeAreaInset: topSafeAreaInset)
    }

    static func effectiveStyle(
        preferred: NotchSettings.SurfaceStyle,
        topSafeAreaInset: CGFloat
    ) -> NotchSettings.SurfaceStyle {
        if preferred == .notch && isFloating(topSafeAreaInset: topSafeAreaInset) {
            return .capsule
        }
        return preferred
    }

    static func pickIndex(
        mode: NotchSettings.DisplayMode,
        screens: [ScreenCandidate]
    ) -> Int? {
        switch mode {
        case .mainScreen:
            return screens.firstIndex(where: \.isMain)
        case .notchedScreen:
            return screens.firstIndex {
                ScreenGeometry.isNotchedDisplay(topSafeAreaInset: $0.topSafeAreaInset)
            }
        case .auto:
            if let notched = screens.firstIndex(where: {
                ScreenGeometry.isNotchedDisplay(topSafeAreaInset: $0.topSafeAreaInset)
            }) {
                return notched
            }
            return screens.firstIndex(where: \.isMain)
        }
    }
}

extension ScreenGeometry {
    static func surfaceAnchorFrame(
        screenFrame: CGRect,
        topSafeAreaInset: CGFloat,
        style: NotchSettings.SurfaceStyle,
        width: CGFloat = ScreenGeometry.windowWidth,
        height: CGFloat = ScreenGeometry.windowHeight
    ) -> CGRect {
        let yOffset: CGFloat = style == .capsule
            ? topSafeAreaInset + DisplayTargetResolver.floatingGap
            : 0

        return CGRect(
            x: screenFrame.midX - width / 2,
            y: screenFrame.maxY - height - yOffset,
            width: width,
            height: height
        )
    }
}
