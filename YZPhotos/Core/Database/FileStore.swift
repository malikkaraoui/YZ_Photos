import Foundation
import GRDB

/// Métadonnées d'un fichier produites par l'énumérateur (passe 1).
struct FileMeta: Sendable {
    var relativePath: String
    var fileName: String
    var ext: String
    var kind: MediaKind
    var sourceType: SourceType
    var sizeBytes: Int64
    var modifiedAt: Date
}

/// Résultat de l'analyse d'un fichier (passe 2).
struct FileAnalysis: Sendable {
    var fileId: Int64
    var partialHash: Data?
    var pixelWidth: Int?
    var pixelHeight: Int?
    var durationSeconds: Double?
    var captureDate: Date?
    var dHash: Int64?
    var isScreenshot: Bool
}

/// Écritures en base du pipeline de scan : upserts par lots, idempotents.
struct FileStore: Sendable {
    let database: AppDatabase

    /// exFAT a une granularité de mtime de 2 s : tolérance dans la détection de changement.
    static let mtimeTolerance: TimeInterval = 2.0

    /// Upsert d'un lot de métadonnées (passe 1).
    /// Si la ligne existe avec la même taille et le même mtime (±2 s), seul
    /// scanGeneration est mis à jour (hashes et analyse conservés).
    /// Sinon la ligne est (ré)initialisée : hashes/analyse à NULL → la passe 2 la retraite.
    func upsertBatch(_ metas: [FileMeta], driveId: String, generation: Int64) async throws {
        try await database.writer.write { db in
            for meta in metas {
                let existing = try FileRecord
                    .filter(Column("driveId") == driveId)
                    .filter(Column("relativePath") == meta.relativePath)
                    .fetchOne(db)
                if var record = existing {
                    let unchanged = record.sizeBytes == meta.sizeBytes
                        && abs(record.modifiedAt.timeIntervalSince(meta.modifiedAt)) <= Self.mtimeTolerance
                    record.scanGeneration = generation
                    if !unchanged {
                        record.sizeBytes = meta.sizeBytes
                        record.modifiedAt = meta.modifiedAt
                        record.partialHash = nil
                        record.fullHash = nil
                        record.dHash = nil
                        record.analyzedAt = nil
                        record.dupGroupId = nil
                        record.dupKind = nil
                    }
                    try record.update(db)
                } else {
                    var record = FileRecord(
                        id: nil,
                        driveId: driveId,
                        relativePath: meta.relativePath,
                        fileName: meta.fileName,
                        ext: meta.ext,
                        kind: meta.kind,
                        sourceType: meta.sourceType,
                        sizeBytes: meta.sizeBytes,
                        modifiedAt: meta.modifiedAt,
                        captureDate: nil,
                        pixelWidth: nil,
                        pixelHeight: nil,
                        durationSeconds: nil,
                        partialHash: nil,
                        fullHash: nil,
                        dHash: nil,
                        analyzedAt: nil,
                        isScreenshot: false,
                        dupGroupId: nil,
                        dupKind: nil,
                        status: .untriaged,
                        trashName: nil,
                        scanGeneration: generation
                    )
                    try record.insert(db)
                }
            }
        }
    }

    /// Purge des lignes orphelines après la passe 1 : fichiers disparus du disque
    /// (génération périmée), sauf ceux en corbeille ou déjà supprimés.
    func pruneStale(driveId: String, generation: Int64) async throws {
        try await database.writer.write { db in
            try db.execute(sql: """
                DELETE FROM file
                WHERE driveId = ? AND scanGeneration < ? AND status IN (0, 1)
                """, arguments: [driveId, generation])
        }
    }

    /// Supprime de la base les fichiers dont l'extension n'est plus reconnue comme
    /// média (ex. `.ts` TypeScript indexés à tort) — sans toucher au disque.
    /// Idempotent et instantané (DB seule). Renvoie le nombre purgé.
    @discardableResult
    func purgeNonMedia(driveId: String) async throws -> Int {
        let mediaExts = Array(FileEnumerator.photoExtensions.union(FileEnumerator.videoExtensions))
        return try await database.writer.write { db in
            let marks = databaseQuestionMarks(count: mediaExts.count)
            let args = StatementArguments([driveId] + mediaExts)
            let toDelete = try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM file
                WHERE driveId = ? AND status IN (0, 1) AND LOWER(ext) NOT IN (\(marks))
                """, arguments: args) ?? 0
            try db.execute(sql: """
                DELETE FROM file
                WHERE driveId = ? AND status IN (0, 1) AND LOWER(ext) NOT IN (\(marks))
                """, arguments: args)
            return toDelete
        }
    }

    /// Fichiers restant à analyser (passe 2). Idempotent : le travail est défini
    /// par l'état de la base, une reprise après crash reprend où on en était.
    /// Critère : analyzedAt seul — un fichier illisible garde partialHash NULL
    /// mais ne doit pas être retraité en boucle.
    func pendingAnalysis(driveId: String, limit: Int) async throws -> [FileRecord] {
        try await database.writer.read { db in
            try FileRecord
                .filter(Column("driveId") == driveId)
                .filter(Column("analyzedAt") == nil)
                .filter(Column("status") != FileStatus.deleted.rawValue)
                .order(Column("id"))
                .limit(limit)
                .fetchAll(db)
        }
    }

    func countPendingAnalysis(driveId: String) async throws -> Int {
        try await database.writer.read { db in
            try FileRecord
                .filter(Column("driveId") == driveId)
                .filter(Column("analyzedAt") == nil)
                .filter(Column("status") != FileStatus.deleted.rawValue)
                .fetchCount(db)
        }
    }

    /// Écriture par lots des résultats d'analyse (passe 2).
    func applyAnalysisBatch(_ batch: [FileAnalysis]) async throws {
        let now = Date()
        try await database.writer.write { db in
            for a in batch {
                try db.execute(sql: """
                    UPDATE file SET
                        partialHash = ?, pixelWidth = ?, pixelHeight = ?,
                        durationSeconds = ?, captureDate = ?, dHash = ?,
                        isScreenshot = ?, analyzedAt = ?
                    WHERE id = ?
                    """, arguments: [
                        a.partialHash, a.pixelWidth, a.pixelHeight,
                        a.durationSeconds, a.captureDate, a.dHash,
                        a.isScreenshot, now, a.fileId,
                    ])
            }
        }
    }
}
