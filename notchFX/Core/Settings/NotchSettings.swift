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

    static let standard = NotchSettings()

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
        return copy
    }
}
