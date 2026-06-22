import SwiftUI

/// Écran-grille générique : Photos, Vidéos, Captures, Par taille.
struct MediaGridScreen: View {
    let drive: DriveRecord
    let root: URL
    let filter: TriageFilter
    /// Restreint la grille à un dossier (nil = tout le disque).
    var scope: String?
    var scopeTitle: String?
    /// true quand la grille est poussée dans une navigation existante
    /// (onglet Dossiers) : elle ne doit alors PAS créer son propre
    /// NavigationStack — un stack dans un stack fige la navigation.
    var embedded = false

    @Environment(AppEnvironment.self) private var env
    @Environment(\.yzTheme) private var theme
    @State private var vm: LibraryViewModel?
    @State private var selectedFile: FileRecord?
    @State private var showDeck = false
    /// Pinch : taille des vignettes (dézoomer = vue globale, zoomer = détail).
    @State private var cellSize: CGFloat = 150
    @State private var baseCellSize: CGFloat = 150
    /// Appui long sur une vignette → mode sélection multiple (comme Photos iOS).
    @State private var selectionMode = false
    @State private var selection = Set<Int64>()
    @State private var confirmBulkTrash = false
    @State private var isWorking = false

    var body: some View {
        Group {
            if embedded {
                inner
            } else {
                NavigationStack { inner }
            }
        }
        .task(id: drive.id) {
            if vm == nil {
                vm = LibraryViewModel(
                    database: env.database, driveId: drive.id, filter: filter, scope: scope,
                    defaultOrder: env.settings.defaultGridOrder
                )
            }
            await vm?.reload()
        }
        .onChange(of: env.scan.phase) { _, newPhase in
            if newPhase == .analyzing || newPhase == .finished {
                Task { await vm?.reload() }
            }
        }
        .onChange(of: env.triage?.changeTick) { _, _ in
            // Pendant une opération par lot (poubelle/garder multi-sélection),
            // chaque fichier incrémente changeTick : on NE recharge PAS à chaque
            // fois (tempête de rechargements → saturation). Le rechargement final
            // est fait explicitement à la fin du lot. Sinon (action unitaire), on
            // recharge normalement.
            if !isWorking { Task { await vm?.reload() } }
        }
        .onChange(of: env.libraryReloadTick) { _, _ in
            Task { await vm?.reload() }
        }
        .fullScreenCover(isPresented: $showDeck, onDismiss: {
            Task { await vm?.reload() }
        }) {
            TriageDeckView(drive: drive, root: root, filter: filter, scope: scope, scopeTitle: scopeTitle, isModal: true)
                .environment(env)
        }
    }

    private var inner: some View {
            Group {
                if let vm {
                    MasterDetailLayout(
                        selectedFile: $selectedFile,
                        root: root,
                        onAction: { advanceAfterAction(vm) },
                        selectionSummary: selectionMode && !selection.isEmpty
                            ? SelectionSummary(files: selectedFiles)
                            : nil
                    ) {
                        grid(vm)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(selectionMode ? "\(selection.count) sélectionnés" : (scopeTitle ?? filter.title))
            .toolbar {
                if selectionMode {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annuler") { exitSelection() }
                    }
                    ToolbarItem(placement: .secondaryAction) {
                        Button("Tout sélectionner") {
                            selection = Set((vm?.files ?? []).compactMap(\.id))
                        }
                    }
                    ToolbarItem(placement: .secondaryAction) {
                        Button("Tout désélectionner") {
                            selection.removeAll()
                        }
                        .disabled(selection.isEmpty)
                    }
                    // Croix directe : vide la sélection sans passer par le menu « … ».
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            selection.removeAll()
                        } label: {
                            Label("Désélectionner", systemImage: "xmark.circle.fill")
                        }
                        .disabled(selection.isEmpty)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            keepSelection()
                        } label: {
                            Label("Garder (\(selection.count))", systemImage: "checkmark")
                        }
                        .tint(theme.keep)
                        .disabled(selection.isEmpty || isWorking)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button(role: .destructive) {
                            confirmBulkTrash = true
                        } label: {
                            Label("Poubelle (\(selection.count) · \(Fmt.bytes(selectedBytes)))", systemImage: "trash.fill")
                        }
                        .disabled(selection.isEmpty || isWorking)
                    }
                } else {
                    ToolbarItem(placement: .secondaryAction) {
                        Menu {
                            Picker("Ranger par", selection: .init(
                                get: { vm?.order ?? .byFolder },
                                set: { newOrder in
                                    vm?.order = newOrder
                                    Task { await vm?.reload() }
                                }
                            )) {
                                ForEach(GridOrder.allCases) { order in
                                    Label(order.rawValue, systemImage: order.icon)
                                        .tag(order)
                                }
                            }
                        } label: {
                            Label("Ranger", systemImage: "arrow.up.arrow.down")
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showDeck = true
                        } label: {
                            Label("Trier ces fichiers", systemImage: "rectangle.stack")
                        }
                    }
                }
            }
            .confirmationDialog(
                "Mettre \(selection.count) fichiers à la poubelle (\(Fmt.bytes(selectedBytes))) ? Rien n'est supprimé tant que la corbeille n'est pas vidée.",
                isPresented: $confirmBulkTrash,
                titleVisibility: .visible
            ) {
                Button("Mettre à la poubelle", role: .destructive) { trashSelection() }
                Button("Annuler", role: .cancel) {}
            }
    }

    @ViewBuilder
    private func grid(_ vm: LibraryViewModel) -> some View {
        if vm.files.isEmpty {
            YZEmptyState(
                systemImage: "photo.on.rectangle",
                title: "Rien ici",
                message: env.scan.isRunning
                    ? "L'analyse est en cours, les fichiers apparaissent au fur et à mesure."
                    : "Aucun fichier ne correspond à ce filtre."
            )
            .yzScreenBackground(theme)
        } else {
            ScrollView {
                HStack {
                    Text("\(Fmt.count(vm.totalCount)) fichiers · \(Fmt.bytes(vm.totalBytes))")
                        .font(YZFont.subheadSemi)
                        .foregroundStyle(theme.t2)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 6)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: cellSize), spacing: 6)],
                    spacing: 6
                ) {
                    ForEach(Array(vm.files.enumerated()), id: \.element.id) { index, file in
                        gridCell(
                            file,
                            joinsPrevious: sameGroup(file, vm.files[safe: index - 1]),
                            joinsNext: sameGroup(file, vm.files[safe: index + 1])
                        )
                        .onAppear {
                            Task { await vm.loadMoreIfNeeded(current: file) }
                            // Précharge en avance les miniatures des cellules
                            // suivantes (arrière-plan) → défilement fluide.
                            let upcoming = Array(vm.files[min(index + 1, vm.files.count)..<min(index + 13, vm.files.count)])
                            env.thumbnails.prefetch(upcoming, store: env.currentStore ?? LocalMediaStore(root: root))
                        }
                    }
                }
                .padding(.horizontal, 6)
            }
            .scrollContentBackground(.hidden)
            .yzScreenBackground(theme)
            .refreshable { await vm.reload() }
            // Pinch comme l'app Photos : écarter = vignettes plus grandes,
            // pincer = plus de photos à l'écran.
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        cellSize = min(max(baseCellSize * value.magnification, 80), 400)
                    }
                    .onEnded { _ in
                        baseCellSize = cellSize
                    }
            )
        }
    }
}

/// Cellule de grille : miniature carrée + badges.
struct ThumbnailCell: View {
    let file: FileRecord
    let root: URL
    var showSize = false
    /// Liaison visuelle des doublons adjacents : le calque coloré du groupe
    /// déborde dans l'espacement et rejoint la vignette voisine.
    var joinsPrevious = false
    var joinsNext = false

    @Environment(AppEnvironment.self) private var env
    @Environment(\.yzTheme) private var theme
    @State private var image: UIImage?

    var body: some View {
        // La couleur de fond dicte la taille de la cellule ; l'image vit en
        // overlay et ne peut pas faire déborder la grille (portrait/paysage).
        theme.bg3
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: file.kind == .video ? "video" : "photo")
                        .font(.title)
                        .foregroundStyle(theme.t3)
                }
            }
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: YZRadius.chip, style: .continuous))
        // Doublons « joints par un calque » : même groupe = même couleur.
        // Voile teinté + cadre épais, et quand deux membres du groupe sont
        // côte à côte (tri par taille), des ponts colorés les relient
        // physiquement — un seul bloc visuel, impossible à rater.
        .overlay {
            if let groupId = file.dupGroupId {
                let color = Self.duplicateColor(groupId)
                ZStack {
                    Rectangle().fill(color.opacity(0.22))
                    Rectangle().strokeBorder(color, lineWidth: 4)
                }
            }
        }
        .overlay(alignment: .leading) {
            if let groupId = file.dupGroupId, joinsPrevious {
                Rectangle()
                    .fill(Self.duplicateColor(groupId))
                    .frame(width: 10, height: 44)
                    .offset(x: -8)
            }
        }
        .overlay(alignment: .trailing) {
            if let groupId = file.dupGroupId, joinsNext {
                Rectangle()
                    .fill(Self.duplicateColor(groupId))
                    .frame(width: 10, height: 44)
                    .offset(x: 8)
            }
        }
        .overlay(alignment: .topLeading) {
            if let groupId = file.dupGroupId {
                Image(systemName: "square.on.square")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(4)
                    .background(Self.duplicateColor(groupId), in: Circle())
                    .padding(4)
            }
        }
        .overlay(alignment: .bottomLeading) {
            HStack(spacing: 4) {
                if let duration = file.durationSeconds {
                    cellBadge(Fmt.duration(duration))
                }
                // Les vidéos affichent toujours leur poids (Mo/Go).
                if showSize || file.kind == .video {
                    cellBadge(Fmt.bytes(file.sizeBytes))
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if file.status == .kept {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(theme.keep)
                    .padding(5)
            }
        }
        .contentShape(Rectangle())
        .task(id: file.id) {
            guard image == nil else { return }
            let store = env.currentStore ?? LocalMediaStore(root: root)
            // Vidéos : la génération peut être différée (mémoire) ou lente (lecture
            // SMB) → on réessaie quelques fois, sinon la cellule resterait en icône.
            let attempts = file.kind == .video ? 5 : 1
            for attempt in 0..<attempts {
                if Task.isCancelled { return }
                if let img = await env.thumbnails.thumbnail(for: file, store: store) {
                    image = img
                    return
                }
                if attempt < attempts - 1 {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                }
            }
        }
    }

    /// Couleur stable par groupe de doublons (palette cyclique).
    static func duplicateColor(_ groupId: Int64) -> Color {
        let palette: [Color] = [.orange, .pink, .cyan, .yellow, .mint, .indigo, .red, .teal]
        return palette[Int(abs(groupId)) % palette.count]
    }

    private func cellBadge(_ text: String) -> some View {
        Text(text)
            .font(YZFont.captionSemi.monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.blackA(0.6), in: Capsule())
            .padding(5)
    }
}

extension Array {
    /// Accès sans crash hors bornes (voisin de grille inexistant → nil).
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Sélection multiple (appui long, comme Photos iOS)

extension MediaGridScreen {
    /// Vrai si les deux fichiers appartiennent au même groupe de doublons.
    fileprivate func sameGroup(_ a: FileRecord, _ b: FileRecord?) -> Bool {
        guard let groupA = a.dupGroupId, let groupB = b?.dupGroupId else { return false }
        return groupA == groupB
    }

    @ViewBuilder
    fileprivate func gridCell(_ file: FileRecord, joinsPrevious: Bool = false, joinsNext: Bool = false) -> some View {
        let isSelected = file.id.map { selection.contains($0) } ?? false
        ThumbnailCell(
            file: file, root: root, showSize: filter == .bySize,
            joinsPrevious: joinsPrevious, joinsNext: joinsNext
        )
            .overlay {
                if selectionMode && isSelected {
                    RoundedRectangle(cornerRadius: YZRadius.chip, style: .continuous)
                        .strokeBorder(theme.accent, lineWidth: 2.5)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if selectionMode {
                    Image(systemName: isSelected ? "checkmark" : "circle")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(isSelected ? theme.accent : Color.blackA(0.3), in: Circle())
                        .overlay { Circle().strokeBorder(.white, lineWidth: 2) }
                        .padding(6)
                }
            }
            .onTapGesture {
                if selectionMode {
                    toggleSelection(file)
                } else {
                    selectedFile = file
                }
            }
            .onLongPressGesture {
                if !selectionMode {
                    selectionMode = true
                    if let id = file.id { selection.insert(id) }
                }
            }
    }

    fileprivate var selectedFiles: [FileRecord] {
        (vm?.files ?? []).filter { file in
            file.id.map { selection.contains($0) } ?? false
        }
    }

    fileprivate var selectedBytes: Int64 {
        selectedFiles.reduce(0) { $0 + $1.sizeBytes }
    }

    fileprivate func toggleSelection(_ file: FileRecord) {
        guard let id = file.id else { return }
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }

    fileprivate func exitSelection() {
        selectionMode = false
        selection.removeAll()
    }

    /// Après une décision dans l'aperçu (poubelle/garder, bouton ou swipe) :
    /// recharge la grille puis **enchaîne toujours sur la photo suivante** encore
    /// présente (comme le deck), sinon la précédente, sinon rien (volet vide).
    private func advanceAfterAction(_ vm: LibraryViewModel) {
        Task {
            let priorId = selectedFile?.id
            let priorFiles = vm.files
            await vm.reload()
            guard let priorId, let idx = priorFiles.firstIndex(where: { $0.id == priorId }) else { return }
            // Suivants d'abord, puis les précédents (à rebours) ; on saute le
            // fichier traité lui-même (qui peut encore être là après « garder »).
            let ordered = Array(priorFiles[(idx + 1)...]) + Array(priorFiles[..<idx].reversed())
            selectedFile = ordered.first { f in f.id != priorId && vm.files.contains(where: { $0.id == f.id }) }
        }
    }

    fileprivate func trashSelection() {
        guard let triage = env.triage else { return }
        let files = selectedFiles
        isWorking = true
        Task {
            try? await triage.trashAll(files)
            exitSelection()
            await vm?.reload()
            isWorking = false
        }
    }

    fileprivate func keepSelection() {
        guard let triage = env.triage else { return }
        let files = selectedFiles
        isWorking = true
        Task {
            try? await triage.keepAll(files)
            exitSelection()
            await vm?.reload()
            isWorking = false
        }
    }
}
