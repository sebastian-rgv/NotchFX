import Foundation
import Testing
@testable import notchFXApp

struct BatteryAnalyzerTests {
    private func snapshot(
        percent: Int,
        charging: Bool,
        plugged: Bool
    ) -> BatterySnapshot {
        BatterySnapshot(percent: percent, isCharging: charging, isPlugged: plugged)
    }

    @Test func baselineProducesNoEvent() {
        let current = snapshot(percent: 80, charging: true, plugged: true)
        #expect(BatteryEventAnalyzer.event(from: nil, current: current) == nil)
    }

    @Test func unchangedStateProducesNoEvent() {
        let previous = snapshot(percent: 80, charging: true, plugged: true)
        let current = snapshot(percent: 82, charging: true, plugged: true)
        #expect(BatteryEventAnalyzer.event(from: previous, current: current) == nil)
    }

    @Test func chargingStartIsDetected() {
        let previous = snapshot(percent: 50, charging: false, plugged: false)
        let current = snapshot(percent: 51, charging: true, plugged: true)
        #expect(BatteryEventAnalyzer.event(from: previous, current: current) == .chargingStarted(percent: 51))
    }

    @Test func fullChargeIsDetected() {
        let previous = snapshot(percent: 93, charging: true, plugged: true)
        let current = snapshot(percent: 100, charging: false, plugged: true)
        #expect(BatteryEventAnalyzer.event(from: previous, current: current) == .fullyCharged(percent: 100))
    }

    @Test func stayingFullyChargedDoesNotRepeat() {
        let previous = snapshot(percent: 100, charging: false, plugged: true)
        let current = snapshot(percent: 100, charging: false, plugged: true)
        #expect(BatteryEventAnalyzer.event(from: previous, current: current) == nil)
    }

    @Test func lowBatteryCrossingOnBatteryPower() {
        let previous = snapshot(percent: 21, charging: false, plugged: false)
        let current = snapshot(percent: 20, charging: false, plugged: false)
        #expect(BatteryEventAnalyzer.event(from: previous, current: current) == .lowBattery(percent: 20))
    }

    @Test func lowBatteryWhilePluggedIsIgnored() {
        let previous = snapshot(percent: 25, charging: false, plugged: false)
        let current = snapshot(percent: 18, charging: false, plugged: true)
        #expect(BatteryEventAnalyzer.event(from: previous, current: current) == nil)
    }

    @Test func lowBatteryDoesNotRetriggerBelowThreshold() {
        let previous = snapshot(percent: 19, charging: false, plugged: false)
        let current = snapshot(percent: 12, charging: false, plugged: false)
        #expect(BatteryEventAnalyzer.event(from: previous, current: current) == nil)
    }

    @Test func eventDetailCarriesBatteryDisplay() {
        #expect(
            BatteryEvent.chargingStarted(percent: 60).detail
                == .battery(percent: 60, isCharging: true)
        )
        #expect(
            BatteryEvent.lowBattery(percent: 18).detail
                == .battery(percent: 18, isCharging: false)
        )
    }
}
