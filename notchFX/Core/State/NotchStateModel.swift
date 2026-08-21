import Foundation

@MainActor
final class NotchStateModel: ObservableObject {
    @Published private(set) var state: NotchState = .hidden

    var stateDescription: String {
        switch state {
        case .hidden:
            return "hidden"
        case .compact(let activity):
            return "compact:\(activity.kind.rawValue)"
        case .expanded(let activity):
            return "expanded:\(activity.kind.rawValue)"
        }
    }

    func present(_ activity: NotchActivity) {
        apply(.compact(activity))
    }

    func replace(_ activity: NotchActivity) {
        switch state {
        case .hidden:
            state = .compact(activity)
        case .compact:
            state = .compact(activity)
        case .expanded(let current):
            if current.id == activity.id {
                state = .expanded(activity)
            }
        }
    }

    func expand() {
        guard let activity = state.activity else { return }
        apply(.expanded(activity))
    }

    func collapse() {
        guard let activity = state.activity else { return }
        apply(.compact(activity))
    }

    func toggleExpanded() {
        switch state {
        case .compact:
            expand()
        case .expanded:
            collapse()
        case .hidden:
            break
        }
    }

    func dismiss() {
        apply(.hidden)
    }

    private func apply(_ target: NotchState) {
        guard let next = state.transition(to: target) else { return }
        state = next
    }
}
