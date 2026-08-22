import Foundation

struct NowPlayingSnapshot: Equatable {
    let title: String
    let artist: String
    let album: String?
    let duration: Double
    let elapsed: Double
    let rate: Double
    let timestamp: Date
    let isPlaying: Bool
    let source: NowPlayingSource
}

enum NowPlayingSource: String, Equatable {
    case mediaRemote
    case appleMusic
    case spotify
}

enum NowPlayingCommand: String {
    case togglePlayPause
    case play
    case pause
    case nextTrack
    case previousTrack
}

enum NowPlayingLogic {
    static func currentElapsed(
        snapshot: NowPlayingSnapshot,
        at date: Date
    ) -> Double {
        guard snapshot.isPlaying else {
            return clamp(snapshot.elapsed, max: snapshot.duration)
        }

        let drift = date.timeIntervalSince(snapshot.timestamp) * snapshot.rate
        return clamp(snapshot.elapsed + drift, max: snapshot.duration)
    }

    static func shouldShow(
        snapshot: NowPlayingSnapshot?,
        now: Date,
        pausedGrace: TimeInterval = 6
    ) -> Bool {
        guard let snapshot else { return false }
        if snapshot.isPlaying { return true }
        return now.timeIntervalSince(snapshot.timestamp) < pausedGrace
    }

    static func progress(snapshot: NowPlayingSnapshot, at date: Date) -> Double {
        guard snapshot.duration > 0 else { return 0 }
        return currentElapsed(snapshot: snapshot, at: date) / snapshot.duration
    }

    static func formatClock(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "--:--" }

        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    private static func clamp(_ value: Double, max maxValue: Double) -> Double {
        guard maxValue > 0 else { return Swift.max(0, value) }
        return Swift.min(Swift.max(0, value), maxValue)
    }
}
