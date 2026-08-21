import CoreGraphics
import Testing
@testable import notchFXApp

struct GestureMathTests {
    @Test func offsetIsLinearBelowLimit() {
        #expect(GestureMath.dampedOffset(0) == 0)
        #expect(GestureMath.dampedOffset(50) == 50)
        #expect(GestureMath.dampedOffset(-80) == -80)
        #expect(GestureMath.dampedOffset(GestureMath.rubberBandLinearLimit) == GestureMath.rubberBandLinearLimit)
    }

    @Test func offsetGrowsSublinearlyAboveLimit() {
        let limit = GestureMath.rubberBandLinearLimit
        let damped = GestureMath.dampedOffset(limit + 100)

        #expect(damped > limit)
        #expect(damped < limit + 100)

        let first = GestureMath.dampedOffset(limit + 40) - limit
        let second = GestureMath.dampedOffset(limit + 160) - limit
        #expect(second > first)
        #expect(second < first * 4)
    }

    @Test func offsetPreservesSign() {
        let dampedDown = GestureMath.dampedOffset(GestureMath.rubberBandLinearLimit + 60)
        let dampedUp = GestureMath.dampedOffset(-(GestureMath.rubberBandLinearLimit + 60))
        #expect(dampedDown > 0)
        #expect(dampedUp < 0)
    }

    @Test func dismissByDistance() {
        let far = GestureMath.shouldDismiss(
            translation: CGSize(width: 0, height: 60),
            predictedEndTranslation: CGSize(width: 0, height: 70)
        )
        let short = GestureMath.shouldDismiss(
            translation: CGSize(width: 0, height: 20),
            predictedEndTranslation: CGSize(width: 0, height: 25)
        )
        #expect(far)
        #expect(!short)
    }

    @Test func dismissByFlickVelocity() {
        let flick = GestureMath.shouldDismiss(
            translation: CGSize(width: 2, height: 18),
            predictedEndTranslation: CGSize(width: 4, height: 220)
        )
        #expect(flick)
    }

    @Test func horizontalDragNeverDismisses() {
        let horizontal = GestureMath.shouldDismiss(
            translation: CGSize(width: 300, height: 3),
            predictedEndTranslation: CGSize(width: 500, height: 5)
        )
        #expect(!horizontal)
    }
}

struct ScreenGeometrySurfaceTests {
    private let screenFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)
    private let activity = NotchActivity(id: ActivityID(rawValue: "a"), kind: .timer)

    @Test func windowAnchorsTopCenter() {
        let anchor = ScreenGeometry.surfaceAnchorFrame(screenFrame: screenFrame)
        #expect(abs(anchor.midX - screenFrame.midX) < 0.001)
        #expect(abs(anchor.maxY - screenFrame.maxY) < 0.001)
        #expect(anchor.width == ScreenGeometry.windowWidth)
        #expect(anchor.height == ScreenGeometry.windowHeight)
    }

    @Test func opaqueRectMatchesState() {
        #expect(ScreenGeometry.opaqueRectInWindow(for: .hidden) == .zero)

        let compact = ScreenGeometry.opaqueRectInWindow(for: .compact(activity))
        #expect(compact.width == ScreenGeometry.compactWidth)
        #expect(compact.height == ScreenGeometry.compactHeight)
        #expect(compact.maxY == ScreenGeometry.windowHeight)

        let expanded = ScreenGeometry.opaqueRectInWindow(for: .expanded(activity))
        #expect(expanded.width == ScreenGeometry.expandedWidth)
        #expect(expanded.height == ScreenGeometry.expandedHeight)
        #expect(expanded.midX == compact.midX)
    }

    @Test func surfacesFitInsideWindow() {
        #expect(ScreenGeometry.compactWidth <= ScreenGeometry.windowWidth)
        #expect(ScreenGeometry.expandedWidth <= ScreenGeometry.windowWidth)
        #expect(ScreenGeometry.expandedHeight <= ScreenGeometry.windowHeight)
    }
}
