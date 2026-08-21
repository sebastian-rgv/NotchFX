import CoreGraphics
import Testing
@testable import notchFXApp

struct ScreenGeometryTests {
    private let screenFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)

    @Test func notchedDisplayDetection() {
        #expect(ScreenGeometry.isNotchedDisplay(topSafeAreaInset: 32))
        #expect(ScreenGeometry.isNotchedDisplay(topSafeAreaInset: 20))
        #expect(!ScreenGeometry.isNotchedDisplay(topSafeAreaInset: 0))
        #expect(!ScreenGeometry.isNotchedDisplay(topSafeAreaInset: 6))
        #expect(!ScreenGeometry.isNotchedDisplay(topSafeAreaInset: 19.9))
    }

    @Test func anchorIsCenteredHorizontally() {
        let anchor = ScreenGeometry.notchAnchorFrame(screenFrame: screenFrame)
        #expect(abs(anchor.midX - screenFrame.midX) < 0.001)
    }

    @Test func anchorIsFlushWithTopEdge() {
        let anchor = ScreenGeometry.notchAnchorFrame(screenFrame: screenFrame)
        #expect(abs(anchor.maxY - screenFrame.maxY) < 0.001)
        #expect(anchor.height == ScreenGeometry.defaultAnchorHeight)
        #expect(anchor.width == ScreenGeometry.defaultAnchorWidth)
    }

    @Test func anchorSupportsCustomSize() {
        let anchor = ScreenGeometry.notchAnchorFrame(
            screenFrame: screenFrame,
            width: 300,
            height: 60
        )
        #expect(anchor.width == 300)
        #expect(anchor.height == 60)
        #expect(abs(anchor.origin.x - (1512.0 - 300.0) / 2) < 0.001)
        #expect(abs(anchor.origin.y - (982.0 - 60.0)) < 0.001)
    }
}
