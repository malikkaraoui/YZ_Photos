import Foundation

/// Détecte les captures d'écran en arrière-plan, SANS décoder ni lire les fichiers
/// en entier. Idée : une capture iOS est TOUJOURS un PNG aux dimensions EXACTES
/// d'un écran Apple ; les photos appareil sont HEIC/JPG. On ne lit donc que les
/// ~64 premiers octets de chaque PNG (l'en-tête IHDR donne largeur×hauteur), on
/// classe, et on marque `isScreenshot`. Très léger (24 octets utiles) → pas de
/// jetsam, ça marche même en SMB. Plusieurs passes possibles (les PNG illisibles
/// sur coupure réseau sont retentés au prochain lancement).
@MainActor
final class ScreenshotDetector {
    private let database: AppDatabase
    private var task: Task<Void, Never>?

    init(database: AppDatabase) { self.database = database }

    func start(driveId: String, store: MediaStore,
               isPaused: @escaping @MainActor () -> Bool,
               onFound: @escaping @MainActor () -> Void) {
        task?.cancel()
        task = Task(priority: .utility) { [weak self] in
            await self?.run(driveId: driveId, store: store, isPaused: isPaused, onFound: onFound)
        }
    }

    func stop() { task?.cancel(); task = nil }

    private func run(driveId: String, store: MediaStore,
                     isPaused: @escaping @MainActor () -> Bool,
                     onFound: @escaping @MainActor () -> Void) async {
        try? await Task.sleep(nanoseconds: 5_000_000_000)   // laisse l'app démarrer
        var attempted = Set<Int64>()   // déjà tentés CE run (évite de boucler)
        var found = 0, seen = 0
        let batchSize = 200

        while !Task.isCancelled {
            let candidates = ((try? await database.writer.read { db in
                try Queries.screenshotCandidatePNGs(db, driveId: driveId, limit: batchSize)
            }) ?? []).filter { $0.id.map { !attempted.contains($0) } ?? false }
            if candidates.isEmpty { break }

            var results: [(id: Int64, w: Int, h: Int, shot: Bool)] = []
            for file in candidates {
                if Task.isCancelled { return }
                while isPaused() {
                    if Task.isCancelled { return }
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                }
                guard let id = file.id else { continue }
                attempted.insert(id)

                // Dimensions DÉJÀ en base (scan USB complet / run précédent) → on
                // reclasse SANS relire. Sinon, on lit juste l'en-tête (24 octets).
                let dims: (width: Int, height: Int)?
                let alreadyMeasured: Bool
                if let w = file.pixelWidth, let h = file.pixelHeight {
                    dims = (w, h); alreadyMeasured = true
                } else if let header = try? await store.readRange(file.relativePath, offset: 0, length: 64) {
                    dims = MediaClassifier.pngDimensions(fromHeader: header); alreadyMeasured = false
                } else {
                    continue   // illisible / coupure réseau → retenté au prochain run
                }
                guard let d = dims else { continue }
                let shot = MediaClassifier.isScreenshot(
                    ext: "png", fileName: file.fileName,
                    pixelWidth: d.width, pixelHeight: d.height, hasCameraExif: false
                )
                seen += 1
                if shot { found += 1 }
                // On écrit si c'est une capture, OU si on vient de mesurer (pour ne
                // pas relire ce PNG au prochain run).
                if shot || !alreadyMeasured {
                    results.append((id, d.width, d.height, shot))
                }
            }

            if !results.isEmpty {
                try? await database.writer.write { db in
                    for r in results {
                        try db.execute(
                            sql: "UPDATE file SET pixelWidth = ?, pixelHeight = ?, isScreenshot = ? WHERE id = ?",
                            arguments: [r.w, r.h, r.shot, r.id]
                        )
                    }
                }
                // Rafraîchit les grilles ouvertes (l'onglet Captures se remplit en direct).
                if results.contains(where: { $0.shot }) { onFound() }
                AppLog.log("Détection captures : \(found) trouvées · \(seen) PNG examinés", "📸")
            }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
        AppLog.log("Détection captures terminée : \(found) capture(s) sur \(seen) PNG", "📸")
    }
}
