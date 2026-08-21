import Foundation

struct BatterySnapshot: Equatable {
    let percent: Int
    let isCharging: Bool
    let isPlugged: Bool

    var isFullyCharged: Bool {
        isPlugged && !isCharging && percent >= 95
    }
}

enum BatteryEvent: Equatable {
    case chargingStarted(percent: Int)
    case fullyCharged(percent: Int)
    case lowBattery(percent: Int)

    var detail: ActivityDetail {
        switch self {
        case .chargingStarted(let percent):
            return .battery(percent: percent, isCharging: true)
        case .fullyCharged(let percent):
            return .battery(percent: percent, isCharging: false)
        case .lowBattery(let percent):
            return .battery(percent: percent, isCharging: false)
        }
    }
}

enum BatteryEventAnalyzer {
    static func event(
        from previous: BatterySnapshot?,
        current: BatterySnapshot,
        lowBatteryThreshold: Int = 20
    ) -> BatteryEvent? {
        guard let previous else { return nil }

        if current.isCharging && !previous.isCharging {
            return .chargingStarted(percent: current.percent)
        }

        if current.isFullyCharged && !previous.isFullyCharged {
            return .fullyCharged(percent: current.percent)
        }

        let crossedLow = previous.percent > lowBatteryThreshold
            && current.percent <= lowBatteryThreshold
        if crossedLow && !current.isPlugged {
            return .lowBattery(percent: current.percent)
        }

        return nil
    }
}
