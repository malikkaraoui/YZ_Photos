import SwiftUI

struct MainTabView: View {
    let drive: DriveRecord
    let root: URL

    @Environment(AppEnvironment.self) private var env
    @State private var selection: TabID = .triage

    enum TabID: Hashable {
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
                // Badge ● : l'analyse du disque tourne.
                Tab("Analyse", systemImage: "waveform.badge.magnifyingglass", value: TabID.scan) {
                    ScanTabView(drive: drive, root: root)
                }
                .badge(env.scan.isRunning ? Text("●") : nil)
                Tab("Stats", systemImage: "chart.bar.xaxis", value: TabID.stats) {
                    StatsDashboardView(drive: drive, root: root)
                }
                Tab("Réglages", systemImage: "gearshape", value: TabID.settings) {
                    SettingsView()
                }
            }
            #if DEBUG
            Tab("Vérifs", systemImage: "checkmark.shield", value: TabID.spike) {
                DriveChecksView(drive: drive, root: root)
            }
            #endif
        }
        // Barre d'onglets flottante compacte : pas de volet latéral qui mange
        // la largeur — tout l'écran 13" pour le contenu.
        .tabViewStyle(.tabBarOnly)
        // En bas : la barre d'onglets iPadOS flotte en haut au centre,
        // la bannière ne doit jamais la chevaucher.
        .overlay(alignment: .bottom) {
            if env.scan.isRunning {
                ScanProgressBanner()
                    .padding(.bottom, 18)
            }
        }
        // Bouton global « Annuler la dernière action » — visible partout
        // dès qu'une décision est annulable.
        .overlay(alignment: .bottomTrailing) {
            if let triage = env.triage, triage.canUndo {
                Button {
                    Task { try? await triage.undo() }
                } label: {
                    Label("Annuler la dernière action", systemImage: "arrow.uturn.backward")
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(.orange.opacity(0.6), lineWidth: 1.5))
                }
                .padding(.trailing, 18)
                .padding(.bottom, 18)
            }
        }
    }
}
