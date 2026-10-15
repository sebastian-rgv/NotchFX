import SwiftUI

struct TerminalCompactContent: View {
    let display: TerminalDisplay

    var body: some View {
        CompactShoulderLayout(
            leading: {
                Image(systemName: "terminal")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(display.isRunning ? Color.green.opacity(0.9) : .white.opacity(0.85))
            },
            trailing: {
                Text(display.statusText)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(.white.opacity(0.8))
            }
        )
    }
}

struct TerminalExpandedContent: View {
    let display: TerminalDisplay
    let onRerun: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            header
            logView
            controlsRow
        }
        .padding(.horizontal, 22)
        .padding(.top, ScreenGeometry.notchClearance)
        .padding(.bottom, 10)
    }

    private var header: some View {
        HStack(spacing: 7) {
            Image(systemName: "terminal")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))

            Text(display.scriptName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))

            Spacer(minLength: 0)

            statusBadge
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 5) {
            if display.isRunning {
                ProgressView()
                    .controlSize(.mini)
            }

            Text(display.statusText)
                .font(.system(size: 9.5, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(statusColor)
        }
    }

    private var statusColor: Color {
        if display.isRunning { return .white.opacity(0.7) }
        guard let exitCode = display.exitCode else { return .white.opacity(0.7) }
        return exitCode == 0 ? Color.green.opacity(0.9) : Color.orange.opacity(0.9)
    }

    private var logView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(display.lines.enumerated()), id: \.offset) { _, line in
                        Text(line.isEmpty ? " " : line)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.82))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Color.clear.frame(height: 1).id("log.bottom")
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.white.opacity(0.06))
            )
            .onChange(of: display.lines.count) { _, _ in
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo("log.bottom", anchor: .bottom)
                }
            }
        }
    }

    private var controlsRow: some View {
        HStack(spacing: 10) {
            Button(action: onRerun) {
                Label("Re-ejecutar", systemImage: "arrow.clockwise")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.white.opacity(0.14)))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(display.isRunning ? 0.35 : 0.85))
            .disabled(display.isRunning)

            Button(action: onClose) {
                Text("Cerrar")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.white.opacity(0.14)))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.85))

            Spacer(minLength: 0)
        }
    }
}
