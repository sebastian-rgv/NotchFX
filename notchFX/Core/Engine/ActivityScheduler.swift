import Foundation

struct ScheduledActivity: Equatable {
    let activity: NotchActivity
    let priority: ActivityPriority
    let expiresAt: Date?
    let sequence: UInt64

    func isExpired(at date: Date) -> Bool {
        guard let expiresAt else { return false }
        return expiresAt <= date
    }
}

struct ActivityScheduler {
    private(set) var entries: [ScheduledActivity] = []
    private var sequence: UInt64 = 0

    var top: ScheduledActivity? {
        entries.first
    }

    mutating func upsert(
        _ activity: NotchActivity,
        priority: ActivityPriority,
        expiresAt: Date?
    ) {
        sequence += 1
        let entry = ScheduledActivity(
            activity: activity,
            priority: priority,
            expiresAt: expiresAt,
            sequence: sequence
        )
        entries.removeAll { $0.activity.id == entry.activity.id }
        entries.append(entry)
        entries.sort { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }
            return lhs.sequence > rhs.sequence
        }
    }

    mutating func remove(_ id: ActivityID) {
        entries.removeAll { $0.activity.id == id }
    }

    @discardableResult
    mutating func expire(now: Date) -> [ScheduledActivity] {
        let expired = entries.filter { $0.isExpired(at: now) }
        guard !expired.isEmpty else { return [] }
        let expiredIDs = Set(expired.map(\.activity.id))
        entries.removeAll { expiredIDs.contains($0.activity.id) }
        return expired
    }

    func nextExpiry(after date: Date) -> Date? {
        entries
            .compactMap(\.expiresAt)
            .filter { $0 > date }
            .min()
    }

    func contains(_ id: ActivityID) -> Bool {
        entries.contains { $0.activity.id == id }
    }
}
