import SwiftUI

/// Référence de navigation vers un niveau de l'arborescence.
struct FolderRef: Hashable {
    var prefix: String
    var title: String
}

/// Référence de navigation vers la grille d'un dossier.
struct FolderGridRef: Hashable {
    var prefix: String
    var title: String
}

/// Onglet Dossiers : naviguer dans l'arborescence du disque (dossiers exportés
/// et bibliothèques .photoslibrary), puis trier ou visualiser un dossier précis.
struct FolderBrowserView: View {
    let drive: DriveRecord
    let root: URL

    var body: some View {
        NavigationStack {
            FolderLevelView(drive: drive, root: root, prefix: "", title: drive.name)
                .navigationDestination(for: FolderRef.self) { ref in
                    FolderLevelView(drive: drive, root: root, prefix: ref.prefix, title: ref.title)
                }
                .navigationDestination(for: FolderGridRef.self) { ref in
                    // embedded : la grille est poussée dans CE stack — elle ne
                    // doit pas créer le sien (stack imbriqué = navigation figée).
                    MediaGridScreen(
                        drive: drive, root: root, filter: .all,
                        scope: ref.prefix.isEmpty ? nil : ref.prefix,
                        scopeTitle: ref.title,
                        embedded: true
                    )
                }
        }
    }
}

/// Un niveau de l'arborescence : stats du dossier courant + actions + sous-dossiers.
struct FolderLevelView: View {
    let drive: DriveRecord
    let root: URL
    /// Chemin du dossier courant relatif à la racine ("" = racine).
    let prefix: String
    let title: String

    @Environment(AppEnvironment.self) private var env
    @State private var entries: [FolderEntry] = []
    @State private var showDeck = false

    private var isPhotosLibrary: Bool {
        title.lowercased().hasSuffix(".photoslibrary")
    }

    private var totalCount: Int { entries.reduce(0) { $0 + $1.count } }
    private var totalBytes: Int64 { entries.reduce(0) { $0 + $1.bytes } }
    private var totalUntriaged: Int { entries.reduce(0) { $0 + $1.untriagedCount } }

    var body: some View {
        List {
            actionSection
            // Dans une bibliothèque Photos, l'arborescence interne (originals/0…F)
            // n'a aucun sens pour l'utilisateur : on n'affiche que les actions.
            if !isPhotosLibrary {
                folderSection
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(displayTitle)
        .navigationBarTitleDisplayMode(.large)
        .task(id: prefix) { await reload() }
        .refreshable { await reload() }
        .onChange(of: env.scan.phase) { _, newPhase in
            if newPhase == .analyzing || newPhase == .finished {
                Task { await reload() }
            }
        }
        .onChange(of: env.triage?.changeTick) { _, _ in
            Task { await reload() }
        }
        .fullScreenCover(isPresented: $showDeck, onDismiss: {
            Task { await reload() }
        }) {
            TriageDeckView(
                drive: drive, root: root, filter: .all,
                scope: prefix.isEmpty ? nil : prefix,
                scopeTitle: displayTitle, isModal: true
            )
            .environment(env)
        }
    }

    private var displayTitle: String {
        isPhotosLibrary
            ? title.replacingOccurrences(of: ".photoslibrary", with: "")
            : title
    }

    private var actionSection: some View {
        Section {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Fmt.count(totalCount)) fichiers · \(Fmt.bytes(totalBytes))")
                        .font(.headline)
                    Text(totalUntriaged == 0
                         ? "Tout est trié ✓"
                         : "\(Fmt.count(totalUntriaged)) à trier")
                        .font(.subheadline)
                        .foregroundStyle(totalUntriaged == 0 ? .green : .secondary)
                }
                Spacer()
                NavigationLink(value: FolderGridRef(prefix: prefix, title: displayTitle)) {
                    Label("Voir", systemImage: "square.grid.2x2")
                }
                .buttonStyle(.bordered)
                Button {
                    showDeck = true
                } label: {
                    Label("Trier ce dossier", systemImage: "rectangle.stack")
                        .bold()
                }
                .buttonStyle(.borderedProminent)
                .disabled(totalUntriaged == 0)
            }
            .padding(.vertical, 4)
        }
    }

    private var folderSection: some View {
        Section {
            ForEach(entries) { entry in
                if let name = entry.name {
                    NavigationLink(value: FolderRef(
                        prefix: prefix.isEmpty ? name : prefix + "/" + name,
                        title: name
                    )) {
                        folderRow(
                            entry,
                            icon: entry.isPhotosLibrary ? "books.vertical.fill" : "folder.fill",
                            iconColor: entry.isPhotosLibrary ? .purple : .blue
                        )
                    }
                } else {
                    folderRow(entry, icon: "photo.on.rectangle", iconColor: .gray)
                }
            }
        } header: {
            if !entries.isEmpty {
                Text("Contenu")
            }
        }
    }

    private func folderRow(_ entry: FolderEntry, icon: String, iconColor: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name.map {
                    $0.hasSuffix(".photoslibrary")
                        ? $0.replacingOccurrences(of: ".photoslibrary", with: "")
                        : $0
                } ?? "Fichiers à ce niveau")
                    .font(.headline)
                    .lineLimit(1)
                Text("\(Fmt.count(entry.count)) fichiers · \(Fmt.bytes(entry.bytes))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if entry.untriagedCount > 0 {
                Text("\(Fmt.count(entry.untriagedCount)) à trier")
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.blue, in: Capsule())
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 2)
    }

    private func reload() async {
        let driveId = drive.id
        let prefix = self.prefix
        entries = (try? await env.database.writer.read { db in
            try Queries.folderEntries(db, driveId: driveId, prefix: prefix)
        }) ?? []
    }
}
