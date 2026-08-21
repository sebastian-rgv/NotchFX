import Foundation
import Testing
@testable import notchFXApp

struct ActivitySchedulerTests {
    private let base = Date(timeIntervalSince1970: 1000)

    private func makeActivity(_ raw: String) -> NotchActivity {
        NotchActivity(id: ActivityID(rawValue: raw), kind: .timer)
    }

    @Test func emptySchedulerHasNoTop() {
        var scheduler = ActivityScheduler()
        #expect(scheduler.top == nil)
        scheduler.upsert(makeActivity("a"), priority: .ambient, expiresAt: nil)
        #expect(scheduler.top != nil)
    }

    @Test func higherPriorityWins() {
        var scheduler = ActivityScheduler()
        let ambient = makeActivity("ambient")
        let alert = makeActivity("alert")

        scheduler.upsert(ambient, priority: .ambient, expiresAt: nil)
        #expect(scheduler.top?.activity.id.rawValue == "ambient")

        scheduler.upsert(alert, priority: .alert, expiresAt: nil)
        #expect(scheduler.top?.activity.id.rawValue == "alert")

        scheduler.remove(ActivityID(rawValue: "alert"))
        #expect(scheduler.top?.activity.id.rawValue == "ambient")
    }

    @Test func newestWinsOnEqualPriority() {
        var scheduler = ActivityScheduler()
        let first = makeActivity("first")
        let second = makeActivity("second")

        scheduler.upsert(first, priority: .alert, expiresAt: nil)
        scheduler.upsert(second, priority: .alert, expiresAt: nil)

        #expect(scheduler.top?.activity.id.rawValue == "second")
        #expect(scheduler.entries.count == 2)
    }

    @Test func upsertReplacesSameActivityWithoutDuplication() {
        var scheduler = ActivityScheduler()
        let id = ActivityID(rawValue: "timer")

        scheduler.upsert(NotchActivity(id: id, kind: .timer), priority: .ambient, expiresAt: nil)
        scheduler.upsert(
            NotchActivity(id: id, kind: .timer, detail: .timer(endDate: base)),
            priority: .critical,
            expiresAt: nil
        )

        #expect(scheduler.entries.count == 1)
        #expect(scheduler.top?.priority == .critical)
        #expect(scheduler.top?.activity.detail == .timer(endDate: base))
    }

    @Test func expireSweepsOnlyExpiredEntries() {
        var scheduler = ActivityScheduler()
        let sticky = makeActivity("sticky")
        let shortLived = makeActivity("short")
        let later = makeActivity("later")

        scheduler.upsert(sticky, priority: .alert, expiresAt: nil)
        scheduler.upsert(shortLived, priority: .alert, expiresAt: base.addingTimeInterval(5))
        scheduler.upsert(later, priority: .ambient, expiresAt: base.addingTimeInterval(60))

        let expired = scheduler.expire(now: base.addingTimeInterval(10))

        #expect(expired.count == 1)
        #expect(expired.first?.activity.id.rawValue == "short")
        #expect(scheduler.contains(ActivityID(rawValue: "sticky")))
        #expect(scheduler.contains(ActivityID(rawValue: "later")))
    }

    @Test func nextExpiryIgnoresPastDates() {
        var scheduler = ActivityScheduler()
        scheduler.upsert(
            makeActivity("past"),
            priority: .ambient,
            expiresAt: base.addingTimeInterval(-10)
        )
        scheduler.upsert(
            makeActivity("future"),
            priority: .ambient,
            expiresAt: base.addingTimeInterval(30)
        )
        scheduler.upsert(makeActivity("forever"), priority: .ambient, expiresAt: nil)

        #expect(scheduler.nextExpiry(after: base) == base.addingTimeInterval(30))
    }

    @Test func isExpiredBoundary() {
        let entry = ScheduledActivity(
            activity: makeActivity("x"),
            priority: .ambient,
            expiresAt: base,
            sequence: 1
        )
        #expect(entry.isExpired(at: base))
        #expect(!entry.isExpired(at: base.addingTimeInterval(-0.001)))
    }
}
