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
