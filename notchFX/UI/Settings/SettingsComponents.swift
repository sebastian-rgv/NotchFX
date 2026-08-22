import SwiftUI

struct PaneSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .kerning(0.5)

            VStack(alignment: .leading, spacing: 14) {
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.05))
            )
        }
        .padding(.bottom, 8)
    }
}

struct PaneCaption: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct NotchProportionsPreview: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let scale = min(
                (geometry.size.width - 40) / ScreenGeometry.windowWidth,
                (geometry.size.height - 16) / ScreenGeometry.windowHeight,
                1.4
            )

            ZStack(alignment: .top) {
                NotchShape(cornerRadius: 14 * scale)
                    .fill(Color.black)
                    .frame(
                        width: width * scale,
                        height: height * scale
                    )
                    .overlay(alignment: .bottomLeading) {
                        EqualizerBars(isPlaying: true, maxHeight: 10 * scale)
                            .padding(.leading, 28 * scale)
                            .padding(.bottom, 6 * scale)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Text("-2:41")
                            .font(.system(size: 9 * scale))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.trailing, 30 * scale)
                            .padding(.bottom, 5 * scale)
                    }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}
