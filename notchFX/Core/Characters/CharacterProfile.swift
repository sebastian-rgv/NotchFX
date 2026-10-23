import Foundation

enum GhostStyle: String, Codable, CaseIterable, Identifiable {
    case blinky
    case pinky
    case inky
    case clyde

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blinky: return "Blinky"
        case .pinky: return "Pinky"
        case .inky: return "Inky"
        case .clyde: return "Clyde"
        }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = GhostStyle(rawValue: raw) ?? .blinky
    }
}

struct CharacterProfile: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var style: GhostStyle
    var command: String
    var workingDirectory: String?

    init(
        id: UUID = UUID(),
        name: String,
        style: GhostStyle = .blinky,
        command: String,
        workingDirectory: String? = nil
    ) {
        self.id = id
        self.name = name
        self.style = style
        self.command = command
        self.workingDirectory = workingDirectory
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, style, command, workingDirectory
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? ""
        style = (try? container.decodeIfPresent(GhostStyle.self, forKey: .style)) ?? .blinky
        command = (try? container.decodeIfPresent(String.self, forKey: .command)) ?? ""
        workingDirectory = try? container.decodeIfPresent(String.self, forKey: .workingDirectory)
    }
}

enum CharacterRunState: Equatable {
    case idle
    case running(startedAt: Date)
    case succeeded
    case failed(exitCode: Int32)
    case stopped

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }

    var isFinished: Bool {
        switch self {
        case .succeeded, .failed, .stopped: return true
        case .idle, .running: return false
        }
    }
}

struct CharacterSnapshot: Identifiable, Equatable {
    let id: UUID
    let name: String
    let style: GhostStyle
    let state: CharacterRunState
}

struct CharactersDisplay: Equatable {
    let snapshots: [CharacterSnapshot]
    let selectedID: UUID?
    let selectedName: String?
    let selectedLines: [String]

    static let empty = CharactersDisplay(
        snapshots: [],
        selectedID: nil,
        selectedName: nil,
        selectedLines: []
    )

    var runningCount: Int {
        snapshots.filter { $0.state.isRunning }.count
    }

    var hasRunning: Bool { runningCount > 0 }
}
