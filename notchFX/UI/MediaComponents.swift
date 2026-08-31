import SwiftUI

struct EqualizerBars: View {
    let isPlaying: Bool
    var barWidth: CGFloat = 3
    var spacing: CGFloat = 2.5
    var maxHeight: CGFloat = 16

    @State private var animating = false

    private let patterns: [(base: CGFloat, amp: CGFloat, speed: Double, delay: Double)] = [
        (0.35, 0.65, 0.55, 0),
        (0.55, 0.45, 0.42, 0.12),
        (0.30, 0.70, 0.62, 0.05),
        (0.50, 0.50, 0.48, 0.18)
    ]

    var body: some View {
        HStack(alignment: .bottom, spacing: spacing) {
            ForEach(0..<patterns.count, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(index % 2 == 0 ? 0.85 : 0.5))
                    .frame(width: barWidth, height: height(for: index))
                    .animation(
                        isPlaying && animating
                            ? .easeInOut(duration: patterns[index].speed)
                                .repeatForever(autoreverses: true)
                                .delay(patterns[index].delay)
                            : .easeOut(duration: 0.25),
                        value: animating
                    )
            }
        }
        .frame(height: maxHeight, alignment: .bottom)
        .onChange(of: isPlaying) { _, playing in
            restartAnimation(playing: playing)
        }
        .onAppear {
            animating = isPlaying
        }
    }

    private func restartAnimation(playing: Bool) {
        animating = false
        guard playing else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            animating = true
        }
    }

    private func height(for index: Int) -> CGFloat {
        let pattern = patterns[index % patterns.count]
        let fraction = animating && isPlaying
            ? pattern.base + pattern.amp * (index % 2 == 0 ? 1 : 0.7)
            : pattern.base * 0.6
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
