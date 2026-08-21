import Foundation

@MainActor
final class LocalTimerController {
    private let engine: ActivityEngine
    private var endTask: Task<Void, Never>?
    private var activeTimerID = ActivityID(rawValue: "timer.local")

    init(engine: ActivityEngine) {
        self.engine = engine
    }

    func start(duration: TimeInterval) {
        endTask?.cancel()

        let endDate = Date().addingTimeInterval(duration)

        engine.present(
            NotchActivity(
                id: activeTimerID,
                kind: .timer,
                detail: .timer(endDate: endDate)
            ),
            priority: .ambient
        )

        endTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.complete()
        }
    }

    func cancel() {
        endTask?.cancel()
        endTask = nil
        engine.finish(activeTimerID)
    }

    private func complete() {
        endTask = nil
        engine.finish(activeTimerID)
        engine.present(
            NotchActivity(
                id: ActivityID(rawValue: "timer.finished"),
                kind: .timer,
                detail: .timerFinished(label: "Timer")
            ),
            priority: .critical,
            ttl: 4
        )
    }
}
