import Foundation

enum ActivityPriority: Int, Comparable {
    case ambient = 0
    case alert = 1
    case critical = 2

    static func < (lhs: ActivityPriority, rhs: ActivityPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
