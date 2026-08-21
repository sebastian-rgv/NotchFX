import CoreGraphics
import Foundation

enum ScreenGeometry {
    static let notchedDisplayMinimumTopSafeAreaInset: CGFloat = 20

    static let windowWidth: CGFloat = 400
    static let windowHeight: CGFloat = 180

    static let compactWidth: CGFloat = 220
    static let compactHeight: CGFloat = 36

    static let expandedWidth: CGFloat = 340
    static let expandedHeight: CGFloat = 132

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
        for state: NotchState
    ) -> CGRect {
        switch state {
        case .hidden:
            return .zero
        case .compact:
            return topAnchoredRect(width: compactWidth, height: compactHeight)
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
