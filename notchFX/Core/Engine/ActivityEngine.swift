import Foundation

@MainActor
final class ActivityEngine: ObservableObject {
    private let stateModel: NotchStateModel
    private var scheduler = ActivityScheduler()
    private var expiryTask: Task<Void, Never>?

    var now: () -> Date = { Date() }

    init(stateModel: NotchStateModel) {
        self.stateModel = stateModel
    }

    func present(
        _ activity: NotchActivity,
        priority: ActivityPriority,
        ttl: TimeInterval? = nil
    ) {
        let expiration = ttl.map { now().addingTimeInterval($0) }
        scheduler.upsert(activity, priority: priority, expiresAt: expiration)
        refresh()
    }

    func finish(_ id: ActivityID) {
        scheduler.remove(id)
        refresh()
    }

    /// Surfaces an activity immediately, overriding an expanded view that
    /// belongs to a different activity. Used for user-initiated actions such
    /// as the terminal, where the notch must switch even while music is
    /// expanded.
    func focus(_ activity: NotchActivity, priority: ActivityPriority) {
        scheduler.upsert(activity, priority: priority, expiresAt: nil)
        stateModel.present(activity)
        scheduleNextExpiry()
    }

    func dismissTop() {
        guard let top = scheduler.top else { return }
        scheduler.remove(top.activity.id)
        refresh()
    }

    func refresh() {
        scheduler.expire(now: now())

        if let top = scheduler.top {
            stateModel.replace(top.activity)
        } else {
            stateModel.dismiss()
        }

        scheduleNextExpiry()
    }

    private func scheduleNextExpiry() {
        expiryTask?.cancel()

        guard let next = scheduler.nextExpiry(after: now()) else { return }

        let delay = max(0.05, next.timeIntervalSince(now()) + 0.02)

        expiryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }
}
