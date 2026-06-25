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
    private static let prefetchCount = 8
    /// Tâche de préchargement en cours : on l'annule avant d'en lancer une autre
    /// (sinon chaque swipe empilait une boucle de lectures de gros fichiers → jetsam).
    private var prefetchTask: Task<Void, Never>?

    var canUndo: Bool { triage.canUndo }

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
            window = files
            remaining = count
            prefetch()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Décision sur la carte du haut. Swipe droite = garder, gauche = poubelle.
    func decide(file: FileRecord, keep: Bool) async {
        do {
            if keep {
                try await triage.keep(file)
            } else {
                try await triage.trash(file)
            }
            window.removeAll { $0.id == file.id }
            remaining = max(0, remaining - 1)
            if window.count < 10 {
                await refresh()
            } else {
                prefetch()
            }
        } catch {
            if await store.isReachable() == false {
                onDiskError()
            } else {
                errorMessage = error.localizedDescription
            }
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
        let count = thumbnails.isPhone ? 3 : Self.prefetchCount
        let files = Array(window.prefix(count))
        let thumbnails = self.thumbnails
        let store = self.store
        prefetchTask = Task.detached(priority: .utility) {
            for file in files {
                if Task.isCancelled { return }
                _ = await thumbnails.cardImage(for: file, store: store)
            }
        }
    }
}
