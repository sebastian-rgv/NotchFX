import SwiftUI

struct CharactersCompactContent: View {
    let display: CharactersDisplay

    var body: some View {
        CompactShoulderLayout(
            leading: {
                if display.snapshots.isEmpty {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.white.opacity(0.85))
                } else {
                    HStack(spacing: 3) {
                        ForEach(Array(display.snapshots.prefix(4))) { snapshot in
                            GhostCharacterView(
                                style: snapshot.style,
                                state: snapshot.state,
                                size: 15
                            )
                        }
                    }
                }
            },
            trailing: {
                Text(statusText)
                    .font(.system(size: 10.5, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(.white.opacity(0.8))
            }
        )
    }

    private var statusText: String {
        if display.hasRunning {
            return "\(display.runningCount) trabajando"
        }

        guard let selected = display.snapshots.first(where: {
            $0.id == display.selectedID
        }) else {
            return "personajes"
        }

        switch selected.state {
        case .idle: return "listo para trabajar"
        case .running: return "trabajando"
        case .succeeded: return "listo"
        case .failed(let code): return "error (\(code))"
        case .stopped: return "detenido"
        }
    }
}

struct CharactersExpandedContent: View {
    let display: CharactersDisplay
    let onSelect: (UUID?) -> Void
    let onRerun: (UUID) -> Void
    let onStop: (UUID) -> Void
    let onStopAll: () -> Void
    let onManage: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 7) {
            header

            if display.snapshots.isEmpty {
                emptyState
            } else {
                chips
                logView
                controlsRow
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, ScreenGeometry.notchClearance)
        .padding(.bottom, 12)
    }

    private var selected: CharacterSnapshot? {
        display.snapshots.first { $0.id == display.selectedID }
    }

    private var header: some View {
        HStack(spacing: 7) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))

            Text("Personajes")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))

            Spacer(minLength: 0)

            Text(summaryText)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var summaryText: String {
        if display.hasRunning {
            return "\(display.runningCount) en marcha"
        }
        return "\(display.snapshots.count) disponibles"
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(display.snapshots) { snapshot in
                    chip(for: snapshot)
                }
            }
            .padding(.vertical, 1)
        }
        .frame(height: 42)
    }

    private func chip(for snapshot: CharacterSnapshot) -> some View {
        let isSelected = snapshot.id == display.selectedID

        return HStack(spacing: 6) {
            GhostCharacterView(
                style: snapshot.style,
                state: snapshot.state,
                size: 24
            )

            VStack(alignment: .leading, spacing: 0) {
                Text(snapshot.name)
                    .font(.system(size: 9.5, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(.white.opacity(0.92))

                Text(Self.label(for: snapshot.state))
                    .font(.system(size: 8, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(Self.statusColor(for: snapshot.state))
            }
            .frame(maxWidth: 72, alignment: .leading)

            Button {
                if snapshot.state.isRunning {
                    onStop(snapshot.id)
                } else {
                    onRerun(snapshot.id)
                }
            } label: {
                Image(systemName: snapshot.state.isRunning ? "stop.fill" : "play.fill")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(.white.opacity(isSelected ? 0.14 : 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(.white.opacity(isSelected ? 0.45 : 0.06), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect(snapshot.id)
        }
    }

    private var logView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 1) {
                    if display.selectedLines.isEmpty {
                        Text(emptyLogText)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(Array(display.selectedLines.enumerated()), id: \.offset) { _, line in
                            Text(line.isEmpty ? " " : line)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.82))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
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
            .onChange(of: display.selectedLines.count) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: display.selectedID) { _, _ in
                scrollToBottom(proxy)
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.12)) {
            proxy.scrollTo("log.bottom", anchor: .bottom)
        }
    }

    private var emptyLogText: String {
        guard let selected else { return "Selecciona un personaje." }
        if selected.state.isRunning { return "Esperando salida…" }
        return "Sin salida todavía."
    }

    private var controlsRow: some View {
        HStack(spacing: 8) {
            CharacterCapsuleButton(
                title: "Re-ejecutar",
                symbol: "arrow.clockwise",
                enabled: selected != nil && selected?.state.isRunning == false
            ) {
                if let selected { onRerun(selected.id) }
            }

            CharacterCapsuleButton(
                title: "Detener",
                symbol: "stop.fill",
                enabled: selected?.state.isRunning == true
            ) {
                if let selected { onStop(selected.id) }
            }

            if display.hasRunning {
                CharacterCapsuleButton(
                    title: "Detener todo",
                    symbol: "stop.circle",
                    enabled: true
                ) {
                    onStopAll()
                }
            }

            Spacer(minLength: 0)

            Button(action: onManage) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(.white.opacity(0.14)))
            }
            .buttonStyle(.plain)
            .help("Gestionar personajes")

            Button(action: onClose) {
                Text("Cerrar")
                    .font(.system(size: 9.5, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.white.opacity(0.14)))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.85))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 0)

            HStack(spacing: 10) {
                GhostCharacterView(style: .blinky, state: .idle, size: 30)
                GhostCharacterView(style: .pinky, state: .idle, size: 30)
                GhostCharacterView(style: .inky, state: .idle, size: 30)
                GhostCharacterView(style: .clyde, state: .idle, size: 30)
            }

            Text("Añade tu primer personaje")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))

            Text("Cada fantasma ejecuta el comando que tú elijas, con su log en vivo.")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)

            Button(action: onManage) {
                Text("Abrir Ajustes")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(.white.opacity(0.14)))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.88))

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    static func label(for state: CharacterRunState) -> String {
        switch state {
        case .idle: return "inactivo"
        case .running: return "trabajando"
        case .succeeded: return "listo"
        case .failed(let code): return "error \(code)"
        case .stopped: return "detenido"
        }
    }

    static func statusColor(for state: CharacterRunState) -> Color {
        switch state {
        case .idle: return .white.opacity(0.45)
        case .running: return Color.green.opacity(0.9)
        case .succeeded: return Color.green.opacity(0.75)
        case .failed: return Color.orange.opacity(0.95)
        case .stopped: return .white.opacity(0.55)
        }
    }
}

private struct CharacterCapsuleButton: View {
    let title: String
    let symbol: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 9.5, weight: .medium))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(.white.opacity(0.14)))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(enabled ? 0.85 : 0.3))
        .disabled(!enabled)
    }
}
