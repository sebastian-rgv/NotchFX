import SwiftUI

struct NowPlayingCompactContent: View {
    let display: NowPlayingDisplay

    private var snapshotValue: NowPlayingSnapshot {
        NowPlayingSnapshot(
            title: display.title,
            artist: display.artist,
            album: nil,
            duration: display.duration,
            elapsed: display.elapsedAtTimestamp,
            rate: display.rate,
            timestamp: display.timestamp,
            isPlaying: display.isPlaying,
            source: display.source
        )
    }

    private var remaining: Double {
        max(0, display.duration - NowPlayingLogic.currentElapsed(
            snapshot: snapshotValue,
            at: Date()
        ))
    }

    private var progress: Double {
        NowPlayingLogic.progress(snapshot: snapshotValue, at: Date())
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                CompactShoulderLayout(
                    leading: {
                        EqualizerBars(isPlaying: display.isPlaying, maxHeight: 15)
                            .frame(width: 34)
                    },
                    trailing: {
                        Text("-" + NowPlayingLogic.formatClock(remaining))
                            .font(.system(size: 11, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                )

                Capsule()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: max(10, geometry.size.width * progress), height: 2.5)
            }
        }
    }
}

struct NowPlayingExpandedContent: View {
    let display: NowPlayingDisplay
    let onTogglePlayPause: () -> Void
    let onNext: () -> Void
    let onPrevious: () -> Void
    let onSeek: (Double) -> Void
    let onOpenSourceApp: () -> Void

    @State private var scrubProgress: Double?

    private var elapsed: Double {
        NowPlayingLogic.currentElapsed(
            snapshot: snapshotValue,
            at: Date()
        )
    }

    private var progress: Double {
        scrubProgress ?? NowPlayingLogic.progress(snapshot: snapshotValue, at: Date())
    }

    private var remainingText: String {
        let remaining = max(0, display.duration - elapsed)
        return "-" + NowPlayingLogic.formatClock(remaining)
    }

    private var snapshotValue: NowPlayingSnapshot {
        NowPlayingSnapshot(
            title: display.title,
            artist: display.artist,
            album: nil,
            duration: display.duration,
            elapsed: display.elapsedAtTimestamp,
            rate: display.rate,
            timestamp: display.timestamp,
            isPlaying: display.isPlaying,
            source: display.source
        )
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: display.isPlaying ? 1 : 30)) { _ in
            VStack(spacing: 7) {
                headerRow
                scrubberSection
                controlsRow
            }
            .padding(.horizontal, 24)
            .padding(.top, ScreenGeometry.notchClearance)
            .padding(.bottom, 10)
        }
    }

    private var headerRow: some View {
        HStack(spacing: 12) {
            Button(action: onOpenSourceApp) {
                EqualizerBars(isPlaying: display.isPlaying, maxHeight: 26)
                    .frame(width: 34)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                MonochromeMarqueeText(
                    text: display.title,
                    font: .system(size: 15, weight: .semibold),
                    nsFont: .systemFont(ofSize: 15, weight: .semibold),
                    color: .white.opacity(0.92)
                )
                .frame(width: 170)

                MonochromeMarqueeText(
                    text: display.artist,
                    font: .system(size: 11),
                    nsFont: .systemFont(ofSize: 11),
                    color: .white.opacity(0.5)
                )
                .frame(width: 170)
            }

            Spacer(minLength: 0)

            Text(NowPlayingLogic.formatClock(elapsed))
                .font(.system(size: 10))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private var scrubberSection: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                let trackWidth = geometry.size.width

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.18))

                    Capsule()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: max(6, trackWidth * progress))

                    Circle()
                        .fill(.white)
                        .frame(width: 9, height: 9)
                        .offset(x: max(0, min(trackWidth - 9, trackWidth * progress - 4.5)))
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            scrubProgress = min(
                                max(0, value.location.x / trackWidth),
                                1
                            )
                        }
                        .onEnded { value in
                            let target = min(max(0, value.location.x / trackWidth), 1)
                            onSeek(target * display.duration)
                            scrubProgress = nil
                        }
                )
            }
            .frame(height: 4)

            HStack {
                Text(NowPlayingLogic.formatClock(elapsed))
                Spacer()
                Text(remainingText)
            }
            .font(.system(size: 9.5))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.38))
        }
    }

    private var controlsRow: some View {
        HStack(spacing: 34) {
            MediaControlButton(symbol: "backward.fill", size: 15) {
                onPrevious()
            }

            MediaControlButton(
                symbol: display.isPlaying ? "pause.fill" : "play.fill",
                size: 21
            ) {
                onTogglePlayPause()
            }

            MediaControlButton(symbol: "forward.fill", size: 15) {
                onNext()
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct MediaControlButton: View {
    let symbol: String
    let size: CGFloat
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .regular))
                .foregroundStyle(hovering ? .white : Color.white.opacity(0.75))
                .frame(width: 40, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            self.hovering = hovering
        }
    }
}
