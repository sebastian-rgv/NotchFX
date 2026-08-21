import Foundation

struct ActivityID: Hashable, Codable, RawRepresentable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}
