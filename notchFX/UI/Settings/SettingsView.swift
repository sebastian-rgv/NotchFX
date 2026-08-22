import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case island
    case media
    case gestures
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .island: return "Isla"
        case .media: return "Música"
        case .gestures: return "Gestos"
        case .about: return "Acerca de"
        }
    }

    var symbolName: String {
        switch self {
        case .general: return "gearshape.fill"
        case .island: return "rectangle.inset.filled"
        case .media: return "music.note"
        case .gestures: return "hand.draw.fill"
        case .about: return "info.circle.fill"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settingsModel: SettingsModel
    @State private var selectedSection: SettingsSection = .general

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2"
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detailPane
        }
        .frame(width: 620, height: 400)
        .preferredColorScheme(.dark)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SettingsSection.allCases) { section in
                SidebarRow(
                    title: section.title,
                    symbolName: section.symbolName,
                    isSelected: selectedSection == section
                )
                .onTapGesture {
                    selectedSection = section
                }
            }

            Spacer()
        }
        .padding(.top, 12)
        .padding(.horizontal, 8)
        .frame(width: 150)
        .background(Color.black.opacity(0.25))
    }

    @ViewBuilder
    private var detailPane: some View {
        ScrollView {
            Group {
                switch selectedSection {
                case .general:
                    GeneralPane(settingsModel: settingsModel)
                case .island:
                    IslandPane(settingsModel: settingsModel)
                case .media:
                    MediaPane()
                case .gestures:
                    GesturesPane(settingsModel: settingsModel)
                case .about:
                    AboutPane(version: appVersion)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SidebarRow: View {
    let title: String
    let symbolName: String
    let isSelected: Bool

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbolName)
                .font(.system(size: 12))
                .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.75))
                .frame(width: 18)

            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(.white.opacity(isSelected ? 1 : 0.8))

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isSelected
                        ? Color.accentColor.opacity(0.85)
                        : hovering ? Color.white.opacity(0.08) : .clear
                )
        )
        .onHover { hovering = $0 }
        .contentShape(Rectangle())
    }
}
