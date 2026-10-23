import Foundation

struct NotchSettings: Codable, Equatable {
    enum DisplayMode: String, Codable, CaseIterable {
        case auto
        case notchedScreen
        case mainScreen
    }

    enum SurfaceStyle: String, Codable, CaseIterable {
        case notch
        case capsule
    }

    var displayMode: DisplayMode = .auto
    var surfaceStyle: SurfaceStyle = .notch
    var swipeDismissEnabled: Bool = true
    var alertDuration: Double = 5
    var islandWidth: Double = 360
    var islandHeight: Double = 46
    var characters: [CharacterProfile] = []

    static let standard = NotchSettings()

    init() {}

    private enum CodingKeys: String, CodingKey {
        case displayMode
        case surfaceStyle
        case swipeDismissEnabled
        case alertDuration
        case islandWidth
        case islandHeight
        case characters
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        displayMode = (try? container.decodeIfPresent(DisplayMode.self, forKey: .displayMode)) ?? .auto
        surfaceStyle = (try? container.decodeIfPresent(SurfaceStyle.self, forKey: .surfaceStyle)) ?? .notch
        swipeDismissEnabled = (try? container.decodeIfPresent(Bool.self, forKey: .swipeDismissEnabled)) ?? true
        alertDuration = (try? container.decodeIfPresent(Double.self, forKey: .alertDuration)) ?? 5
        islandWidth = (try? container.decodeIfPresent(Double.self, forKey: .islandWidth)) ?? 360
        islandHeight = (try? container.decodeIfPresent(Double.self, forKey: .islandHeight)) ?? 46

        let stored = try? container.decodeIfPresent(
            [FailableDecodable<CharacterProfile>].self,
            forKey: .characters
        )
        characters = stored?.compactMap(\.value) ?? []
    }

    func sanitized() -> NotchSettings {
        var copy = self
        if copy.alertDuration < 2 {
            copy.alertDuration = 2
        }
        if copy.alertDuration > 15 {
            copy.alertDuration = 15
        }
        copy.islandWidth = min(max(copy.islandWidth, 260), 396)
        copy.islandHeight = min(max(copy.islandHeight, 38), 72)
        copy.characters = Self.sanitize(copy.characters)
        return copy
    }

    private static func sanitize(_ profiles: [CharacterProfile]) -> [CharacterProfile] {
        var seen = Set<UUID>()

        let cleaned = profiles.enumerated().compactMap { index, profile -> CharacterProfile? in
            var copy = profile
            copy.name = copy.name.trimmingCharacters(in: .whitespacesAndNewlines)
            copy.command = copy.command.trimmingCharacters(in: .whitespacesAndNewlines)

            if let directory = copy.workingDirectory?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               directory.isEmpty {
                copy.workingDirectory = nil
            }

            guard !copy.command.isEmpty else { return nil }

            if copy.name.isEmpty {
                copy.name = "Personaje \(index + 1)"
            }

            if seen.contains(copy.id) {
                copy.id = UUID()
            }
            seen.insert(copy.id)
            return copy
        }

        return Array(cleaned.prefix(12))
    }
}

/// Decodes each element independently so one malformed entry cannot discard
/// the rest of the collection.
struct FailableDecodable<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: Decoder) throws {
        value = try? Value(from: decoder)
    }
}
