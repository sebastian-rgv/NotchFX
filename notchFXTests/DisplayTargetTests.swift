import CoreGraphics
import Foundation
import Testing
@testable import notchFXApp

struct DisplayTargetResolverTests {
    private let notched = ScreenCandidate(topSafeAreaInset: 32, isMain: false)
    private let plain = ScreenCandidate(topSafeAreaInset: 0, isMain: true)
    private let plainSecondary = ScreenCandidate(topSafeAreaInset: 6, isMain: false)

    @Test func floatingDetection() {
        #expect(DisplayTargetResolver.isFloating(topSafeAreaInset: 0))
        #expect(DisplayTargetResolver.isFloating(topSafeAreaInset: 6))
        #expect(!DisplayTargetResolver.isFloating(topSafeAreaInset: 32))
    }

    @Test func autoPrefersNotchedScreen() {
        let index = DisplayTargetResolver.pickIndex(
            mode: .auto,
            screens: [plain, notched]
        )
        #expect(index == 1)
    }

    @Test func autoFallsBackToMainWhenNoNotch() {
        let index = DisplayTargetResolver.pickIndex(
            mode: .auto,
            screens: [plainSecondary, plain]
        )
        #expect(index == 1)
    }

    @Test func forcedNotchedWithoutNotchHidesPanel() {
        let index = DisplayTargetResolver.pickIndex(
            mode: .notchedScreen,
            screens: [plain, plainSecondary]
        )
        #expect(index == nil)
    }

    @Test func forcedMainPicksMainScreen() {
        let index = DisplayTargetResolver.pickIndex(
            mode: .mainScreen,
            screens: [notched, plain]
        )
        #expect(index == 1)
    }

    @Test func notchStyleBecomesCapsuleOnFloatingScreen() {
        #expect(
            DisplayTargetResolver.effectiveStyle(preferred: .notch, topSafeAreaInset: 0) == .capsule
        )
        #expect(
            DisplayTargetResolver.effectiveStyle(preferred: .notch, topSafeAreaInset: 32) == .notch
        )
        #expect(
            DisplayTargetResolver.effectiveStyle(preferred: .capsule, topSafeAreaInset: 32) == .capsule
        )
    }
}

struct SurfaceStyleAnchorTests {
    private let screenFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)

    @Test func notchStyleSitsFlushWithTop() {
        let frame = ScreenGeometry.surfaceAnchorFrame(
            screenFrame: screenFrame,
            topSafeAreaInset: 32,
            style: .notch
        )
        #expect(abs(frame.maxY - screenFrame.maxY) < 0.001)
    }

    @Test func capsuleStyleFloatsBelowMenuBar() {
        let inset: CGFloat = 25
        let gap = DisplayTargetResolver.floatingGap

        let frame = ScreenGeometry.surfaceAnchorFrame(
            screenFrame: screenFrame,
            topSafeAreaInset: inset,
            style: .capsule
        )

        #expect(frame.maxY < screenFrame.maxY)
        #expect(abs(frame.maxY - (screenFrame.maxY - inset - gap)) < 0.001)
    }

    @Test func bothStylesStayCentered() {
        for style in [NotchSettings.SurfaceStyle.notch, .capsule] {
            let frame = ScreenGeometry.surfaceAnchorFrame(
                screenFrame: screenFrame,
                topSafeAreaInset: 30,
                style: style
            )
            #expect(abs(frame.midX - screenFrame.midX) < 0.001)
        }
    }
}
