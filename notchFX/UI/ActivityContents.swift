import SwiftUI

struct TimerCompactContent: View {
    let endDate: Date

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "timer")
                .font(.system(size: 11, weight: .regular))
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(NotchRootView.formatCountdown(from: context.date, to: endDate))
                    .font(.system(size: 11, weight: .regular))
                    .monospacedDigit()
            }
        }
        .foregroundStyle(.white.opacity(0.9))
    }
}

struct TimerExpandedContent: View {
    let endDate: Date
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text("Temporizador")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.white.opacity(0.65))

            TimelineView(.periodic(from: .now, by: 0.25)) { context in
                Text(Self.formatted(from: context.date, to: endDate))
                    .font(.system(size: 30, weight: .light))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }

            Button(action: onCancel) {
                Text("Cancelar")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(.white.opacity(0.14)))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.85))
        }
    }

    static func formatted(from date: Date, to endDate: Date) -> String {
        let remaining = max(0, endDate.timeIntervalSince(date))
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        let tenths = Int((remaining - floor(remaining)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }
}

struct BatteryCompactContent: View {
    let percent: Int
    let isCharging: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: isCharging ? "battery.bolt" : "battery.75percent")
                .font(.system(size: 12, weight: .regular))
            Text("\(percent)%")
                .font(.system(size: 11, weight: .regular))
                .monospacedDigit()
        }
        .foregroundStyle(.white.opacity(0.9))
    }
}

struct BatteryExpandedContent: View {
    let percent: Int
    let isCharging: Bool

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: isCharging ? "bolt.fill" : "battery.75percent")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(isCharging ? Color.green.opacity(0.9) : .white.opacity(0.85))

            Text("\(percent)%")
                .font(.system(size: 22, weight: .light))
                .monospacedDigit()
                .foregroundStyle(.white)

            Capsule()
                .fill(.white.opacity(0.16))
                .frame(width: 120, height: 5)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.85))
                        .frame(width: max(6, 120 * CGFloat(percent) / 100))
                }
        }
    }
}

struct FinishedCompactContent: View {
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 11, weight: .regular))
            Text(label)
                .font(.system(size: 11, weight: .regular))
        }
        .foregroundStyle(.white.opacity(0.9))
    }
}

struct InfoCompactContent: View {
    let symbol: String
    let label: String
    let fallback: String

    var body: some View {
        HStack(spacing: 6) {
            if !symbol.isEmpty {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .regular))
            }
            Text(label.isEmpty ? fallback : label)
                .font(.system(size: 11, weight: .regular))
                .monospacedDigit()
        }
        .foregroundStyle(.white.opacity(0.9))
    }
}
