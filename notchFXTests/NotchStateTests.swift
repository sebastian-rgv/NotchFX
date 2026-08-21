import Testing
@testable import notchFXApp

struct NotchStateTests {
    private let activity = NotchActivity(
        id: ActivityID(rawValue: "test.activity"),
        kind: .timer
    )
    private let otherActivity = NotchActivity(
        id: ActivityID(rawValue: "test.other"),
        kind: .battery
    )

    @Test func hiddenPresentsCompact() {
        let next = NotchState.hidden.transition(to: .compact(activity))
        #expect(next == .compact(activity))
    }

    @Test func compactExpands() {
        let compact = NotchState.compact(activity)
        #expect(compact.transition(to: .expanded(activity)) == .expanded(activity))
    }

    @Test func expandedCollapses() {
        let expanded = NotchState.expanded(activity)
        #expect(expanded.transition(to: .compact(activity)) == .compact(activity))
    }

    @Test func compactDismisses() {
        let compact = NotchState.compact(activity)
        #expect(compact.transition(to: .hidden) == .hidden)
    }

    @Test func expandedDismisses() {
        let expanded = NotchState.expanded(activity)
        #expect(expanded.transition(to: .hidden) == .hidden)
    }

    @Test func hiddenCannotExpandDirectly() {
        #expect(NotchState.hidden.transition(to: .expanded(activity)) == nil)
    }

    @Test func sameStateTransitionIsRejected() {
        let compact = NotchState.compact(activity)
        #expect(compact.transition(to: .compact(otherActivity)) == nil)
        #expect(NotchState.hidden.transition(to: .hidden) == nil)
        #expect(NotchState.expanded(activity).transition(to: .expanded(otherActivity)) == nil)
    }

    @Test func activityExtraction() {
        #expect(NotchState.hidden.activity == nil)
        #expect(NotchState.compact(activity).activity == activity)
        #expect(NotchState.expanded(activity).activity == activity)
    }

    @Test func isPresentedFlag() {
        #expect(!NotchState.hidden.isPresented)
        #expect(NotchState.compact(activity).isPresented)
        #expect(NotchState.expanded(activity).isPresented)
    }
}

@MainActor
struct NotchStateModelTests {
    private let activity = NotchActivity(
        id: ActivityID(rawValue: "model.test"),
        kind: .nowPlaying
    )

    @Test func presentExpandCollapseCycle() {
        let model = NotchStateModel()
        #expect(model.stateDescription == "hidden")

        model.present(activity)
        #expect(model.stateDescription == "compact:nowPlaying")

        model.expand()
        #expect(model.stateDescription == "expanded:nowPlaying")

        model.collapse()
        #expect(model.stateDescription == "compact:nowPlaying")

        model.dismiss()
        #expect(model.stateDescription == "hidden")
    }

    @Test func invalidTransitionsAreIgnored() {
        let model = NotchStateModel()

        model.expand()
        #expect(model.stateDescription == "hidden")

        model.dismiss()
        #expect(model.stateDescription == "hidden")

        model.present(activity)
        model.present(NotchActivity(id: ActivityID(rawValue: "other"), kind: .hud))
        #expect(model.stateDescription == "compact:nowPlaying")
    }

    @Test func expandWithoutActivityDoesNothing() {
        let model = NotchStateModel()
        model.expand()
        #expect(model.state == .hidden)
    }
}
