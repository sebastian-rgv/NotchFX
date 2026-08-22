import SwiftUI

struct TimerCompactContent: View {
    let endDate: Date

    var body: some View {
        CompactShoulderLayout(
            leading: {
                Image(systemName: "timer")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.85))
            },
            trailing: {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(NotchRootView.formatCountdown(from: context.date, to: endDate))
                        .font(.system(size: 11.5, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        )
    }
}

struct BatteryCompactContent: View {
    let percent: Int
    let isCharging: Bool

    var body: some View {
        CompactShoulderLayout(
            leading: {
                Image(systemName: isCharging ? "battery.bolt" : "battery.75percent")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(isCharging ? Color.green.opacity(0.9) : .white.opacity(0.85))
            },
            trailing: {
                Text("\(percent)%")
                    .font(.system(size: 11.5, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.85))
            }
        )
    }
}

struct FinishedCompactContent: View {
    let label: String

    var body: some View {
        CompactShoulderLayout(
            leading: {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.85))
            },
            trailing: {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(.white.opacity(0.85))
            }
        )
    }
}

struct InfoCompactContent: View {
    let symbol: String
    let label: String
    let fallback: String

    var body: some View {
        CompactShoulderLayout(
            leading: {
                if !symbol.isEmpty {
                    Image(systemName: symbol)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.white.opacity(0.85))
                }
            },
            trailing: {
                Text(label.isEmpty ? fallback : label)
                    .font(.system(size: 11, weight: .regular))
                    .monospacedDigit()
                    .lineLimit(1)
                    .foregroundStyle(.white.opacity(0.75))
            }
        )
    }
}

struct CompactShoulderLayout<Leading: View, Trailing: View>: View {
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            HStack {
                leading()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, ScreenGeometry.shoulderInset)

                Spacer(minLength: ScreenGeometry.notchClearance * 6)

                trailing()
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, ScreenGeometry.shoulderInset + 4)
            }

            Capsule()
                .fill(Color.clear)
                .frame(height: 1)
        }
    }
}

struct TimerExpandedContent: View {
    let endDate: Date
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            TimelineView(.periodic(from: .now, by: 0.25)) { context in
                Text(Self.formatted(from: context.date, to: endDate))
                    .font(.system(size: 26, weight: .light))
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
