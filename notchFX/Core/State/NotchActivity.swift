import Foundation

struct NowPlayingDisplay: Equatable {
    let title: String
    let artist: String
    let duration: Double
    let elapsedAtTimestamp: Double
    let rate: Double
    let timestamp: Date
    let isPlaying: Bool
}

enum ActivityDetail: Equatable {
    case timer(endDate: Date)
    case timerFinished(label: String)
    case battery(percent: Int, isCharging: Bool)
    case nowPlaying(NowPlayingDisplay)
    case info(symbol: String, label: String)
}

struct NotchActivity: Equatable, Identifiable {
    let id: ActivityID
    let kind: ActivityKind
    let detail: ActivityDetail

    init(
        id: ActivityID,
        kind: ActivityKind,
        detail: ActivityDetail = .info(symbol: "", label: "")
    ) {
        self.id = id
        self.kind = kind
        self.detail = detail
    }
}
