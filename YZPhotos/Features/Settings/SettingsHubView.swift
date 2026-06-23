import SwiftUI

/// Onglet unifié : les Réglages et les Statistiques partagent le même onglet,
/// via un sélecteur segmenté en haut.
struct SettingsHubView: View {
    let drive: DriveRecord
    let root: URL

    @Environment(\.yzTheme) private var theme
    @State private var section = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                YZSegmented(options: ["Réglages", "Statistiques"], selection: $section)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                if section == 0 {
                    SettingsView()
                } else {
                    StatsDashboardView(drive: drive, root: root)
                }
            }
            .yzScreenBackground(theme)
            .navigationTitle(section == 0 ? "Réglages" : "Statistiques")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(theme.accent)
    }
}
