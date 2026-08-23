import SwiftUI

struct NowPlayingCompactContent: View {
    let display: NowPlayingDisplay
    var artwork: NSImage? = nil

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

    private func remaining(at date: Date) -> Double {
        max(0, display.duration - NowPlayingLogic.currentElapsed(
            snapshot: snapshotValue,
            at: date
        ))
    }

    private func progress(at date: Date) -> Double {
        NowPlayingLogic.progress(snapshot: snapshotValue, at: date)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                CompactShoulderLayout(
                    leading: {
                        HStack(spacing: 7) {
                            if let artwork {
                                Image(nsImage: artwork)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 20, height: 20)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }

                            EqualizerBars(isPlaying: display.isPlaying, maxHeight: 13)
                                .frame(width: 28)
                        }
                    },
                    trailing: {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text("-" + NowPlayingLogic.formatClock(remaining(at: context.date)))
                                .font(.system(size: 11, weight: .medium))
                                .monospacedDigit()
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                )

            }
        }
    }
}

struct NowPlayingExpandedContent: View {
    let display: NowPlayingDisplay
    var artwork: NSImage? = nil
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
                if let artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 42, height: 42)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    EqualizerBars(isPlaying: display.isPlaying, maxHeight: 26)
                        .frame(width: 34)
                }
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
        VStack(spacing: 10) {
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
