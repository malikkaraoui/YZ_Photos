import Foundation
import Observation

/// File d'attente du deck : fenêtre de ~50 fichiers non triés, préchargement
/// des images suivantes, décisions et annulation.
@MainActor
@Observable
final class TriageViewModel {
    let filter: TriageFilter
    /// Préfixe de chemin : restreint le deck à un dossier (nil = tout le disque).
    let scope: String?

    private let database: AppDatabase
    private let thumbnails: ThumbnailStore
    private let triage: TriageService
    private let driveId: String
    private let store: MediaStore
    /// Appelé quand une opération échoue parce que le disque a disparu.
    private let onDiskError: () -> Void

    private(set) var window: [FileRecord] = []
    private(set) var remaining = 0
    private(set) var errorMessage: String?

    private static let windowSize = 50
    /// Tâche de préchargement en cours : on l'annule avant d'en lancer une autre
    /// (sinon chaque swipe empilait une boucle de lectures de gros fichiers → jetsam).
    private var prefetchTask: Task<Void, Never>?
    /// Cartes dont la décision (garder/poubelle) tourne ENCORE en arrière-plan : on
    /// les EXCLUT d'un refresh, sinon — encore .untriaged en base le temps du
    /// déplacement réseau — elles réapparaîtraient dans le deck (« la carte revient »).
    private var decidingIds = Set<Int64>()
    /// La dernière fenêtre chargée était-elle ALÉATOIRE ? → un rechargement
    /// (reload) garde le mode pour ne pas « revenir aux premières photos ».
    private var lastWasRandom = false

    var canUndo: Bool { triage.canUndo }

    /// Recharge la fenêtre en CONSERVANT le mode (aléatoire si on avait fait shuffle,
    /// séquentiel sinon). À utiliser pour tous les rafraîchissements automatiques.
    func reload() async {
        if lastWasRandom { await refreshRandom() } else { await refresh() }
    }

    init(
        database: AppDatabase,
        thumbnails: ThumbnailStore,
        triage: TriageService,
        driveId: String,
        store: MediaStore,
        filter: TriageFilter,
        scope: String? = nil,
        onDiskError: @escaping () -> Void
    ) {
        self.database = database
        self.thumbnails = thumbnails
        self.triage = triage
        self.driveId = driveId
        self.store = store
        self.filter = filter
        self.scope = scope
        self.onDiskError = onDiskError
    }

    func refresh() async {
        lastWasRandom = false
        let driveId = self.driveId
        let filter = self.filter
        let scope = self.scope
        do {
            let (files, count) = try await database.writer.read { db in
                (
                    try Queries.untriagedWindow(db, driveId: driveId, filter: filter, scope: scope, limit: Self.windowSize),
                    try Queries.untriagedCount(db, driveId: driveId, filter: filter, scope: scope)
                )
            }
            // Exclut les cartes dont la décision est encore en cours en arrière-plan
            // (sinon elles reviendraient, encore .untriaged en base le temps du réseau).
            let live = await pruneMissing(files)
            window = live.filter { $0.id.map { !decidingIds.contains($0) } ?? true }
            remaining = max(0, count - (files.count - live.count) - decidingIds.count)
            prefetch()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// « Repartir au hasard » : recharge une fenêtre ALÉATOIRE de fichiers non triés.
    /// Pratique pour varier… et pour échapper à une carte qui coince.
    func refreshRandom() async {
        lastWasRandom = true
        let driveId = self.driveId
        let filter = self.filter
        let scope = self.scope
        do {
            let (files, count) = try await database.writer.read { db in
                (
                    try Queries.untriagedWindowRandom(db, driveId: driveId, filter: filter, scope: scope, limit: Self.windowSize),
                    try Queries.untriagedCount(db, driveId: driveId, filter: filter, scope: scope)
                )
            }
            let live = await pruneMissing(files)
            window = live.filter { $0.id.map { !decidingIds.contains($0) } ?? true }
            remaining = max(0, count - (files.count - live.count) - decidingIds.count)
            prefetch()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Retire du tri les fichiers DÉJÀ SUPPRIMÉS du disque (entrées DB obsolètes, ex.
    /// supprimés depuis un ordinateur) : c'était la cause des captures « impossibles à
    /// afficher » qui revenaient dans le deck. Vérif LOCALE uniquement (stat instantané
    /// et fiable ; en réseau on ne stat pas la fenêtre). Les marque .deleted → exclus
    /// du deck ET des grilles, sans toucher au disque (ils n'y sont déjà plus).
    private func pruneMissing(_ files: [FileRecord]) async -> [FileRecord] {
        var missing: [Int64] = []
        for f in files {
            guard let id = f.id, let url = store.localURL(for: f) else { continue }
            if !FileManager.default.fileExists(atPath: url.path) { missing.append(id) }
        }
        guard !missing.isEmpty else { return files }
        let ids = missing
        try? await database.writer.write { db in
            try db.execute(
                sql: "UPDATE file SET status = ? WHERE id IN (\(ids.map(String.init).joined(separator: ",")))",
                arguments: [FileStatus.deleted.rawValue]
            )
        }
        AppLog.log("Tri : \(missing.count) fichier(s) introuvable(s) retiré(s) — déjà supprimés du disque", "🗑️")
        return files.filter { $0.id.map { !missing.contains($0) } ?? true }
    }

    /// Décision OPTIMISTE sur la carte du haut (swipe droite = garder, gauche =
    /// poubelle). Synchrone : retire la carte de la fenêtre TOUT DE SUITE pour que
    /// le deck avance sans attendre le réseau ; le garder/poubelle réel se fait en
    /// arrière-plan. À appeler dans la MÊME transaction que la remise à zéro de
    /// l'offset de swipe → la nouvelle carte du dessus apparaît directement au centre.
    func advance(file: FileRecord, keep: Bool) {
        guard let id = file.id else { return }
        decidingIds.insert(id)
        window.removeAll { $0.id == id }
        remaining = max(0, remaining - 1)
        // Recharge TÔT (fenêtre < 25) pour garder de l'avance même en swipant vite.
        if window.count < 25 {
            Task { await refresh() }
        } else {
            prefetch()
        }
        Task {
            do {
                if keep { try await triage.keep(file) } else { try await triage.trash(file) }
            } catch {
                if await store.isReachable() == false { onDiskError() }
                else { errorMessage = error.localizedDescription }
            }
            decidingIds.remove(id)
        }
    }

    /// Retour en arrière : la carte annulée revient en haut du deck.
    func undo() async {
        do {
            guard let restored = try await triage.undo() else { return }
            if matchesFilter(restored) {
                window.removeAll { $0.id == restored.id }
                window.insert(restored, at: 0)
                remaining += 1
            }
        } catch {
            if await store.isReachable() == false {
                onDiskError()
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private func matchesFilter(_ file: FileRecord) -> Bool {
        if let scope, !file.relativePath.hasPrefix(scope + "/") { return false }
        return switch filter {
        case .all, .bySize: true
        case .photos: file.kind == .photo
        case .videos: file.kind == .video
        case .screenshots: file.isScreenshot
        case .duplicates: file.dupGroupId != nil
        }
    }

    /// Précharge les images des prochaines cartes pour un swipe sans attente.
    /// UNE seule boucle à la fois (on annule la précédente) et plus courte sur
    /// iPhone : sinon chaque swipe empilait une boucle de lectures de fichiers
    /// entiers (RAW/DNG = dizaines de Mo) → la mémoire grimpait jusqu'au jetsam.
    private func prefetch() {
        prefetchTask?.cancel()
        // Plus profond + en PARALLÈLE sur iPad (le portail réseau borne déjà la
        // concurrence anti-jetsam) → l'avance suit le swipe rapide. iPhone reste
        // prudent (mémoire serrée) : court et en série.
        let count = thumbnails.isPhone ? 3 : 12
        let concurrency = thumbnails.isPhone ? 1 : 3
        let files = Array(window.prefix(count))
        let thumbnails = self.thumbnails
        let store = self.store
        prefetchTask = Task.detached(priority: .utility) {
            await withTaskGroup(of: Void.self) { group in
                var next = 0
                func submit() {
                    guard next < files.count else { return }
                    let file = files[next]; next += 1
                    group.addTask {
                        if Task.isCancelled { return }
                        _ = await thumbnails.cardImage(for: file, store: store)
                    }
                }
                for _ in 0..<min(concurrency, files.count) { submit() }
                for await _ in group {
                    if Task.isCancelled { break }
                    submit()
                }
            }
        }
    }
}
