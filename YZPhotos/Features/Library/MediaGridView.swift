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
    /// Indicateur de défilement (rangé par date) : date de la cellule en cours +
    /// affichage seulement pendant le scroll.
    @State private var scrollDate: Date?
    @State private var isScrolling = false
    /// Appui long sur une vignette → mode sélection multiple (comme Photos iOS).
    @State private var selectionMode = false
    @State private var selection = Set<Int64>()
    /// Ordre de sélection (ids ajoutés au fil des taps) → la pile d'aperçu montre la
    /// DERNIÈRE sélectionnée en premier (dessus). Peut contenir des ids retirés ; on
    /// filtre par `selection` à la lecture.
    @State private var selectionOrder: [Int64] = []
    @State private var confirmBulkTrash = false
    /// Nombre d'opérations par lot (poubelle/garder) ENCORE en cours en arrière-plan.
    /// Sert à ne PAS recharger la grille pendant qu'un lot tourne (sinon le retrait
    /// optimiste serait annulé), tout en laissant les boutons accessibles pour
    /// enchaîner d'autres sélections. Compteur (pas booléen) → plusieurs lots
    /// peuvent se chevaucher.
    @State private var pendingOps = 0

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
            if pendingOps == 0 { Task { await vm?.reload() } }
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
                            selectionOrder.removeAll()
                        }
                    }
                    ToolbarItem(placement: .secondaryAction) {
                        Button("Tout désélectionner") {
                            selection.removeAll()
                            selectionOrder.removeAll()
                        }
                        .disabled(selection.isEmpty)
                    }
                    // Croix directe : vide la sélection sans passer par le menu « … ».
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            selection.removeAll()
                            selectionOrder.removeAll()
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
                        .disabled(selection.isEmpty)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button(role: .destructive) {
                            confirmBulkTrash = true
                        } label: {
                            Label("Poubelle (\(selection.count) · \(Fmt.bytes(selectedBytes)))", systemImage: "trash.fill")
                        }
                        .disabled(selection.isEmpty)
                    }
                } else {
                    ToolbarItem(placement: .secondaryAction) {
                        Menu {
                            // Un clic choisit le critère (croissant) ; un re-clic sur le
                            // MÊME critère bascule croissant ↔ décroissant (la flèche le
                            // montre). Taille/Date/Genre basculent ; Dossier est unique.
                            ForEach(GridOrder.Field.allCases) { field in
                                Button {
                                    let current = vm?.order ?? .byFolder
                                    vm?.order = (current.field == field) ? current.toggled : field.ascending
                                    Task { await vm?.reload() }
                                } label: {
                                    let current = vm?.order ?? .byFolder
                                    if current.field == field, field != .folder {
                                        Label(field.label, systemImage: current.isDescending ? "arrow.down" : "arrow.up")
                                    } else if current.field == field {
                                        Label(field.label, systemImage: "checkmark")
                                    } else {
                                        Text(field.label)
                                    }
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
                            // Indicateur mois/année : la cellule qui apparaît donne la
                            // position de défilement courante (rangé par date).
                            if vm.order.field == .date {
                                scrollDate = file.captureDate ?? file.modifiedAt
                            }
                        }
                    }
                }
                .padding(.horizontal, 6)
            }
            .scrollContentBackground(.hidden)
            .yzScreenBackground(theme)
            // Indicateur façon Photos : pastille mois/année sur le bord droit,
            // visible UNIQUEMENT pendant le défilement et seulement si rangé par date.
            .overlay(alignment: .trailing) {
                if isScrolling, vm.order.field == .date, let scrollDate {
                    Text(scrollDate.formatted(.dateTime.month(.wide).year()).capitalized)
                        .font(YZFont.subheadSemi.monospacedDigit())
                        .foregroundStyle(theme.t1)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .yzSurface(theme, radius: 100, elevated: true)
                        .padding(.trailing, 10)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .onScrollPhaseChange { _, newPhase in
                withAnimation(.easeOut(duration: 0.25)) { isScrolling = newPhase != .idle }
            }
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
    /// Calque coloré + badge « doublon » : utile DANS LA GRILLE (repérer/relier les
    /// doublons noyés parmi les autres), mais à désactiver dans l'onglet Doublons
    /// où chaque groupe est déjà isolé (sinon couleurs arbitraires déroutantes).
    var showDuplicateDecoration = true

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
            if showDuplicateDecoration, let groupId = file.dupGroupId {
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
            if showDuplicateDecoration, let groupId = file.dupGroupId {
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
            let attempts = file.kind == .video ? 3 : 1
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
        let selecting = selectionMode && isSelected
        ThumbnailCell(
            file: file, root: root, showSize: filter == .bySize,
            joinsPrevious: joinsPrevious, joinsNext: joinsNext
        )
            // Calque teinté sur la vignette sélectionnée (suit le rétrécissement).
            .overlay {
                if selecting {
                    RoundedRectangle(cornerRadius: YZRadius.chip, style: .continuous)
                        .fill(theme.accent.opacity(0.34))
                }
            }
            // Sélectionnée → rétrécie ; non sélectionnée (en mode sélection) → estompée.
            .scaleEffect(selecting ? 0.82 : 1)
            .opacity(selectionMode && !isSelected ? 0.45 : 1)
            // Cadre épais à taille pleine autour de la vignette rétrécie.
            .overlay {
                if selecting {
                    RoundedRectangle(cornerRadius: YZRadius.chip, style: .continuous)
                        .strokeBorder(theme.accent, lineWidth: 4)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if selectionMode {
                    Group {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, theme.accent)
                        } else {
                            Image(systemName: "circle")
                                .foregroundStyle(.white.opacity(0.95))
                        }
                    }
                    .font(.system(size: 26, weight: .bold))
                    .shadow(color: .black.opacity(0.45), radius: 2)
                    .padding(7)
                }
            }
            .animation(.snappy(duration: 0.18), value: isSelected)
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
                    if let id = file.id { selection.insert(id); selectionOrder.append(id) }
                }
            }
    }

    fileprivate var selectedFiles: [FileRecord] {
        let byId = Dictionary(
            (vm?.files ?? []).compactMap { f in f.id.map { ($0, f) } },
            uniquingKeysWith: { a, _ in a }
        )
        var seen = Set<Int64>()
        var ordered: [FileRecord] = []
        // 1) Les plus récemment sélectionnées d'abord (ordre inverse, dédupliqué).
        for id in selectionOrder.reversed() where selection.contains(id) && seen.insert(id).inserted {
            if let f = byId[id] { ordered.append(f) }
        }
        // 2) Le reste (ex. « tout sélectionner ») en ordre de grille.
        for f in (vm?.files ?? []) where f.id.map({ selection.contains($0) && seen.insert($0).inserted }) ?? false {
            ordered.append(f)
        }
        return ordered
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
            selectionOrder.append(id)   // garde la trace de l'ordre
        }
    }

    fileprivate func exitSelection() {
        selectionMode = false
        selection.removeAll()
        selectionOrder.removeAll()
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
        let ids = Set(files.compactMap(\.id))
        // Retrait OPTIMISTE : la grille se met à jour tout de suite et on quitte le
        // mode sélection → l'utilisateur peut enchaîner d'autres suppressions sans
        // attendre. Les déplacements disque réels se font en arrière-plan (901
        // fichiers en SMB = plusieurs minutes : on ne bloque surtout pas l'écran).
        vm?.removeOptimistically(ids)
        exitSelection()
        pendingOps += 1
        Task {
            try? await triage.trashAll(files)
            pendingOps -= 1
        }
    }

    fileprivate func keepSelection() {
        guard let triage = env.triage else { return }
        let files = selectedFiles
        // « Garder » laisse les fichiers dans la grille (juste marqués gardés) : pas
        // de retrait optimiste. On quitte la sélection tout de suite et on marque en
        // arrière-plan, puis on recharge pour afficher l'état « gardé ».
        exitSelection()
        pendingOps += 1
        Task {
            try? await triage.keepAll(files)
            await vm?.reload()
            pendingOps -= 1
        }
    }
}
