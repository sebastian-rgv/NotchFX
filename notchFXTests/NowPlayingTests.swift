import Foundation
import Testing
@testable import notchFXApp

struct NowPlayingLogicTests {
    private func snapshot(
        duration: Double,
        elapsed: Double,
        rate: Double,
        timestamp: Date,
        isPlaying: Bool
    ) -> NowPlayingSnapshot {
        NowPlayingSnapshot(
            title: "Test",
            artist: "Artist",
            album: nil,
            duration: duration,
            elapsed: elapsed,
            rate: rate,
            timestamp: timestamp,
            isPlaying: isPlaying,
            source: .spotify
        )
    }

    private let base = Date(timeIntervalSince1970: 1000)

    @Test func elapsedInterpolatesWhilePlaying() {
        let snap = snapshot(duration: 200, elapsed: 30, rate: 1, timestamp: base, isPlaying: true)
        let later = base.addingTimeInterval(10)

        #expect(NowPlayingLogic.currentElapsed(snapshot: snap, at: later) == 40)
    }

    @Test func elapsedFrozenWhilePaused() {
        let snap = snapshot(duration: 200, elapsed: 30, rate: 1, timestamp: base, isPlaying: false)
        let later = base.addingTimeInterval(60)

        #expect(NowPlayingLogic.currentElapsed(snapshot: snap, at: later) == 30)
    }

    @Test func elapsedClampsToDuration() {
        let snap = snapshot(duration: 100, elapsed: 95, rate: 2, timestamp: base, isPlaying: true)
        let later = base.addingTimeInterval(30)

        #expect(NowPlayingLogic.currentElapsed(snapshot: snap, at: later) == 100)
    }

    @Test func progressIsRatio() {
        let snap = snapshot(duration: 200, elapsed: 50, rate: 0, timestamp: base, isPlaying: false)
        #expect(NowPlayingLogic.progress(snapshot: snap, at: base) == 0.25)
    }

    @Test func progressZeroWithoutDuration() {
        let snap = snapshot(duration: 0, elapsed: 10, rate: 1, timestamp: base, isPlaying: true)
        #expect(NowPlayingLogic.progress(snapshot: snap, at: base) == 0)
    }

    @Test func showRulesWithPauseGrace() {
        let playing = snapshot(duration: 100, elapsed: 0, rate: 1, timestamp: base, isPlaying: true)
        let pausedNow = snapshot(duration: 100, elapsed: 0, rate: 0, timestamp: base, isPlaying: false)
        let pausedLongAgo = snapshot(
            duration: 100,
            elapsed: 0,
            rate: 0,
            timestamp: base.addingTimeInterval(-120),
            isPlaying: false
        )

        #expect(NowPlayingLogic.shouldShow(snapshot: playing, now: base))
        #expect(NowPlayingLogic.shouldShow(snapshot: pausedNow, now: base))
        #expect(!NowPlayingLogic.shouldShow(snapshot: pausedLongAgo, now: base))
        #expect(!NowPlayingLogic.shouldShow(snapshot: nil, now: base))
    }

    @Test func clockFormatting() {
        #expect(NowPlayingLogic.formatClock(0) == "00:00")
        #expect(NowPlayingLogic.formatClock(65) == "01:05")
        #expect(NowPlayingLogic.formatClock(3600 + 125) == "1:02:05")
        #expect(NowPlayingLogic.formatClock(-5) == "--:--")
        #expect(NowPlayingLogic.formatClock(.infinity) == "--:--")
    }
}

struct ScriptedMediaParsingTests {
    @Test func parsesFullResponse() {
        let now = Date()
        let output = "Bohemian Rhapsody|Queen|354000|42|playing"

        let parsed = ScriptedMediaProvider.parseResponse(output, source: .spotify, now: now)

        #expect(parsed?.title == "Bohemian Rhapsody")
        #expect(parsed?.artist == "Queen")
        #expect(parsed?.duration == 354)
        #expect(parsed?.elapsed == 42)
        #expect(parsed?.isPlaying == true)
        #expect(parsed?.rate == 1)
    }

    @Test func spotifyDurationConvertsFromMilliseconds() {
        let parsed = ScriptedMediaProvider.parseResponse(
            "Song|Artist|215693|57|playing",
            source: .spotify,
            now: Date()
        )
        #expect(parsed?.duration == 215.693)

        let musicParsed = ScriptedMediaProvider.parseResponse(
            "Song|Artist|215|57|playing",
            source: .appleMusic,
            now: Date()
        )
        #expect(musicParsed?.duration == 215)
    }

    @Test func parsesPausedState() {
        let parsed = ScriptedMediaProvider.parseResponse(
            "Song|Artist|180|10|paused",
            source: .appleMusic,
            now: Date()
        )
        #expect(parsed?.isPlaying == false)
        #expect(parsed?.rate == 0)
    }

    @Test func rejectsEmptyAndMalformed() {
        #expect(ScriptedMediaProvider.parseResponse("", source: .spotify, now: Date()) == nil)
        #expect(ScriptedMediaProvider.parseResponse("missing", source: .spotify, now: Date()) == nil)
        #expect(
            ScriptedMediaProvider.parseResponse("|||x|playing", source: .spotify, now: Date()) == nil
        )
    }
}
