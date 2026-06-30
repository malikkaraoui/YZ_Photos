import SwiftUI

/// Onglet unifié : les Réglages et les Statistiques partagent le même onglet,
/// via un sélecteur segmenté en haut.
struct SettingsHubView: View {
    let drive: DriveRecord
    let root: URL

    @Environment(\.yzTheme) private var theme
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var section = 0

    var body: some View {
        NavigationStack {
            content
                .yzScreenBackground(theme)
                .navigationTitle(hSize == .regular ? "Réglages & statistiques" : (section == 0 ? "Réglages" : "Statistiques"))
                .navigationBarTitleDisplayMode(.inline)
        }
        .tint(theme.accent)
    }

    @ViewBuilder private var content: some View {
        if hSize == .regular {
            // iPad : Réglages ET Statistiques sur la MÊME page, côte à côte → chaque
            // moitié est deux fois moins large (les sections ne s'étalent plus).
            HStack(spacing: 0) {
                SettingsView()
                Divider()
                StatsDashboardView(drive: drive, root: root)
            }
        } else {
            // iPhone : un sélecteur segmenté (pas la place pour les deux).
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
        }
    }
}
