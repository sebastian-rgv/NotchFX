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

    func expand() {
        guard let activity = state.activity else { return }
        apply(.expanded(activity))
    }

    func collapse() {
        guard let activity = state.activity else { return }
        apply(.compact(activity))
    }

    func dismiss() {
        apply(.hidden)
    }

    private func apply(_ target: NotchState) {
        guard let next = state.transition(to: target) else { return }
        state = next
    }
}
