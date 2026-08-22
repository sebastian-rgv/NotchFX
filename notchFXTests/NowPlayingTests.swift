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

struct AdapterPayloadParserTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func payload() -> [String: Any] {
        [
            "title": "Paris",
            "artist": "The Chainsmokers",
            "album": "Memories... Do Not Open",
            "duration": 221.504,
            "elapsedTime": 104.08,
            "timestamp": "1970-01-12T13:46:40Z",
            "playing": true,
            "bundleIdentifier": "com.spotify.client"
        ]
    }

    @Test func parsesFullAdapterPayload() throws {
        let snapshot = try AdapterPayloadParser.parse(payload(), now: now) ?? {
            throw TestError("payload no parseado")
        }()

        #expect(snapshot.title == "Paris")
        #expect(snapshot.artist == "The Chainsmokers")
        #expect(snapshot.duration == 221.504)
        #expect(snapshot.elapsed == 104.08)
        #expect(snapshot.isPlaying)
        #expect(snapshot.source == .spotify)
    }

    @Test func missingTitleIsRejected() {
        var broken = payload()
        broken["title"] = nil
        #expect(AdapterPayloadParser.parse(broken, now: now) == nil)

        broken["title"] = ""
        #expect(AdapterPayloadParser.parse(broken, now: now) == nil)
    }

    @Test func unknownBundleMapsToMediaRemote() {
        var custom = payload()
        custom["bundleIdentifier"] = "com.other.player"
        let snapshot = AdapterPayloadParser.parse(custom, now: now)
        #expect(snapshot?.source == .mediaRemote)
    }

    @Test func streamLineParsesWhenTypeIsData() {
        let line = #"{"type":"data","diff":false,"payload":{"title":"X","playing":false,"bundleIdentifier":"com.apple.Music","duration":100,"elapsedTime":3}}"#
        let data = Data(line.utf8)

        let snapshot = AdapterPayloadParser.parse(streamLine: data, now: now)
        #expect(snapshot?.title == "X")
        #expect(snapshot?.source == .appleMusic)
        #expect(!snapshot!.isPlaying)
    }

    @Test func nonDataLinesAreIgnored() {
        let line = Data(#"{"type":"heartbeat"}"#.utf8)
        #expect(AdapterPayloadParser.parse(streamLine: line, now: now) == nil)
    }
}

struct TestError: Error {
    let message: String
    init(_ message: String) { self.message = message }
}
