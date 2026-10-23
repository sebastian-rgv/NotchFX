import AppKit
import SwiftUI

struct CharactersPane: View {
    @ObservedObject var settingsModel: SettingsModel
    @ObservedObject var characters: CharacterSessionController

    @State private var editingProfile: CharacterProfile?

    private var profiles: [CharacterProfile] {
        settingsModel.settings.characters
    }

    var body: some View {
        PaneSection(title: "Tus personajes") {
            if profiles.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(GhostStyle.allCases) { style in
                            GhostCharacterView(style: style, state: .idle, size: 26)
                        }
                    }

                    Text("Todavía no hay personajes.")
                        .font(.system(size: 12, weight: .medium))

                    PaneCaption("Añade un fantasma y asígnale el comando que quieras ejecutar desde el notch.")
                }
            } else {
                ForEach(profiles) { profile in
                    row(for: profile)
                    if profile.id != profiles.last?.id {
                        Divider().opacity(0.3)
                    }
                }
            }

            Button {
                editingProfile = CharacterProfile(name: "", command: "")
            } label: {
                Label("Añadir personaje", systemImage: "plus")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.borderless)

            PaneCaption("Cada personaje corre su comando en una shell de login. Para agentes usa el modo no interactivo: `fx ask \"...\"` o `claude -p \"...\"`. El PATH ya incluye ~/.local/bin (donde instala fx).")
        }
        .sheet(item: $editingProfile) { profile in
            CharacterEditorView(profile: profile) { saved in
                save(saved)
            }
        }
    }

    private func row(for profile: CharacterProfile) -> some View {
        let state = characters.display.snapshots
            .first(where: { $0.id == profile.id })?.state ?? .idle

        return HStack(spacing: 10) {
            GhostCharacterView(style: profile.style, state: state, size: 28)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(profile.name)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)

                    Text(CharactersExpandedContent.label(for: state))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(CharactersExpandedContent.statusColor(for: state))
                }

                Text(profile.command)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)

            Button {
                characters.start(profile)
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 10))
            }
            .buttonStyle(.borderless)
            .disabled(state.isRunning)
            .help("Lanzar en el notch")

            Button {
                editingProfile = profile
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 10))
            }
            .buttonStyle(.borderless)
            .help("Editar")

            Button {
                delete(profile)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10))
            }
            .buttonStyle(.borderless)
            .help("Eliminar")
        }
        .padding(.vertical, 2)
    }

    private func save(_ profile: CharacterProfile) {
        settingsModel.update { settings in
            if let index = settings.characters.firstIndex(where: { $0.id == profile.id }) {
                settings.characters[index] = profile
            } else {
                settings.characters.append(profile)
            }
        }
    }

    private func delete(_ profile: CharacterProfile) {
        characters.stop(profile.id)
        settingsModel.update { settings in
            settings.characters.removeAll { $0.id == profile.id }
        }
        characters.sync(profiles: settingsModel.settings.characters)
    }
}

private struct CharacterEditorView: View {
    @State private var draft: CharacterProfile
    let onSave: (CharacterProfile) -> Void

    @Environment(\.dismiss) private var dismiss

    init(profile: CharacterProfile, onSave: @escaping (CharacterProfile) -> Void) {
        _draft = State(initialValue: profile)
        self.onSave = onSave
    }

    private var canSave: Bool {
        !draft.command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(draft.name.isEmpty ? "Nuevo personaje" : "Editar personaje")
                .font(.system(size: 16, weight: .semibold))

            VStack(alignment: .leading, spacing: 6) {
                Text("Nombre")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("Blinky", text: $draft.name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Fantasma")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(GhostStyle.allCases) { style in
                        Button {
                            draft.style = style
                        } label: {
                            HStack(spacing: 5) {
                                GhostCharacterView(style: style, state: .idle, size: 22)
                                Text(style.displayName)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(.white.opacity(draft.style == style ? 0.16 : 0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(
                                        .white.opacity(draft.style == style ? 0.4 : 0.06),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Comando")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("fx ask \"explica este repositorio\"", text: $draft.command)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))

                HStack(spacing: 6) {
                    Text("Plantillas:")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    templateButton("Vercel fx") {
                        draft.command = "fx ask \"explica los cambios de este repositorio\""
                        if draft.name.isEmpty { draft.name = "Blinky" }
                    }
                    templateButton("Claude") {
                        draft.command = "claude -p \"explica los cambios de este repositorio\""
                        if draft.name.isEmpty { draft.name = "Pinky" }
                    }
                    templateButton("fx.sh") {
                        draft.command = "./Scripts/fx.sh"
                        if draft.name.isEmpty { draft.name = "Clyde" }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Directorio de trabajo")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    TextField(
                        "~/Proyectos/mi-proyecto",
                        text: Binding(
                            get: { draft.workingDirectory ?? "" },
                            set: { draft.workingDirectory = $0.isEmpty ? nil : $0 }
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))

                    Button("Elegir…") {
                        chooseDirectory()
                    }
                }
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()

                Button("Cancelar") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Guardar") {
                    onSave(draft)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
        .padding(20)
        .frame(width: 500, height: 360)
        .preferredColorScheme(.dark)
    }

    private func templateButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.borderless)
            .font(.system(size: 10))
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Elegir"

        if panel.runModal() == .OK, let url = panel.url {
            draft.workingDirectory = url.path
        }
    }
}
