import SwiftUI

/// Onglet Doublons : liste des groupes à gauche, aperçu permanent à droite.
/// Coche sur chaque vignette pour une sélection multiple → suppression en un coup.
/// « Garder la meilleure » reste l'action rapide par groupe.
struct DuplicateGroupsView: View {
    let drive: DriveRecord
    let root: URL

    @Environment(AppEnvironment.self) private var env
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
                        .font(.subheadline)
                }
            }
        }
        .listStyle(.insetGrouped)
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
                HStack {
                    ProgressView().controlSize(.small)
                    Text(runPhaseTitle)
                        .font(.headline)
                    Spacer()
                    Button {
                        dup.isPaused ? dup.resume() : dup.pause()
                    } label: {
                        Label(dup.isPaused ? "Reprendre" : "Pause",
                              systemImage: dup.isPaused ? "play.fill" : "pause.fill")
                    }
                    .buttonStyle(.bordered)
                    Button(role: .destructive) {
                        dup.cancel()
                    } label: {
                        Label("Arrêter", systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                }
                Text(runPhaseExplanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if dup.phase == .confirming, dup.candidateGroups > 0 {
                    ProgressView(value: Double(dup.groupsConfirmed), total: Double(dup.candidateGroups))
                    Text("\(Fmt.count(dup.groupsConfirmed)) / \(Fmt.count(dup.candidateGroups)) groupes vérifiés")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else if dup.phase == .comparingVisuals, dup.photosTotal > 0 {
                    ProgressView(value: Double(dup.photosCompared), total: Double(dup.photosTotal))
                    Text("\(Fmt.count(dup.photosCompared)) / \(Fmt.count(dup.photosTotal)) photos comparées")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(idleStatusText)
                            .font(.headline)
                        Text("La recherche compare les empreintes calculées pendant l'analyse : copies strictement identiques d'abord (vérifiées octet par octet), puis photos quasi identiques (rafales, recompressions).")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        dup.start(driveId: drive.id, root: root)
                    } label: {
                        Label("Rechercher les doublons", systemImage: "magnifyingglass")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
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
                Text(isExact ? "Identiques" : "Similaires")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(isExact ? Color.orange.opacity(0.2) : Color.blue.opacity(0.2), in: Capsule())
                Text("\(group.count) fichiers · \(Fmt.bytes(Queries.reclaimableBytes(group))) récupérables")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(role: .destructive) {
                    trashGroup(group)
                } label: {
                    Label("Tout supprimer", systemImage: "trash.fill")
                        .font(.subheadline.bold())
                }
                .buttonStyle(.bordered)
                .disabled(isWorking)
                Button {
                    keepBest(group)
                } label: {
                    Label("Garder la meilleure", systemImage: "wand.and.stars")
                        .font(.subheadline.bold())
                }
                .buttonStyle(.borderedProminent)
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

    /// Vignette d'un doublon : tap = aperçu à droite, coche = sélection multiple.
    private func duplicateThumb(_ file: FileRecord, isBest: Bool) -> some View {
        let isSelected = file.id.map { selection.contains($0) } ?? false
        return ThumbnailCell(file: file, root: root, showSize: true)
            .frame(width: 130, height: 130)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        previewFile?.id == file.id ? Color.accentColor : (isSelected ? .red : .clear),
                        lineWidth: 3
                    )
            )
            .overlay(alignment: .topLeading) {
                if isBest {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .shadow(radius: 2)
                        .padding(5)
                }
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    toggleSelection(file)
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isSelected ? .red : .white)
                        .shadow(radius: 3)
                        .padding(5)
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
