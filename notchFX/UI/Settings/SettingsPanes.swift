import SwiftUI

struct GeneralPane: View {
    @ObservedObject var settingsModel: SettingsModel

    var body: some View {
        PaneSection(title: "Pantalla") {
            Picker("Pantalla activa", selection: displayModeBinding) {
                Text("Automática").tag(NotchSettings.DisplayMode.auto)
                Text("Con muesca").tag(NotchSettings.DisplayMode.notchedScreen)
                Text("Principal").tag(NotchSettings.DisplayMode.mainScreen)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            PaneCaption("La isla vive sobre la muesca; si tu Mac no tiene, flota bajo la barra de menú.")
        }

        PaneSection(title: "Alertas del sistema") {
            HStack(spacing: 12) {
                Text("Duración en pantalla")
                Slider(value: alertDurationBinding, in: 2...15, step: 1)
                Text("\(Int(settingsModel.settings.alertDuration)) s")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 34, alignment: .trailing)
            }
        }
    }

    private var displayModeBinding: Binding<NotchSettings.DisplayMode> {
        Binding(
            get: { settingsModel.settings.displayMode },
            set: { newValue in settingsModel.update { $0.displayMode = newValue } }
        )
    }

    private var alertDurationBinding: Binding<Double> {
        Binding(
            get: { settingsModel.settings.alertDuration },
            set: { newValue in settingsModel.update { $0.alertDuration = newValue } }
        )
    }
}

struct IslandPane: View {
    @ObservedObject var settingsModel: SettingsModel

    private var islandWidthBinding: Binding<Double> {
        Binding(
            get: { settingsModel.settings.islandWidth },
            set: { newValue in settingsModel.update { $0.islandWidth = newValue } }
        )
    }

    private var islandHeightBinding: Binding<Double> {
        Binding(
            get: { settingsModel.settings.islandHeight },
            set: { newValue in settingsModel.update { $0.islandHeight = newValue } }
        )
    }

    var body: some View {
        PaneSection(title: "Tamaño de la isla") {
            VStack(spacing: 14) {
                NotchProportionsPreview(
                    width: settingsModel.settings.islandWidth,
                    height: settingsModel.settings.islandHeight
                )
                .frame(height: 70)
                .frame(maxWidth: .infinity)

                HStack(spacing: 12) {
                    Text("Ancho")
                        .frame(width: 52, alignment: .leading)
                    Slider(value: islandWidthBinding, in: 260...396, step: 4)
                    Text("\(Int(settingsModel.settings.islandWidth))")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 34, alignment: .trailing)
                }

                HStack(spacing: 12) {
                    Text("Alto")
                        .frame(width: 52, alignment: .leading)
                    Slider(value: islandHeightBinding, in: 38...72, step: 2)
                    Text("\(Int(settingsModel.settings.islandHeight))")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 34, alignment: .trailing)
                }

                PaneCaption("El contenido vive a los lados de la muesca. Sube el ancho hasta que ambos hombros queden fuera de ella y el alto hasta fusionar con el hardware.")
            }
        }

        PaneSection(title: "Estilo") {
            Toggle(isOn: capsuleBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cápsula flotante")
                    PaneCaption("Isla redondeada independiente, incluso con muesca.")
                }
            }
        }
    }

    private var capsuleBinding: Binding<Bool> {
        Binding(
            get: { settingsModel.settings.surfaceStyle == .capsule },
            set: { isOn in settingsModel.update { $0.surfaceStyle = isOn ? .capsule : .notch } }
        )
    }
}

struct MediaPane: View {
    var body: some View {
        PaneSection(title: "Detección de música") {
            LabeledContent("Motor", value: "MediaRemoteAdapter")

            PaneCaption("Lee cualquier reproductor del sistema en tiempo real sin permisos adicionales: Spotify, Música, navegador y más.")

            LabeledContent("Controles soportados", value: "Play · Pausa · Siguiente · Anterior · Seek")

            PaneCaption("Próximamente: artwork del álbum dentro de la isla.")
        }
    }
}

struct GesturesPane: View {
    @ObservedObject var settingsModel: SettingsModel

    var body: some View {
        PaneSection(title: "Gestos") {
            Toggle(isOn: swipeDismissBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Deslizar para descartar")
                    PaneCaption("Arrastra la isla hacia abajo para cerrar la actividad actual.")
                }
            }

            LabeledContent("Click", value: "Expandir / colapsar")
            LabeledContent("Hover", value: "Las esquinas reaccionan")
            LabeledContent("Click fuera", value: "Colapsa la isla")
        }
    }

    private var swipeDismissBinding: Binding<Bool> {
        Binding(
            get: { settingsModel.settings.swipeDismissEnabled },
            set: { isOn in settingsModel.update { $0.swipeDismissEnabled = isOn } }
        )
    }
}

struct AboutPane: View {
    let version: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(systemName: "rectangle.inset.filled")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 4) {
                    Text("notchFX")
                        .font(.title2.bold())
                    Text("Versión \(version)")
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Text("Bring your notch to life.")
                .font(.system(size: 13, weight: .medium))

            Text("Isla dinámica nativa para macOS. Ligera, privada, sin telemetría ni conexión a servidores.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 380, alignment: .leading)
        }
    }
}
