import Foundation

enum NotchState: Equatable {
    case hidden
    case compact(NotchActivity)
    case expanded(NotchActivity)

    func transition(to target: NotchState) -> NotchState? {
        switch (self, target) {
        case (.hidden, .compact),
             (.compact, .expanded),
             (.expanded, .compact),
             (.compact, .hidden),
             (.expanded, .hidden):
            return target
        default:
            return nil
        }
    }

    var isPresented: Bool {
        if case .hidden = self {
            return false
        }
        return true
    }

    var activity: NotchActivity? {
        switch self {
        case .hidden:
            return nil
        case .compact(let activity):
            return activity
        case .expanded(let activity):
            return activity
        }
    }
}
