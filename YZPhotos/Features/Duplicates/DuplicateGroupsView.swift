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
        .task(id: drive.id) { await reload() }
        .onChange(of: env.scan.phase) { _, newPhase in
            if newPhase == .finished {
                Task { await reload() }
            }
        }
        .onChange(of: env.triage?.changeTick) { _, _ in
            Task { await reload() }
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

    // MARK: - Liste des groupes

    @ViewBuilder
    private var groupsList: some View {
        List {
            Section {
                runControlPanel
            }
            if !groups.isEmpty {
                Section {
                    ForEach(groups, id: \.first?.id) { group in
                        groupRow(group)
                    }
                } header: {
                    Text("\(Fmt.count(groups.count)) groupes · \(Fmt.bytes(totalReclaimable)) récupérables · touche une vignette pour l'aperçu, coche pour sélectionner")
                        .font(YZFont.subhead)
                        .foregroundStyle(theme.t2)
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
                    YZAdaptiveButton(title: "Rechercher les doublons", systemImage: "magnifyingglass", variant: .primary) {
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
            groups.isEmpty ? "Aucune recherche lancée pour l'instant." : "Résultats de la dernière recherche."
        }
    }

    private var totalReclaimable: Int64 {
        groups.reduce(0) { $0 + Queries.reclaimableBytes($1) }
    }

    private var selectedFiles: [FileRecord] {
        groups.flatMap { $0 }.filter { file in
            file.id.map { selection.contains($0) } ?? false
        }
    }

    private var selectedBytes: Int64 {
        selectedFiles.reduce(0) { $0 + $1.sizeBytes }
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
    private func trashGroup(_ group: [FileRecord]) {
        guard let triage = env.triage else { return }
        isWorking = true
        Task {
            try? await triage.trashAll(group)
            await reload()
            isWorking = false
        }
    }

    private func trashSelection() {
        guard let triage = env.triage else { return }
        let files = selectedFiles
        isWorking = true
        Task {
            try? await triage.trashAll(files)
            selection.removeAll()
            previewFile = nil
            await reload()
            isWorking = false
        }
    }

    private func keepBest(_ group: [FileRecord]) {
        guard let triage = env.triage else { return }
        isWorking = true
        Task {
            try? await triage.keepBest(of: group)
            await reload()
            isWorking = false
        }
    }

    private func reload() async {
        let driveId = drive.id
        groups = (try? await env.database.writer.read { db in
            try Queries.duplicateGroups(db, driveId: driveId)
        }) ?? []
        // Purge la sélection des fichiers qui ne sont plus visibles.
        let visibleIds = Set(groups.flatMap { $0 }.compactMap(\.id))
        selection.formIntersection(visibleIds)
    }
}
