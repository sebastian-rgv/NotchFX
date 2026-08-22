import Foundation

enum ActivityKind: String, Codable, CaseIterable {
    case nowPlaying
    case timer
    case battery
    case hud
    case download
    case camera

    var displayName: String {
        switch self {
        case .nowPlaying:
            return "Now Playing"
        case .timer:
            return "Timer"
        case .battery:
            return "Battery"
        case .hud:
            return "HUD"
        case .download:
            return "Download"
        case .camera:
            return "Camera"
        }
    }

    var symbolName: String {
        switch self {
        case .nowPlaying:
            return "music.note"
        case .timer:
            return "timer"
        case .battery:
            return "battery.bolt"
        case .hud:
            return "speaker.wave.2.fill"
        case .download:
            return "arrow.down.circle"
        case .camera:
            return "video.fill"
        }
    }
}
