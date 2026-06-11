import Foundation
import GRDB
import Observation
import UIKit

struct DriveDisconnectedError: Error {}

/// Levée quand l'empreinte mémoire approche la limite iOS (~5 Go) :
/// on s'arrête proprement AVANT que le système ne tue l'app — la reprise
/// est gratuite (le travail accompli est en base).
struct ScanMemoryError: Error {}

/// Orchestre le scan en 2 passes :
/// 1. énumération + upsert des métadonnées (rapide — débloque l'onglet Par taille) ;
/// 2. analyse (hash partiel, miniature, dHash, dimensions, classification) avec
///    workers bornés, puis détection de doublons.
/// Idempotent : un crash ou un débranchage reprend là où la base s'est arrêtée.
@MainActor
@Observable
final class ScanCoordinator {
    enum Phase: Equatable {
        case idle
        case enumerating
        case analyzing
        case finished
        case failed(String)
        case diskDisconnected
    }

    private(set) var phase: Phase = .idle
    private(set) var filesSeen = 0
    /// Octets cumulés des fichiers vus : c'est LE chiffre qui bouge après un
    /// nettoyage (supprimer 100 vidéos ne change presque pas le nombre de
    /// fichiers, mais retire bien 100 Go d'ici).
    private(set) var bytesSeen: Int64 = 0
    private(set) var analyzedDone = 0
    private(set) var analyzedTotal = 0
    private(set) var startedAt: Date?
    /// Transparence : ce que le scan est en train de traiter, en clair.
    private(set) var currentPath: String = ""
    private(set) var photosAnalyzed = 0
    private(set) var videosAnalyzed = 0
    private(set) var screenshotsFound = 0
    /// Début de la passe d'analyse (sert au débit et à l'ETA, hors passe 1).
    private var analysisStartedAt: Date?
    /// Empreinte mémoire de l'app en Mo (transparence + garde-fou anti-crash).
    private(set) var memoryFootprintMB = 0
    /// true si le scan a été interrompu par un passage en arrière-plan :
    /// il redémarre automatiquement au retour au premier plan.
    private(set) var interruptedByBackground = false

    var isRunning: Bool {
        switch phase {
        case .enumerating, .analyzing: true
        default: false
        }
    }

    /// Fichiers analysés par seconde (pour l'ETA affichée).
    var rate: Double {
        guard let analysisStartedAt, analyzedDone > 0 else { return 0 }
        let elapsed = Date().timeIntervalSince(analysisStartedAt)
        guard elapsed > 1 else { return 0 }
        return Double(analyzedDone) / elapsed
    }

    /// Temps restant estimé de la passe d'analyse, en secondes.
    var etaSeconds: Double? {
        guard rate > 0, analyzedTotal > analyzedDone else { return nil }
        return Double(analyzedTotal - analyzedDone) / rate
    }

    private let database: AppDatabase
    private let thumbnails: ThumbnailStore
    private var scanTask: Task<Void, Never>?

    // 4 workers : le goulot est l'USB, et 8 décodages d'images simultanés
    // créaient des pics mémoire fatals (jetsam constaté à 5,2 Go).
    private static let analysisWorkers = 4
    private static let upsertBatchSize = 1000
    private static let analysisBatchSize = 256
    /// Au-dessus de ce seuil on purge les caches et on souffle.
    private static let memorySoftLimitMB = 2200
    /// Au-dessus de ce seuil on s'interrompt proprement (la limite iOS est ~5 Go).
    private static let memoryHardLimitMB = 3200

    init(database: AppDatabase, thumbnails: ThumbnailStore) {
        self.database = database
        self.thumbnails = thumbnails
    }

    // L'écran est maintenu allumé globalement par RootView (isIdleTimerDisabled).
    func startScan(drive: DriveRecord, root: URL) {
        guard !isRunning else { return }
        scanTask = Task {
            await run(drive: drive, root: root)
        }
    }

    func cancel() {
        scanTask?.cancel()
    }

    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    /// Passage en arrière-plan : on demande à iOS le sursis maximal autorisé
    /// (~30 s) pour continuer à travailler, puis on s'arrête proprement à
    /// l'expiration (iOS tue toute app qui travaille au-delà — 0x8BADF00D).
    /// Le travail reprend automatiquement au retour au premier plan.
    func enteredBackground() {
        guard isRunning else { return }
        interruptedByBackground = true
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "yzphotos-scan") { [weak self] in
            Task { @MainActor [weak self] in
                self?.cancel()
                self?.endBackgroundTask()
            }
        }
    }

    func enteredForeground(drive: DriveRecord, root: URL) {
        endBackgroundTask()
        guard interruptedByBackground else { return }
        interruptedByBackground = false
        // Si le scan a survécu au sursis, il continue tout seul ;
        // s'il a été arrêté à l'expiration, on le relance (reprise gratuite).
        if !isRunning {
            startScan(drive: drive, root: root)
        }
    }

    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }

    // MARK: - Garde-fou mémoire

    /// Empreinte mémoire réelle du processus (phys_footprint), en Mo.
    nonisolated static func footprintMB() -> Int {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Int(info.phys_footprint / (1024 * 1024))
    }

    /// Purge + pause si la mémoire monte ; interruption propre si elle
    /// ne redescend pas (mieux qu'un kill système sans message).
    private func memoryCheckpoint() async throws {
        let footprint = Self.footprintMB()
        memoryFootprintMB = footprint
        guard footprint > Self.memorySoftLimitMB else { return }
        thumbnails.purgeMemoryCaches()
        try await Task.sleep(for: .seconds(2))
        let after = Self.footprintMB()
        memoryFootprintMB = after
        if after > Self.memoryHardLimitMB {
            throw ScanMemoryError()
        }
    }

    private func run(drive: DriveRecord, root: URL) async {
        let store = FileStore(database: database)
        let generation = drive.scanGeneration + 1
        filesSeen = 0
        bytesSeen = 0
        analyzedDone = 0
        photosAnalyzed = 0
        videosAnalyzed = 0
        screenshotsFound = 0
        currentPath = ""
        startedAt = Date()
        analysisStartedAt = nil

        do {
            // Passe 1 — énumération + upsert métadonnées.
            phase = .enumerating
            var batch: [FileMeta] = []
            var sinceLastPathUpdate = 0
            batch.reserveCapacity(Self.upsertBatchSize)
            for try await meta in FileEnumerator.enumerate(root: root) {
                batch.append(meta)
                bytesSeen += meta.sizeBytes
                sinceLastPathUpdate += 1
                if sinceLastPathUpdate >= 200 {
                    sinceLastPathUpdate = 0
                    currentPath = meta.relativePath
                }
                if batch.count >= Self.upsertBatchSize {
                    try await store.upsertBatch(batch, driveId: drive.id, generation: generation)
                    filesSeen += batch.count
                    batch.removeAll(keepingCapacity: true)
                    try await memoryCheckpoint()
                }
            }
            try await store.upsertBatch(batch, driveId: drive.id, generation: generation)
            filesSeen += batch.count
            try await store.pruneStale(driveId: drive.id, generation: generation)
            try await database.writer.write { db in
                try db.execute(
                    sql: "UPDATE drive SET scanGeneration = ? WHERE id = ?",
                    arguments: [generation, drive.id]
                )
            }

            // Passe 2 — analyse avec workers bornés.
            phase = .analyzing
            analysisStartedAt = Date()
            analyzedTotal = try await store.countPendingAnalysis(driveId: drive.id)
            try await analyzeLoop(store: store, driveId: drive.id, root: root)

            // La recherche de doublons n'est PAS lancée ici : elle se déclenche
            // à la demande depuis l'onglet Doublons (DuplicateRunController).
            try await database.writer.write { db in
                try db.execute(
                    sql: "UPDATE drive SET lastScanCompletedAt = ? WHERE id = ?",
                    arguments: [Date(), drive.id]
                )
            }
            phase = .finished
        } catch is CancellationError {
            phase = .idle
        } catch is DriveDisconnectedError {
            phase = .diskDisconnected
        } catch is ScanMemoryError {
            phase = .failed("Analyse interrompue pour protéger la mémoire de l'iPad. Relance-la : elle reprendra exactement où elle s'est arrêtée.")
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func analyzeLoop(store: FileStore, driveId: String, root: URL) async throws {
        let thumbnails = self.thumbnails
        while true {
            try Task.checkCancellation()
            let pending = try await store.pendingAnalysis(driveId: driveId, limit: Self.analysisBatchSize)
            if pending.isEmpty { break }

            let results = try await withThrowingTaskGroup(
                of: FileAnalysis.self,
                returning: [FileAnalysis].self
            ) { group in
                var iterator = pending.makeIterator()
                var inFlight = 0
                var collected: [FileAnalysis] = []
                collected.reserveCapacity(pending.count)

                while inFlight < Self.analysisWorkers, let file = iterator.next() {
                    currentPath = file.relativePath
                    group.addTask {
                        try await Self.analyze(file: file, root: root, thumbnails: thumbnails)
                    }
                    inFlight += 1
                }
                while inFlight > 0 {
                    guard let result = try await group.next() else { break }
                    inFlight -= 1
                    collected.append(result)
                    if let file = iterator.next() {
                        currentPath = file.relativePath
                        group.addTask {
                            try await Self.analyze(file: file, root: root, thumbnails: thumbnails)
                        }
                        inFlight += 1
                    }
                }
                return collected
            }

            try await store.applyAnalysisBatch(results)
            analyzedDone += results.count
            photosAnalyzed += pending.count(where: { $0.kind == .photo })
            videosAnalyzed += pending.count(where: { $0.kind == .video })
            screenshotsFound += results.count(where: \.isScreenshot)
            try await memoryCheckpoint()
        }
    }

    /// Analyse d'un fichier : hash partiel + miniature + dHash + métadonnées.
    /// Ne lève que si le disque a disparu (sinon le fichier est marqué analysé
    /// avec des champs NULL — pas de boucle infinie sur fichier corrompu).
    nonisolated private static func analyze(
        file: FileRecord,
        root: URL,
        thumbnails: ThumbnailStore
    ) async throws -> FileAnalysis {
        guard let id = file.id else {
            return FileAnalysis(fileId: -1, isScreenshot: false)
        }
        let url = root.appending(path: file.relativePath)
        var analysis = FileAnalysis(fileId: id, isScreenshot: false)

        do {
            analysis.partialHash = try HashWorker.partialHash(url: url, sizeBytes: file.sizeBytes)
        } catch {
            if (try? root.checkResourceIsReachable()) != true {
                throw DriveDisconnectedError()
            }
            return analysis
        }

        switch file.kind {
        case .photo:
            // autoreleasepool : ImageIO crée des objets temporaires qui ne sont
            // libérés qu'en fin de pool — indispensable sur 100k+ décodages.
            if let photo = autoreleasepool(invoking: { thumbnails.analyzePhoto(fileID: id, url: url) }) {
                analysis.pixelWidth = photo.pixelWidth
                analysis.pixelHeight = photo.pixelHeight
                analysis.captureDate = photo.captureDate
                analysis.dHash = photo.dHash.map { Int64(bitPattern: $0) }
                analysis.isScreenshot = MediaClassifier.isScreenshot(
                    ext: file.ext,
                    fileName: file.fileName,
                    pixelWidth: photo.pixelWidth,
                    pixelHeight: photo.pixelHeight,
                    hasCameraExif: photo.hasCameraExif
                )
            }
        case .video:
            let video = await thumbnails.analyzeVideo(fileID: id, url: url)
            analysis.pixelWidth = video.pixelWidth
            analysis.pixelHeight = video.pixelHeight
            analysis.durationSeconds = video.durationSeconds
        }
        return analysis
    }
}
