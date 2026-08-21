import Foundation
import Testing
@testable import notchFXApp

@MainActor
struct NotchStateReplaceTests {
    private func activity(_ raw: String, kind: ActivityKind = .timer) -> NotchActivity {
        NotchActivity(id: ActivityID(rawValue: raw), kind: kind)
    }

    @Test func replaceFromHiddenShowsCompact() {
        let model = NotchStateModel()
        model.replace(activity("a"))
        #expect(model.state == .compact(activity("a")))
    }

    @Test func replaceInCompactSwapsContent() {
        let model = NotchStateModel()
        model.present(activity("a"))
        model.replace(activity("b", kind: .battery))
        #expect(model.state == .compact(activity("b", kind: .battery)))
    }

    @Test func replaceWithDifferentActivityKeepsExpanded() {
        let model = NotchStateModel()
        model.present(activity("a"))
        model.expand()
        model.replace(activity("b"))
        #expect(model.state == .expanded(activity("a")))
    }

    @Test func replaceSameIDUpdatesExpandedContent() {
        let old = NotchActivity(
            id: ActivityID(rawValue: "a"),
            kind: .timer,
            detail: .timer(endDate: Date(timeIntervalSince1970: 0))
        )
        let updated = NotchActivity(
            id: ActivityID(rawValue: "a"),
            kind: .timer,
            detail: .timer(endDate: Date(timeIntervalSince1970: 500))
        )

        let model = NotchStateModel()
        model.present(old)
        model.expand()
        model.replace(updated)

        #expect(model.state == .expanded(updated))
    }
}
