import AppKit
import Foundation

@MainActor
final class NowPlayingActivityController: ObservableObject {
    static let activityID = ActivityID(rawValue: "nowplaying.session")

    private enum ProviderKind {
        case adapter
        case scripted
    }

    private let engine: ActivityEngine

    @Published private(set) var display: NowPlayingDisplay?
    @Published private(set) var artwork: NSImage?

    private var pausedSince: Date?
    private var lastArtworkTrackKey: String?
    private var activeProvider: ProviderKind = .scripted

    private lazy var adapterProvider = MediaRemoteAdapterProvider { [weak self] snapshot in
        MainActor.assumeIsolated {
            self?.handle(snapshot)
        }
    }

    private lazy var scriptedProvider = ScriptedMediaProvider { [weak self] snapshot in
        MainActor.assumeIsolated {
            self?.handle(snapshot)
        }
    }

    var isVisibleToUser: Bool { display != nil }

    init(engine: ActivityEngine) {
        self.engine = engine
    }

    func start() {
        if adapterProvider.isAvailable() {
            activeProvider = .adapter
            adapterProvider.start { [weak self] snapshot in
                MainActor.assumeIsolated {
                    self?.handle(snapshot)
                }
            }
        } else {
            activeProvider = .scripted
            scriptedProvider.start()
        }
    }

    func stop() {
        switch activeProvider {
        case .adapter:
            adapterProvider.stop()
        case .scripted:
            scriptedProvider.stop()
        }
        engine.finish(Self.activityID)
        display = nil
    }

    func togglePlayPause() {
        switch activeProvider {
        case .adapter:
            adapterProvider.send(commandID: "2")
        case .scripted:
            scriptedProvider.send(.togglePlayPause)
        }
    }

    func nextTrack() {
        switch activeProvider {
        case .adapter:
            adapterProvider.send(commandID: "4")
        case .scripted:
            scriptedProvider.send(.nextTrack)
        }
    }

    func previousTrack() {
        switch activeProvider {
        case .adapter:
            adapterProvider.send(commandID: "5")
        case .scripted:
            scriptedProvider.send(.previousTrack)
        }
    }

    func seek(to seconds: Double) {
        switch activeProvider {
        case .adapter:
            adapterProvider.seek(to: seconds)
        case .scripted:
            scriptedProvider.seek(to: seconds)
        }
    }

    func openSourceApp() {
        let bundleID: String?

        switch display?.source {
        case .spotify:
            bundleID = "com.spotify.client"
        case .appleMusic:
            bundleID = "com.apple.Music"
        default:
            bundleID = nil
        }

        guard let bundleID,
              let app = NSRunningApplication.runningApplications(
                  withBundleIdentifier: bundleID
              ).first
        else { return }

        app.activate()
    }

    private func handle(_ snapshot: NowPlayingSnapshot?) {
        guard let snapshot else {
            hideIfVisible()
            return
        }

        if snapshot.isPlaying {
            pausedSince = nil
        } else if pausedSince == nil {
            pausedSince = Date()
        }

        let pauseGraceExpired = !snapshot.isPlaying && pausedSince.map {
            Date().timeIntervalSince($0) > 6
        } ?? false

        guard !pauseGraceExpired else {
            hideIfVisible()
            return
        }

        refreshArtworkIfNeeded(for: snapshot)

        let detail = NowPlayingDisplay(
            title: snapshot.title.isEmpty ? "Unknown track" : snapshot.title,
            artist: snapshot.artist.isEmpty ? "Unknown artist" : snapshot.artist,
            duration: snapshot.duration,
            elapsedAtTimestamp: snapshot.elapsed,
            rate: snapshot.rate,
            timestamp: snapshot.timestamp,
            isPlaying: snapshot.isPlaying,
            source: snapshot.source
        )

        engine.present(
            makeActivity(detail),
            priority: .ambient
        )

        display = detail
    }

    private func refreshArtworkIfNeeded(for snapshot: NowPlayingSnapshot) {
        let trackKey = "\(snapshot.title)|\(snapshot.artist)"

        guard activeProvider == .adapter, trackKey != lastArtworkTrackKey else { return }
        lastArtworkTrackKey = trackKey

        adapterProvider.fetchArtwork { [weak self] image in
            self?.artwork = image
        }
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
