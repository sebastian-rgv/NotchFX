import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsModel: SettingsModel

    private var appVersion: String {
        let short = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String
        return short ?? "0.1.1"
    }

    var body: some View {
        Form {
            Section("Pantalla") {
                Picker("Pantalla activa", selection: displayModeBinding) {
                    Text("Automática").tag(NotchSettings.DisplayMode.auto)
                    Text("Con muesca").tag(NotchSettings.DisplayMode.notchedScreen)
                    Text("Principal").tag(NotchSettings.DisplayMode.mainScreen)
                }
                .pickerStyle(.segmented)

                Toggle(isOn: capsuleBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cápsula flotante")
                        Text("Isla redondeada independiente bajo la barra de menú, incluso con muesca.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Gestos") {
                Toggle(isOn: swipeDismissBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Deslizar para descartar")
                        Text("Arrastra la isla hacia abajo para cerrar la actividad actual.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Alertas") {
                HStack(spacing: 12) {
                    Text("Duración")
                    Slider(value: alertDurationBinding, in: 2...15, step: 1)
                    Text("\(Int(settingsModel.settings.alertDuration)) s")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 38, alignment: .trailing)
                }
            }

            Section("Acerca de") {
                LabeledContent("notchFX", value: "v\(appVersion)")
                Text("Bring your notch to life. Isla dinámica nativa para tu MacBook, ligera y privada.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .preferredColorScheme(.dark)
    }

    private var displayModeBinding: Binding<NotchSettings.DisplayMode> {
        Binding(
            get: { settingsModel.settings.displayMode },
            set: { newValue in settingsModel.update { $0.displayMode = newValue } }
        )
    }

    private var capsuleBinding: Binding<Bool> {
        Binding(
            get: { settingsModel.settings.surfaceStyle == .capsule },
            set: { isOn in
                settingsModel.update { $0.surfaceStyle = isOn ? .capsule : .notch }
            }
        )
    }

    private var swipeDismissBinding: Binding<Bool> {
        Binding(
            get: { settingsModel.settings.swipeDismissEnabled },
            set: { isOn in settingsModel.update { $0.swipeDismissEnabled = isOn } }
        )
    }

    private var alertDurationBinding: Binding<Double> {
        Binding(
            get: { settingsModel.settings.alertDuration },
            set: { newValue in settingsModel.update { $0.alertDuration = newValue } }
        )
    }
}
