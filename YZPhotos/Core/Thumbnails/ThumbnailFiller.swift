import Foundation

/// Remplit progressivement, en arrière-plan, les vignettes vidéo manquantes —
/// pour que la grille Vidéos finisse par être complète **sans crash** :
/// - une seule à la fois (via le portail de `ThumbnailStore`) ;
/// - se met en pause dès que la mémoire chauffe (géré dans `ThumbnailStore`) ;
/// - se met en pause pendant une analyse (pour ne pas se marcher dessus) ;
/// - plusieurs passes : une vidéo sautée (pression mémoire) est reprise plus tard.
@MainActor
final class ThumbnailFiller {
    private let database: AppDatabase
    private let thumbnails: ThumbnailStore
    private var task: Task<Void, Never>?

    init(database: AppDatabase, thumbnails: ThumbnailStore) {
        self.database = database
        self.thumbnails = thumbnails
    }

    /// (Re)démarre le remplissage pour un disque. `isPaused` = true met en pause
    /// (ex. analyse en cours).
    func start(driveId: String, store: MediaStore, isPaused: @escaping @MainActor () -> Bool) {
        task?.cancel()
        task = Task(priority: .background) { [weak self] in
            await self?.run(driveId: driveId, store: store, isPaused: isPaused)
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func run(driveId: String, store: MediaStore, isPaused: @escaping @MainActor () -> Bool) async {
        // Laisse l'app respirer au démarrage (connexion, premiers écrans).
        try? await Task.sleep(nanoseconds: 6_000_000_000)

        let videos: [FileRecord] = (try? await database.writer.read { db in
            try Queries.gridRequest(driveId: driveId, filter: .videos, scope: nil, order: .byFolder).fetchAll(db)
        }) ?? []
        guard !videos.isEmpty else { return }
        AppLog.log("Remplissage vignettes vidéo : \(videos.count) vidéos à couvrir", "🎞️")

        var total = 0
        for pass in 0..<3 {
            if Task.isCancelled { return }
            var madeThisPass = 0
            for file in videos {
                if Task.isCancelled { return }
                // Pause pendant une analyse.
                while isPaused() {
                    if Task.isCancelled { return }
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                }
                guard let id = file.id else { continue }
                // Déjà en cache disque ? on saute.
                if FileManager.default.fileExists(atPath: thumbnails.cacheURL(forFileID: id).path) { continue }
                // Mémoire tendue → on SOUFFLE longtemps avant de reprendre (anti-jetsam) :
                // le remplissage de fond ne doit jamais pousser l'app au-dessus de la limite.
                if thumbnails.underMemoryPressure {
                    try? await Task.sleep(nanoseconds: 20_000_000_000)
                    continue
                }
                if await thumbnails.thumbnail(for: file, store: store) != nil {
                    madeThisPass += 1
                    total += 1
                    if total % 25 == 0 { AppLog.log("Remplissage vignettes vidéo : \(total) générées", "🎞️") }
                }
                // Doux : délai notable entre deux (laisse la mémoire se récupérer).
                try? await Task.sleep(nanoseconds: 800_000_000)
            }
            // Plus rien de neuf à générer → terminé (le reste = formats illisibles).
            if madeThisPass == 0 { break }
            _ = pass
        }
        AppLog.log("Remplissage vignettes vidéo terminé (\(total) générées)", "🎞️")
    }
}
