import Foundation
import IOKit.ps

final class BatteryMonitorService {
    private let handler: (BatteryEvent) -> Void
    private var runLoopSource: CFRunLoopSource?
    private var lastSnapshot: BatterySnapshot?

    init(handler: @escaping (BatteryEvent) -> Void) {
        self.handler = handler
    }

    func start() {
        guard runLoopSource == nil else { return }

        let context = Unmanaged.passRetained(self).toOpaque()

        let callback: @convention(c) (UnsafeMutableRawPointer?) -> Void = { context in
            guard let context else { return }
            let service = Unmanaged<BatteryMonitorService>
                .fromOpaque(context)
                .takeUnretainedValue()
            service.powerSourcesChanged()
        }

        if let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = source
        }

        lastSnapshot = readSnapshot()
    }

    func stop() {
        guard let source = runLoopSource else { return }

        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        runLoopSource = nil
        Unmanaged<BatteryMonitorService>.passUnretained(self).release()
    }

    fileprivate func powerSourcesChanged() {
        guard let snapshot = readSnapshot() else { return }

        let event = BatteryEventAnalyzer.event(from: lastSnapshot, current: snapshot)
        lastSnapshot = snapshot

        if let event {
            handler(event)
        }
    }

    private func readSnapshot() -> BatterySnapshot? {
        guard
            let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else {
            return nil
        }

        for source in list {
            guard
                let description = IOPSGetPowerSourceDescription(blob, source)?
                    .takeUnretainedValue() as? [String: Any],
                let percent = description[kIOPSCurrentCapacityKey] as? Int,
                let state = description[kIOPSPowerSourceStateKey] as? String
            else {
                continue
            }

            let isCharging = description[kIOPSIsChargingKey] as? Bool ?? false
            let isPlugged = state == kIOPSACPowerValue

            return BatterySnapshot(
                percent: percent,
                isCharging: isCharging,
                isPlugged: isPlugged
            )
        }

        return nil
    }
}
