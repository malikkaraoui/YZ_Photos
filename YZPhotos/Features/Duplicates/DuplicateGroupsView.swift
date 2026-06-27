import SwiftUI

/// Onglet Doublons : liste des groupes à gauche, aperçu permanent à droite.
/// Coche sur chaque vignette pour une sélection multiple → suppression en un coup.
/// « Garder la meilleure » reste l'action rapide par groupe.
struct DuplicateGroupsView: View {
    let drive: DriveRecord
    let root: URL

    @Environment(AppEnvironment.self) private var env
    @Environment(\.yzTheme) private var theme
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var groups: [[FileRecord]] = []
    @State private var previewFile: FileRecord?
    @State private var selection = Set<Int64>()
    @State private var isWorking = false
    @State private var confirmBulkTrash = false
    /// Disque déjà chargé : évite de tout recharger (64 000 fichiers) à CHAQUE
    /// ouverture de l'onglet (le `.task` se relance à chaque apparition).
    @State private var loadedDriveId: String?
    @State private var isLoading = false
    /// Index id→fichier construit UNE fois par reload : la sélection (octets, etc.)
    /// se calcule alors en O(sélection) au lieu de re-aplatir des dizaines de
    /// milliers de groupes à CHAQUE rendu (ce qui faisait ramer/figer l'app).
    @State private var fileById: [Int64: FileRecord] = [:]
    /// Total récupérable mis en cache (sinon resommé sur 32 000 groupes à chaque rendu).
    @State private var totalReclaimableCached: Int64 = 0
    @State private var sort: DupSort = .gainDesc
    /// Nombre max de groupes RENDUS dans la liste : le reste est gardé en mémoire
    /// mais pas diffusé, pour que le diff de liste reste rapide même à 32 000 groupes.
    private let displayLimit = 200

    /// Ordre d'affichage des groupes de doublons, au choix de l'utilisateur.
    enum DupSort: String, CaseIterable, Identifiable {
        case gainDesc, gainAsc, type, count
        var id: String { rawValue }
        var label: String {
            switch self {
            case .gainDesc: "Plus gros gain d'espace"
            case .gainAsc: "Plus petit gain d'espace"
            case .type: "Par type (vidéos d'abord)"
            case .count: "Plus de copies"
            }
        }
        var icon: String {
            switch self {
            case .gainDesc: "arrow.down"
            case .gainAsc: "arrow.up"
            case .type: "photo.on.rectangle.angled"
            case .count: "square.stack.3d.up"
            }
        }
    }

    var body: some View {
        NavigationStack {
            MasterDetailLayout(
                selectedFile: $previewFile,
                root: root,
                onAction: { Task { await reload() } },
                selectionSummary: selection.isEmpty ? nil : SelectionSummary(files: selectedFiles)
            ) {
                groupsList
            }
            .tint(theme.accent)
            .navigationTitle("Doublons")
            .toolbar {
                if !selection.isEmpty {
                    // Croix directe : vide la sélection d'un tap.
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            selection.removeAll()
                        } label: {
                            Label("Désélectionner", systemImage: "xmark.circle.fill")
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button(role: .destructive) {
                            confirmBulkTrash = true
                        } label: {
                            Label(
                                "Mettre à la poubelle (\(selection.count) · \(Fmt.bytes(selectedBytes)))",
                                systemImage: "trash.fill"
                            )
                            .bold()
                        }
                        .disabled(isWorking)
                    }
                }
            }
        }
        .task(id: drive.id) {
            // Charge UNE fois par disque : le `.task` se relance à CHAQUE apparition
            // de l'onglet ; sans ce garde on rechargeait 64 000 fichiers (quelques
            // secondes) à chaque clic sur Doublons. Les données restent en mémoire
            // entre les onglets ; un nouveau scan / une nouvelle recherche
            // déclenchent un rechargement explicite.
            guard loadedDriveId != drive.id else { return }
            await reload()
            loadedDriveId = drive.id
        }
        .onChange(of: env.scan.phase) { _, newPhase in
            if newPhase == .finished {
                Task { await reload() }
            }
        }
        // PAS de rechargement sur `triage.changeTick` ici : les actions de cette
        // vue (garder la meilleure / supprimer) retirent déjà le groupe de façon
        // OPTIMISTE. Recharger sur le changeTick du tri en arrière-plan refaisait
        // apparaître le groupe une fraction de seconde (entre « garder le meilleur »
        // et « mettre les copies à la poubelle ») → effet en deux temps. La vue se
        // resynchronise sur la base à la prochaine navigation (.task) / fin de scan.
        .confirmationDialog(
            "Mettre \(selection.count) fichiers à la poubelle (\(Fmt.bytes(selectedBytes))) ? Rien n'est supprimé tant que la corbeille n'est pas vidée.",
            isPresented: $confirmBulkTrash,
            titleVisibility: .visible
        ) {
            Button("Mettre à la poubelle", role: .destructive) { trashSelection() }
            Button("Annuler", role: .cancel) {}
        }
    }

    // MARK: - Liste des groupes

    @ViewBuilder
    private var groupsList: some View {
        List {
            Section {
                runControlPanel
            }
            if isLoading && groups.isEmpty {
                Section {
                    HStack(spacing: 10) {
                        Spacer()
                        ProgressView()
                        Text("Chargement des doublons…")
                            .font(YZFont.subhead)
                            .foregroundStyle(theme.t2)
                        Spacer()
                    }
                    .padding(.vertical, 24)
                    .listRowBackground(Color.clear)
                }
            }
            if !groups.isEmpty {
                Section {
                    // On ne DIFFUSE que les `displayLimit` premiers groupes (triés) :
                    // diffuser/differ 32 000 lignes à chaque modif figeait l'app.
                    // L'utilisateur traite le haut de la pile, les suivants remontent.
                    ForEach(groups.prefix(displayLimit), id: \.first?.id) { group in
                        groupRow(group)
                    }
                } header: {
                    HStack(alignment: .firstTextBaseline) {
                        Text(groups.count > displayLimit
                             ? "\(Fmt.count(groups.count)) groupes · \(Fmt.bytes(totalReclaimable)) récupérables · \(displayLimit) affichés"
                             : "\(Fmt.count(groups.count)) groupes · \(Fmt.bytes(totalReclaimable)) récupérables")
                            .font(YZFont.subhead)
                            .foregroundStyle(theme.t2)
                        Spacer()
                        Menu {
                            Picker("Trier", selection: $sort) {
                                ForEach(DupSort.allCases) { s in
                                    Label(s.label, systemImage: s.icon).tag(s)
                                }
                            }
                        } label: {
                            Label("Trier", systemImage: "arrow.up.arrow.down")
                                .font(YZFont.subhead)
                                .foregroundStyle(theme.accent)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .yzScreenBackground(theme)
        .refreshable { await reload() }
        .onChange(of: env.duplicates.phase) { _, newPhase in
            if newPhase == .finished {
                Task { await reload() }
            }
        }
        .onChange(of: sort) { _, _ in applySort() }
    }

    /// Pilotage de la recherche : à la demande, avec progression, pause et arrêt.
    @ViewBuilder
    private var runControlPanel: some View {
        let dup = env.duplicates
        VStack(alignment: .leading, spacing: 10) {
            if dup.isRunning {
                HStack(spacing: 8) {
                    // En pause : on STOPPE l'animation (spinner → icône pause figée),
                    // sinon ça donne l'impression que ça tourne encore.
                    if dup.isPaused {
                        Image(systemName: "pause.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(theme.t2)
                    } else {
                        ProgressView().controlSize(.small)
                    }
                    Text(dup.isPaused ? "En pause" : runPhaseTitle)
                        .font(YZFont.headline)
                        .foregroundStyle(theme.t1)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                // Boutons sur leur PROPRE rangée + largeur figée + libellé sur une
                // seule ligne : en Split View étroit, « Pause »/« Arrêter » ne se
                // coupent plus sur deux lignes.
                HStack(spacing: 10) {
                    Button {
                        dup.isPaused ? dup.resume() : dup.pause()
                    } label: {
                        // Icône SEULE, centrée dans une cellule de taille fixe.
                        Image(systemName: dup.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 34, height: 22)
                    }
                    .buttonStyle(YZButtonStyle(.secondary))
                    .accessibilityLabel(dup.isPaused ? "Reprendre" : "Pause")
                    Button {
                        dup.cancel()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 34, height: 22)
                    }
                    .buttonStyle(YZButtonStyle(.secondary))
                    .accessibilityLabel("Arrêter")
                    Spacer(minLength: 0)
                }
                Text(runPhaseExplanation)
                    .font(YZFont.subhead)
                    .foregroundStyle(theme.t2)
                if dup.phase == .confirming, dup.candidateGroups > 0 {
                    YZProgressBar(value: dup.candidateGroups > 0 ? Double(dup.groupsConfirmed) / Double(dup.candidateGroups) : 0,
                                  tone: theme.accent)
                    Text("\(Fmt.count(dup.groupsConfirmed)) / \(Fmt.count(dup.candidateGroups)) groupes vérifiés")
                        .font(YZFont.caption.monospacedDigit())
                        .foregroundStyle(theme.t2)
                } else if dup.phase == .comparingVisuals, dup.photosTotal > 0 {
                    YZProgressBar(value: dup.photosTotal > 0 ? Double(dup.photosCompared) / Double(dup.photosTotal) : 0,
                                  tone: theme.accent)
                    Text("\(Fmt.count(dup.photosCompared)) / \(Fmt.count(dup.photosTotal)) photos comparées")
                        .font(YZFont.caption.monospacedDigit())
                        .foregroundStyle(theme.t2)
                }
                // Débit + temps restant estimé (phase mesurée en cours).
                if dup.rate > 0 {
                    Text("\(Int(dup.rate.rounded()))/s"
                         + (dup.etaSeconds.map { " · reste \(Fmt.eta($0))" } ?? ""))
                        .font(YZFont.caption.monospacedDigit())
                        .foregroundStyle(theme.t3)
                }
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(idleStatusText)
                            .font(YZFont.headline)
                            .foregroundStyle(theme.t1)
                        Text("La recherche compare les empreintes calculées pendant l'analyse : copies strictement identiques d'abord (vérifiées octet par octet), puis photos quasi identiques (rafales, recompressions).")
                            .font(YZFont.subhead)
                            .foregroundStyle(theme.t2)
                    }
                    Spacer()
                    // Si des résultats existent déjà (recherche faite, persistée),
                    // la recherche n'est plus l'action principale : bouton « Relancer »
                    // discret (secondaire). Sinon, « Rechercher » en primaire.
                    let hasResults = !groups.isEmpty
                    YZAdaptiveButton(
                        title: hasResults ? "Relancer la recherche" : "Rechercher les doublons",
                        systemImage: hasResults ? "arrow.clockwise" : "magnifyingglass",
                        variant: hasResults ? .secondary : .primary
                    ) {
                        dup.start(driveId: drive.id, store: env.currentStore ?? LocalMediaStore(root: root))
                    }
                    .disabled(env.scan.isRunning && env.scan.phase == .enumerating)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var runPhaseTitle: String {
        switch env.duplicates.phase {
        case .findingCandidates: "Étape 1/4 — Repérage des candidats"
        case .confirming: "Étape 2/4 — Confirmation octet par octet"
        case .comparingVisuals: "Étape 3/4 — Comparaison visuelle des photos"
        case .writing: "Étape 4/4 — Enregistrement des groupes"
        default: ""
        }
    }

    private var runPhaseExplanation: String {
        switch env.duplicates.phase {
        case .findingCandidates:
            "Recherche des fichiers de même taille et même empreinte rapide — quasi instantané."
        case .confirming:
            "Chaque groupe candidat est relu en entier pour garantir que ce sont de vraies copies (les grosses vidéos prennent du temps)."
        case .comparingVisuals:
            "Les photos sont comparées visuellement pour repérer les quasi-doublons : rafales, recompressions, redimensionnements."
        case .writing:
            "Écriture des groupes en base — quelques secondes."
        default: ""
        }
    }

    private var idleStatusText: String {
        switch env.duplicates.phase {
        case .finished:
            "\(Fmt.count(env.duplicates.groupsFound)) groupes trouvés"
            + (env.duplicates.finishedAt.map { " · terminé le \(Fmt.date($0))" } ?? "")
        case .cancelled:
            "Recherche arrêtée — relance quand tu veux."
        case .failed(let message):
            "Erreur : \(message)"
        default:
            // Reconnexion : la phase en mémoire est remise à .idle, mais les groupes
            // sont rechargés depuis la BASE (résultats persistés). On le dit
            // clairement au lieu de proposer une nouvelle recherche comme si rien
            // n'avait été fait.
            groups.isEmpty
                ? "Aucune recherche lancée pour l'instant."
                : "Recherche terminée — \(Fmt.count(groups.count)) groupes à traiter"
        }
    }

    // Total mis en cache (calculé dans reload + ajusté aux retraits optimistes) —
    // plus de re-somme sur 32 000 groupes à chaque rendu.
    private var totalReclaimable: Int64 { totalReclaimableCached }

    // O(sélection) via l'index, au lieu d'aplatir ~64 000 fichiers à chaque rendu.
    private var selectedFiles: [FileRecord] {
        selection.compactMap { fileById[$0] }
    }

    private var selectedBytes: Int64 {
        selection.reduce(0) { $0 + (fileById[$1]?.sizeBytes ?? 0) }
    }

    private func groupRow(_ group: [FileRecord]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                let isExact = group.contains { $0.dupKind == .exact }
                YZBadge(isExact ? "Identiques" : "Similaires",
                        tone: isExact ? .warn : .accent)
                Text("\(group.count) fichiers · \(Fmt.bytes(Queries.reclaimableBytes(group))) récupérables")
                    .font(YZFont.subhead)
                    .foregroundStyle(theme.t2)
                Spacer()
                YZAdaptiveButton(title: "Tout supprimer", systemImage: "trash.fill", variant: .destructive) {
                    trashGroup(group)
                }
                .disabled(isWorking)
                YZAdaptiveButton(title: "Garder la meilleure", systemImage: "wand.and.stars", variant: .primary) {
                    keepBest(group)
                }
                .disabled(isWorking)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    let best = Queries.bestOfGroup(group)
                    // La meilleure (étoile jaune) toujours tout à gauche,
                    // le reste par taille décroissante.
                    let ordered = group.sorted { a, b in
                        if a.id == best?.id { return true }
                        if b.id == best?.id { return false }
                        return a.sizeBytes > b.sizeBytes
                    }
                    ForEach(ordered) { file in
                        duplicateThumb(file, isBest: file.id == best?.id)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }

    /// Vignettes plus petites en Split View étroit (largeur compacte) pour que la
    /// ligne respire ; pleine taille en largeur normale.
    private var thumbSize: CGFloat { hSize == .compact ? 92 : 130 }

    /// Vignette d'un doublon : tap = aperçu à droite, coche = sélection multiple.
    private func duplicateThumb(_ file: FileRecord, isBest: Bool) -> some View {
        let isSelected = file.id.map { selection.contains($0) } ?? false
        let outlineColor: Color = {
            if previewFile?.id == file.id { return theme.accent }
            if isSelected { return theme.trash }
            if isBest { return theme.warn }
            return .clear
        }()
        return ThumbnailCell(file: file, root: root, showSize: true, showDuplicateDecoration: false)
            .frame(width: thumbSize, height: thumbSize)
            .opacity(isSelected ? 0.5 : 1)
            .clipShape(RoundedRectangle(cornerRadius: YZRadius.chip, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: YZRadius.chip, style: .continuous)
                    .strokeBorder(outlineColor, lineWidth: 3)
            )
            .overlay(alignment: .topLeading) {
                if isBest {
                    Image(systemName: "star.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(theme.warn, in: Circle())
                        .padding(6)
                }
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    toggleSelection(file)
                } label: {
                    Image(systemName: isSelected ? "checkmark" : "circle")
                        .font(.system(size: isSelected ? 13 : 22, weight: .bold))
                        .foregroundStyle(isSelected ? .white : .white)
                        .frame(width: 26, height: 26)
                        .background {
                            if isSelected {
                                Circle().fill(theme.trash)
                            } else {
                                Circle().fill(Color.blackA(0.28))
                            }
                        }
                        .shadow(radius: 2)
                        .padding(6)
                }
                .buttonStyle(.plain)
            }
            .onTapGesture { previewFile = file }
    }

    // MARK: - Actions

    private func toggleSelection(_ file: FileRecord) {
        guard let id = file.id else { return }
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }

    /// « Tout supprimer » : met le groupe entier à la poubelle (restaurable).
    /// INSTANTANÉ : le groupe disparaît tout de suite, la mise à la poubelle
    /// (déplacement réseau) se fait en arrière-plan — l'utilisateur enchaîne sans
    /// attendre. Plus de rechargement complet (qui re-interrogeait des dizaines de
    /// milliers de groupes → c'était ça la latence).
    private func trashGroup(_ group: [FileRecord]) {
        guard let triage = env.triage else { return }
        removeGroupOptimistically(group)
        Task { try? await triage.trashAll(group) }
    }

    /// Petit retour tactile : confirme que le bouton a bien pris le tap, même si la
    /// ligne disparaît aussitôt (l'utilisateur SENT que son clic a été pris).
    private func tapFeedback() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Retire un groupe de l'affichage IMMÉDIATEMENT (UI optimiste). Met à jour
    /// l'index et le total en cache de façon incrémentale (pas de recalcul global).
    private func removeGroupOptimistically(_ group: [FileRecord]) {
        tapFeedback()
        let gid = group.first?.dupGroupId
        let ids = Set(group.compactMap(\.id))
        totalReclaimableCached -= Queries.reclaimableBytes(group)
        for id in ids { fileById[id] = nil }
        if let idx = groups.firstIndex(where: { $0.first?.dupGroupId == gid }) {
            withAnimation(.easeOut(duration: 0.2)) { _ = groups.remove(at: idx) }
        }
        selection.subtract(ids)
        if let pid = previewFile?.id, ids.contains(pid) { previewFile = nil }
    }

    private func trashSelection() {
        guard let triage = env.triage else { return }
        tapFeedback()
        let files = selectedFiles
        let ids = Set(files.compactMap(\.id))
        // Optimiste : on retire les fichiers sélectionnés des groupes tout de suite
        // (et les groupes réduits à 1 fichier, qui ne sont plus des doublons), SANS
        // animation (animer des centaines de lignes d'une liste de 32 000 figeait
        // l'app). La mise à la poubelle se fait en arrière-plan.
        for i in groups.indices { groups[i].removeAll { ids.contains($0.id ?? -1) } }
        groups.removeAll { $0.count <= 1 }
        rebuildIndex()
        selection.removeAll()
        previewFile = nil
        Task { try? await triage.trashAll(files) }
    }

    private func keepBest(_ group: [FileRecord]) {
        guard let triage = env.triage else { return }
        // Instantané : on retire le groupe TOUT DE SUITE, le tri (poubelle des
        // autres copies) se fait en arrière-plan.
        removeGroupOptimistically(group)
        Task { try? await triage.keepBest(of: group) }
    }

    private func reload() async {
        let driveId = drive.id
        isLoading = true
        let loaded = (try? await env.database.writer.read { db in
            try Queries.duplicateGroups(db, driveId: driveId)
        }) ?? []
        groups = loaded
        applySort()
        rebuildIndex()
        isLoading = false
    }

    /// Réordonne les groupes selon le choix de l'utilisateur (clé calculée une fois
    /// par groupe, pas pendant le rendu).
    private func applySort() {
        switch sort {
        case .gainDesc:
            groups = groups.map { ($0, Queries.reclaimableBytes($0)) }.sorted { $0.1 > $1.1 }.map(\.0)
        case .gainAsc:
            groups = groups.map { ($0, Queries.reclaimableBytes($0)) }.sorted { $0.1 < $1.1 }.map(\.0)
        case .count:
            groups.sort { $0.count > $1.count }
        case .type:
            groups = groups
                .map { ($0, $0.first?.kind == .video ? 0 : 1, Queries.reclaimableBytes($0)) }
                .sorted { $0.1 != $1.1 ? $0.1 < $1.1 : $0.2 > $1.2 }
                .map(\.0)
        }
    }

    /// (Re)construit l'index id→fichier + le total récupérable en cache, et purge
    /// la sélection des fichiers disparus. Une seule passe sur les groupes (jamais
    /// pendant le rendu).
    private func rebuildIndex() {
        var byId: [Int64: FileRecord] = [:]
        var total: Int64 = 0
        for group in groups {
            for f in group { if let id = f.id { byId[id] = f } }
            total += Queries.reclaimableBytes(group)
        }
        fileById = byId
        totalReclaimableCached = total
        selection.formIntersection(Set(byId.keys))
    }
}
