import StoreKit
import SwiftUI

struct MainTabView: View {
    let drive: DriveRecord
    let root: URL

    @Environment(AppEnvironment.self) private var env
    @Environment(\.yzTheme) private var theme
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.requestReview) private var requestReview
    // @SceneStorage (et pas @State) : la sélection d'onglet SURVIT aux
    // reconstructions de vue. Sans ça, redimensionner la fenêtre iPad (Split View
    // → plein écran) changeait la size class, reconstruisait le TabView et
    // remettait l'onglet sur « Trier » (surtout que « Doublons » est dans le
    // débordement « Autre » des >5 onglets). Bonus : l'onglet est aussi restauré
    // au prochain lancement.
    @SceneStorage("yz.selectedTab") private var selection: TabID = .triage

    enum TabID: String, Hashable {
        case triage, folders, photos, videos, duplicates, screenshots, bySize, trash, scan, stats, settings, spike
    }

    var body: some View {
        TabView(selection: $selection) {
            Group {
                Tab("Trier", systemImage: "rectangle.stack", value: TabID.triage) {
                    TriageDeckView(drive: drive, root: root, filter: .all)
                }
                Tab("Dossiers", systemImage: "folder", value: TabID.folders) {
                    FolderBrowserView(drive: drive, root: root)
                }
            }
            Tab("Photos", systemImage: "photo", value: TabID.photos) {
                MediaGridScreen(drive: drive, root: root, filter: .photos)
            }
            Tab("Vidéos", systemImage: "video", value: TabID.videos) {
                MediaGridScreen(drive: drive, root: root, filter: .videos)
            }
            // Badge ● : une recherche de doublons tourne (⏸ = en pause).
            Tab("Doublons", systemImage: "square.on.square", value: TabID.duplicates) {
                DuplicateGroupsView(drive: drive, root: root)
            }
            .badge(env.duplicates.isRunning ? Text(env.duplicates.isPaused ? "⏸" : "●") : nil)
            Tab("Captures", systemImage: "camera.viewfinder", value: TabID.screenshots) {
                MediaGridScreen(drive: drive, root: root, filter: .screenshots)
            }
            Tab("Par taille", systemImage: "arrow.up.arrow.down", value: TabID.bySize) {
                MediaGridScreen(drive: drive, root: root, filter: .bySize)
            }
            Tab("Corbeille", systemImage: "trash", value: TabID.trash) {
                TrashView(drive: drive, root: root)
            }
            Group {
                // Badge ● : l'analyse du disque tourne. Regroupe analyse +
                // vérifications/diagnostics (debug) sous le même onglet.
                Tab("Analyse", systemImage: "waveform.badge.magnifyingglass", value: TabID.scan) {
                    AnalyseHubView(drive: drive, root: root)
                }
                .badge(env.scan.isRunning ? Text("●") : nil)
                // Réglages + Statistiques regroupés sous le même onglet.
                Tab("Réglages", systemImage: "gearshape", value: TabID.settings) {
                    SettingsHubView(drive: drive, root: root)
                }
            }
        }
        // Barre d'onglets flottante compacte : pas de volet latéral qui mange
        // la largeur — tout l'écran 13" pour le contenu.
        .tabViewStyle(.tabBarOnly)
        // En bas À DROITE : les boutons de tri (poubelle / retour / garder) sont
        // centrés en bas — la pastille doit rester dans le coin pour ne JAMAIS
        // les chevaucher. (Bottom-center la posait pile par-dessus.)
        .overlay(alignment: .bottomTrailing) {
            // Bandeau flottant : seulement sur iPad (écran large), et JAMAIS sur
            // l'onglet Analyse (la progression y est déjà détaillée → doublon).
            if env.scan.isRunning, hSize == .regular, selection != .scan {
                ScanProgressBanner()
                    .padding(.trailing, 22)
                    .padding(.bottom, 22)
            }
        }
        // (Le bouton « Annuler » flottant global a été retiré : il chevauchait les
        // boutons d'action du volet d'aperçu. L'annulation est désormais dans le
        // deck (contrôles) et dans le volet d'aperçu — chacun bien placé.)
        .task {
            // Usage réel (disque branché) → routine d'évaluation (plafonnée Apple).
            ReviewPrompter.registerUseAndMaybePrompt(requestReview)
        }
    }
}
