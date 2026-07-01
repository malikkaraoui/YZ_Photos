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
    @Environment(\.yzTheme) private var theme
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
        .scrollContentBackground(.hidden)
        .yzScreenBackground(theme)
        .tint(theme.accent)
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
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Fmt.count(totalCount)) fichiers · \(Fmt.bytes(totalBytes))")
                        .font(YZFont.headline)
                        .foregroundStyle(theme.t1)
                    Text(totalUntriaged == 0
                         ? "Tout est trié ✓"
                         : "\(Fmt.count(totalUntriaged)) à trier")
                        .font(YZFont.subhead)
                        .foregroundStyle(totalUntriaged == 0 ? theme.keep : theme.t2)
                }
                // Boutons en ligne SOUS les stats : tient sur iPhone comme iPad
                // (avant, dans une seule HStack, « Trier ce dossier » se cassait
                //  caractère par caractère faute de place).
                HStack(spacing: 12) {
                    NavigationLink(value: FolderGridRef(prefix: prefix, title: displayTitle)) {
                        Label("Voir", systemImage: "square.grid.2x2").lineLimit(1)
                    }
                    .buttonStyle(YZButtonStyle(.secondary))
                    Button {
                        showDeck = true
                    } label: {
                        Label("Trier ce dossier", systemImage: "rectangle.stack")
                            .lineLimit(1).minimumScaleFactor(0.85)
                    }
                    .buttonStyle(YZButtonStyle(.primary, fullWidth: true))
                    .disabled(totalUntriaged == 0)
                }
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
                            iconColor: entry.isPhotosLibrary ? Color(hex: 0x9B6DFF) : theme.accent
                        )
                    }
                } else {
                    folderRow(entry, icon: "photo.on.rectangle", iconColor: theme.t3)
                }
            }
        } header: {
            if !entries.isEmpty {
                Text("Contenu")
                    .foregroundStyle(theme.t2)
            }
        }
    }

    private func folderRow(_ entry: FolderEntry, icon: String, iconColor: Color) -> some View {
        HStack(spacing: 14) {
            folderIcon(entry, icon: icon, iconColor: iconColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.name.map {
                    $0.hasSuffix(".photoslibrary")
                        ? $0.replacingOccurrences(of: ".photoslibrary", with: "")
                        : $0
                } ?? "Fichiers à ce niveau")
                    .font(YZFont.headline)
                    .foregroundStyle(theme.t1)
                    .lineLimit(1)
                Text("\(Fmt.count(entry.count)) fichiers · \(Fmt.bytes(entry.bytes))")
                    .font(YZFont.subhead)
                    .foregroundStyle(theme.t2)
            }
            Spacer()
            if entry.untriagedCount > 0 {
                YZBadge("\(Fmt.count(entry.untriagedCount)) à trier", tone: .accent)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(theme.keep)
            }
        }
        .padding(.vertical, 2)
    }

    /// Pastille d'icône à gauche d'une entrée. Trois cas :
    /// - photothèque Apple (.photoslibrary) → rosace multicolore type app « Photos » ;
    /// - vrai dossier → pastille BLEUE avec icône dossier (lisible dans tous les thèmes ;
    ///   avant on utilisait `theme.accent`, qui est BLANC en thème Verre → carré blanc) ;
    /// - « Fichiers à ce niveau » → icône photo sur la couleur passée.
    @ViewBuilder
    private func folderIcon(_ entry: FolderEntry, icon: String, iconColor: Color) -> some View {
        if entry.isPhotosLibrary {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(AngularGradient(
                    gradient: Gradient(colors: [
                        Color(hex: 0xF9CE34), Color(hex: 0xF15B5B), Color(hex: 0xEE2A7B),
                        Color(hex: 0x6228D7), Color(hex: 0x3B82F6), Color(hex: 0x22C55E),
                        Color(hex: 0xF9CE34)
                    ]),
                    center: .center))
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .blackA(0.35), radius: 1, y: 0.5)
                }
        } else if entry.name != nil {
            Image(systemName: "folder.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(
                    LinearGradient(colors: [Color(hex: 0x54A8FF), Color(hex: 0x2C7BE5)],
                                   startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        } else {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(iconColor.opacity(0.9), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
    }

    private func reload() async {
        let driveId = drive.id
        let prefix = self.prefix
        entries = (try? await env.database.writer.read { db in
            try Queries.folderEntries(db, driveId: driveId, prefix: prefix)
        }) ?? []
    }
}
