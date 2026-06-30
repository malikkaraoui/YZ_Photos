import SwiftUI

/// Onglet « Analyse » unifié : la progression de l'analyse et (en debug) les
/// vérifications/diagnostics partagent le même onglet, via un sélecteur segmenté.
struct AnalyseHubView: View {
    let drive: DriveRecord
    let root: URL

    @Environment(\.yzTheme) private var theme
    @Environment(\.horizontalSizeClass) private var hSize
    #if DEBUG
    @State private var section = 0
    #endif

    var body: some View {
        NavigationStack {
            content
                .yzScreenBackground(theme)
                .navigationTitle("Analyse")
                .navigationBarTitleDisplayMode(.inline)
        }
        .tint(theme.accent)
    }

    @ViewBuilder private var content: some View {
        #if DEBUG
        if hSize == .regular {
            // iPad : Analyse ET Vérifications sur la MÊME page, côte à côte.
            HStack(spacing: 0) {
                analyse
                Divider()
                DriveChecksView(drive: drive, root: root)
            }
        } else {
            // iPhone : un sélecteur segmenté (pas la place pour les deux).
            VStack(spacing: 0) {
                YZSegmented(options: ["Analyse", "Vérifications"], selection: $section)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                if section == 0 {
                    analyse
                } else {
                    DriveChecksView(drive: drive, root: root)
                }
            }
        }
        #else
        analyse
        #endif
    }

    private var analyse: some View {
        ScrollView { ScanDetailView(asSheet: false, drive: drive, root: root) }
            .scrollContentBackground(.hidden)
    }
}
