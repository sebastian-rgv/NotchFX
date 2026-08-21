import CoreGraphics
import Foundation

enum ScreenGeometry {
    static let notchedDisplayMinimumTopSafeAreaInset: CGFloat = 20
    static let defaultAnchorWidth: CGFloat = 220
    static let defaultAnchorHeight: CGFloat = 36

    static func isNotchedDisplay(topSafeAreaInset: CGFloat) -> Bool {
        topSafeAreaInset >= notchedDisplayMinimumTopSafeAreaInset
    }

    static func notchAnchorFrame(
        screenFrame: CGRect,
        width: CGFloat = ScreenGeometry.defaultAnchorWidth,
        height: CGFloat = ScreenGeometry.defaultAnchorHeight
    ) -> CGRect {
        let originX = screenFrame.midX - width / 2
        let originY = screenFrame.maxY - height
        return CGRect(x: originX, y: originY, width: width, height: height)
    }
}
