import Foundation
import Testing
@testable import notchFXApp

@MainActor
struct ActivityEngineTests {
    private let base = Date(timeIntervalSince1970: 1000)

    @Test func ambientBecomesVisible() {
        let stateModel = NotchStateModel()
        let engine = ActivityEngine(stateModel: stateModel)
        let now = base
        engine.now = { now }

        let timer = NotchActivity(
            id: ActivityID(rawValue: "timer"),
            kind: .timer,
            detail: .timer(endDate: base.addingTimeInterval(60))
        )

        engine.present(timer, priority: .ambient)
        #expect(stateModel.state == .compact(timer))
    }

    @Test func alertPreemptsAmbientAndReturnsAfterExpiry() {
        let stateModel = NotchStateModel()
        let engine = ActivityEngine(stateModel: stateModel)
        var now = base
        engine.now = { now }

        let timer = NotchActivity(
            id: ActivityID(rawValue: "timer"),
            kind: .timer,
            detail: .timer(endDate: base.addingTimeInterval(600))
        )
        engine.present(timer, priority: .ambient)

        let alert = NotchActivity(
            id: ActivityID(rawValue: "alert"),
            kind: .battery,
            detail: .battery(percent: 15, isCharging: false)
        )
        engine.present(alert, priority: .alert, ttl: 5)
        #expect(stateModel.state == .compact(alert))

        now = base.addingTimeInterval(6)
        engine.refresh()
        #expect(stateModel.state == .compact(timer))
    }

    @Test func stickyAmbientSurvivesAlertExpiryAndStaysUntilFinished() {
        let stateModel = NotchStateModel()
        let engine = ActivityEngine(stateModel: stateModel)
        var now = base
        engine.now = { now }

        let timer = NotchActivity(id: ActivityID(rawValue: "timer"), kind: .timer)
        engine.present(timer, priority: .ambient)

        let alert = NotchActivity(id: ActivityID(rawValue: "alert"), kind: .hud)
        engine.present(alert, priority: .critical, ttl: 3)

        now = base.addingTimeInterval(10)
        engine.refresh()
        #expect(stateModel.state == .compact(timer))

        engine.finish(ActivityID(rawValue: "timer"))
        #expect(stateModel.state == .hidden)
    }

    @Test func finishingUnknownActivityKeepsCurrentTop() {
        let stateModel = NotchStateModel()
        let engine = ActivityEngine(stateModel: stateModel)
        engine.now = { base }

        let timer = NotchActivity(id: ActivityID(rawValue: "timer"), kind: .timer)
        engine.present(timer, priority: .ambient)

        engine.finish(ActivityID(rawValue: "does-not-exist"))
        #expect(stateModel.state == .compact(timer))
    }

    @Test func criticalPreemptsAlert() {
        let stateModel = NotchStateModel()
        let engine = ActivityEngine(stateModel: stateModel)
        engine.now = { base }

        let alert = NotchActivity(id: ActivityID(rawValue: "alert"), kind: .battery)
        engine.present(alert, priority: .alert, ttl: 30)
        #expect(stateModel.state == .compact(alert))

        let hud = NotchActivity(id: ActivityID(rawValue: "hud"), kind: .hud)
        engine.present(hud, priority: .critical, ttl: 2)
        #expect(stateModel.state == .compact(hud))

        let afterHud = base.addingTimeInterval(2.1)
        engine.now = { afterHud }
        engine.refresh()
        #expect(stateModel.state == .compact(alert))
    }
}
