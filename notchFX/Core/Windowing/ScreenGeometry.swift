import CoreGraphics
import Foundation

enum ScreenGeometry {
    static let notchedDisplayMinimumTopSafeAreaInset: CGFloat = 20

    static let windowWidth: CGFloat = 400
    static let windowHeight: CGFloat = 180

    static let defaultCompactWidth: CGFloat = 360
    static let defaultCompactHeight: CGFloat = 46
    static var compactWidth: CGFloat { defaultCompactWidth }
    static var compactHeight: CGFloat { defaultCompactHeight }

    static let expandedWidth: CGFloat = 380
    static let expandedHeight: CGFloat = 152

    static let notchClearance: CGFloat = 34
    static let shoulderInset: CGFloat = 28

    static func isNotchedDisplay(topSafeAreaInset: CGFloat) -> Bool {
        topSafeAreaInset >= notchedDisplayMinimumTopSafeAreaInset
    }

    static func surfaceAnchorFrame(
        screenFrame: CGRect,
        width: CGFloat = ScreenGeometry.windowWidth,
        height: CGFloat = ScreenGeometry.windowHeight
    ) -> CGRect {
        let originX = screenFrame.midX - width / 2
        let originY = screenFrame.maxY - height
        return CGRect(x: originX, y: originY, width: width, height: height)
    }

    static func opaqueRectInWindow(
        for state: NotchState,
        islandWidth: CGFloat = defaultCompactWidth,
        islandHeight: CGFloat = defaultCompactHeight
    ) -> CGRect {
        switch state {
        case .hidden:
            return .zero
        case .compact:
            return topAnchoredRect(width: islandWidth, height: islandHeight)
        case .expanded:
            return topAnchoredRect(width: expandedWidth, height: expandedHeight)
        }
    }

    private static func topAnchoredRect(width: CGFloat, height: CGFloat) -> CGRect {
        CGRect(
            x: (windowWidth - width) / 2,
            y: windowHeight - height,
            width: width,
            height: height
        )
    }
}


extension ScreenGeometry {
    enum ExpandedZone {
        case previous
        case playPause
        case next
        case scrubber(fraction: Double)
        case background
    }

    static func windowOrigin(
        screenFrame: CGRect,
        topSafeAreaInset: CGFloat,
        style: NotchSettings.SurfaceStyle,
        width: CGFloat = ScreenGeometry.windowWidth,
        height: CGFloat = ScreenGeometry.windowHeight
    ) -> CGPoint {
        let yOffset: CGFloat = style == .capsule
            ? topSafeAreaInset + DisplayTargetResolver.floatingGap
            : -1
        return CGPoint(
            x: screenFrame.midX - width / 2,
            y: screenFrame.maxY - height - yOffset
        )
    }

    static func expandedZone(
        at globalPoint: CGPoint,
        windowOrigin: CGPoint,
        islandWidth: CGFloat,
        duration: Double,
        elapsed: Double
    ) -> ExpandedZone {
        let localX = globalPoint.x - (windowOrigin.x + (windowWidth - islandWidth) / 2)
        let localYFromTop = (windowOrigin.y + windowHeight) - globalPoint.y

        guard localYFromTop > notchClearance else { return .background }

        let controlsTop = notchClearance + 62
        let controlsBottom = controlsTop + 40

        if localYFromTop >= controlsTop, localYFromTop <= controlsBottom {
            let third = islandWidth / 3
            if localX < third { return .previous }
            if localX > islandWidth - third { return .next }
            return .playPause
        }

        if localYFromTop >= notchClearance + 30, localYFromTop <= notchClearance + 52 {
            let fraction = min(max(0, localX / islandWidth), 1)
            return .scrubber(fraction: fraction * duration + elapsed - elapsed)
        }

        return .background
    }
}
