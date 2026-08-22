import CoreMediaIO
import Foundation

final class CameraMonitor {
    private var pollTimer: Timer?
    private let handler: (Bool) -> Void
    private(set) var isInUse = false

    init(handler: @escaping (Bool) -> Void) {
        self.handler = handler
    }

    func start(interval: TimeInterval = 1.5) {
        guard pollTimer == nil else { return }
        poll()
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.poll()
            }
        }
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func poll() {
        let inUse = Self.isAnyCameraActive()
        if inUse != isInUse {
            isInUse = inUse
            handler(inUse)
        }
    }

    static func isAnyCameraActive() -> Bool {
        var propertyAddress = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )

        var dataSize: UInt32 = 0
        let systemObject = CMIOObjectID(kCMIOObjectSystemObject)

        guard
            CMIOObjectGetPropertyDataSize(systemObject, &propertyAddress, 0, nil, &dataSize) == 0,
            dataSize > 0
        else { return false }

        let deviceCount = Int(dataSize) / MemoryLayout<CMIOObjectID>.size
        var devices = [CMIOObjectID](repeating: 0, count: deviceCount)
        var devicesUsed: UInt32 = 0

        guard
            CMIOObjectGetPropertyData(systemObject, &propertyAddress, 0, nil, dataSize, &devicesUsed, &devices) == 0
        else { return false }

        for device in devices {
            var runningAddress = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
            )

            var running: UInt32 = 0
            var runningSize = UInt32(MemoryLayout<UInt32>.size)
            var runningUsed: UInt32 = 0

            if
                CMIOObjectGetPropertyData(device, &runningAddress, 0, nil, runningSize, &runningUsed, &running) == 0,
                running != 0
            {
                return true
            }
        }

        return false
    }
}
