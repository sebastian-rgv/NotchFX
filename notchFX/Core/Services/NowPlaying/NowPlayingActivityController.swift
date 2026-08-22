import Foundation

@MainActor
final class NowPlayingActivityController: ObservableObject {
    static let activityID = ActivityID(rawValue: "nowplaying.session")

    private let engine: ActivityEngine
    private lazy var provider = ScriptedMediaProvider(handler: { [weak self] snapshot in
        MainActor.assumeIsolated {
            self?.handle(snapshot)
        }
    })

    @Published private(set) var display: NowPlayingDisplay?
    var isVisibleToUser: Bool { display != nil }

    init(engine: ActivityEngine) {
        self.engine = engine
    }

    func start() {
        provider.start()
    }

    func stop() {
        provider.stop()
        engine.finish(Self.activityID)
        display = nil
    }

    func togglePlayPause() {
        provider.send(.togglePlayPause)
    }

    func nextTrack() {
        provider.send(.nextTrack)
    }

    func previousTrack() {
        provider.send(.previousTrack)
    }

    func seek(to seconds: Double) {
        provider.seek(to: seconds)
    }

    func openSourceApp() {
        provider.openSourceApp()
    }

    private func handle(_ snapshot: NowPlayingSnapshot?) {
        guard let snapshot, NowPlayingLogic.shouldShow(snapshot: snapshot, now: Date()) else {
            hideIfVisible()
            return
        }

        let detail = NowPlayingDisplay(
            title: snapshot.title.isEmpty ? "Unknown track" : snapshot.title,
            artist: snapshot.artist.isEmpty ? "Unknown artist" : snapshot.artist,
            duration: snapshot.duration,
            elapsedAtTimestamp: snapshot.elapsed,
            rate: snapshot.rate,
            timestamp: snapshot.timestamp,
            isPlaying: snapshot.isPlaying
        )

        engine.present(
            makeActivity(detail),
            priority: .ambient
        )

        display = detail
    }

    private func hideIfVisible() {
        guard isVisibleToUser else { return }
        engine.finish(Self.activityID)
        display = nil
    }

    private func makeActivity(_ detail: NowPlayingDisplay) -> NotchActivity {
        NotchActivity(
            id: Self.activityID,
            kind: .nowPlaying,
            detail: .nowPlaying(detail)
        )
    }
}
