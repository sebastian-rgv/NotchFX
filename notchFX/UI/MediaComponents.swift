import Foundation
import SwiftUI

struct EqualizerBars: View {
    let isPlaying: Bool
    var barWidth: CGFloat = 3
    var spacing: CGFloat = 2.5
    var maxHeight: CGFloat = 16

    // Per-bar motion: height fractions at the wave's trough/crest,
    // angular speed (rad/s) and phase offset (rad).
    private let bars: [(low: CGFloat, high: CGFloat, speed: Double, phase: Double)] = [
        (0.21, 1.00, 5.7, 0.0),
        (0.33, 0.87, 7.5, 1.1),
        (0.18, 1.00, 5.1, 2.3),
        (0.30, 0.85, 6.5, 0.6)
    ]

    var body: some View {
        // Heights are a pure function of time, driven by the timeline's own
        // display link. This keeps the bars moving regardless of how often
        // the parent view re-renders (snapshot updates, expansion, AnyView
        // erasure) - a repeatForever implicit animation stalls in that case.
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isPlaying)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(bars.indices, id: \.self) { index in
                    Capsule()
                        .fill(Color.white.opacity(index % 2 == 0 ? 0.85 : 0.5))
                        .frame(width: barWidth, height: height(for: index, at: time))
                }
            }
            .frame(height: maxHeight, alignment: .bottom)
        }
    }

    private func height(for index: Int, at time: Double) -> CGFloat {
        let bar = bars[index]
        let wave = isPlaying ? (sin(time * bar.speed + bar.phase) + 1) / 2 : 0
        let fraction = bar.low + (bar.high - bar.low) * wave
        return max(2, maxHeight * fraction)
    }
}

struct MonochromeMarqueeText: View {
    let text: String
    let font: Font
    let nsFont: NSFont
    let color: Color

    @State private var offset: CGFloat = 0
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geometry in
            let textWidth = measuredWidth(of: text)
            let overflow = textWidth - geometry.size.width

            Group {
                if overflow > 4 {
                    Text(text)
                        .font(font)
                        .foregroundStyle(color)
                        .lineLimit(1)
                        .fixedSize()
                        .offset(x: offset)
                        .task(id: text) {
                            await scrollLoop(width: overflow)
                        }
                } else {
                    Text(text)
                        .font(font)
                        .foregroundStyle(color)
                        .lineLimit(1)
                }
            }
            .frame(width: geometry.size.width, alignment: .leading)
        }
        .frame(height: lineHeight)
        .clipped()
    }

    private var lineHeight: CGFloat { nsFont.pointSize * 1.25 }

    private func measuredWidth(of string: String) -> CGFloat {
        NSAttributedString(string: text, attributes: [.font: nsFont])
            .size().width
    }

    private func scrollLoop(width overflow: CGFloat) async {
        while !Task.isCancelled {
            offset = 0
            try? await Task.sleep(nanoseconds: 1_400_000_000)

            withAnimation(.linear(duration: max(3.5, overflow / 26))) {
                offset = -(overflow + 18)
            }

            try? await Task.sleep(nanoseconds: UInt64(max(3.5, overflow / 26) * 1_000_000_000) + 1_600_000_000)
            withAnimation(.linear(duration: 0.001)) {
                offset = 0
            }
        }
    }
}
