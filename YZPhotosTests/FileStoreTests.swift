import GRDB
import XCTest
@testable import YZPhotos

final class FileStoreTests: XCTestCase {
    private var database: AppDatabase!
    private var store: FileStore!
    private let driveId = "TEST-DRIVE"

    override func setUpWithError() throws {
        database = try AppDatabase.inMemory()
        store = FileStore(database: database)
        try database.writer.write { db in
            try DriveRecord(
                id: "TEST-DRIVE", name: "Test", bookmarkData: Data(),
                totalBytes: nil, lastScanCompletedAt: nil, scanGeneration: 0
            ).insert(db)
        }
    }

    private func meta(_ path: String, size: Int64 = 1000, mtime: Date = Date(timeIntervalSince1970: 1_700_000_000)) -> FileMeta {
        FileMeta(
            relativePath: path,
            fileName: (path as NSString).lastPathComponent,
            ext: (path as NSString).pathExtension.lowercased(),
            kind: .photo,
            sourceType: .folder,
            sizeBytes: size,
            modifiedAt: mtime
        )
    }

    /// Upsert idempotent : re-scanner un fichier inchangé ne crée pas de doublon
    /// et préserve les résultats d'analyse (rescan incrémental quasi gratuit).
    func testUpsertUnchangedPreservesAnalysis() async throws {
        try await store.upsertBatch([meta("Photos/a.jpg")], driveId: driveId, generation: 1)

        // Simule l'analyse de la passe 2.
        let id = try await database.writer.read { db in
            try FileRecord.fetchOne(db)!.id!
        }
        try await store.applyAnalysisBatch([FileAnalysis(
            fileId: id, partialHash: Data([1, 2, 3]), pixelWidth: 100, pixelHeight: 50,
            durationSeconds: nil, captureDate: nil, dHash: 99, isScreenshot: true
        )])

        // Re-scan, fichier inchangé (mtime à +1 s : sous la tolérance exFAT de 2 s).
        try await store.upsertBatch(
            [meta("Photos/a.jpg", mtime: Date(timeIntervalSince1970: 1_700_000_001))],
            driveId: driveId, generation: 2
        )

        let records = try await database.writer.read { db in try FileRecord.fetchAll(db) }
        XCTAssertEqual(records.count, 1, "Pas de ligne dupliquée")
        XCTAssertEqual(records[0].scanGeneration, 2, "Génération mise à jour")
        XCTAssertEqual(records[0].partialHash, Data([1, 2, 3]), "Analyse préservée")
        XCTAssertEqual(records[0].dHash, 99)
        XCTAssertTrue(records[0].isScreenshot)
    }

    /// Fichier modifié (taille différente) : l'analyse est invalidée.
    func testUpsertChangedResetsAnalysis() async throws {
        try await store.upsertBatch([meta("a.jpg", size: 1000)], driveId: driveId, generation: 1)
        let id = try await database.writer.read { db in try FileRecord.fetchOne(db)!.id! }
        try await store.applyAnalysisBatch([FileAnalysis(
            fileId: id, partialHash: Data([9]), pixelWidth: nil, pixelHeight: nil,
            durationSeconds: nil, captureDate: nil, dHash: 5, isScreenshot: false
        )])

        try await store.upsertBatch([meta("a.jpg", size: 2000)], driveId: driveId, generation: 2)

        let record = try await database.writer.read { db in try FileRecord.fetchOne(db)! }
        XCTAssertEqual(record.sizeBytes, 2000)
        XCTAssertNil(record.partialHash, "Hash invalidé")
        XCTAssertNil(record.dHash)
        XCTAssertNil(record.analyzedAt, "Le fichier redevient à analyser")
        let pending = try await store.countPendingAnalysis(driveId: driveId)
        XCTAssertEqual(pending, 1)
    }

    /// L'onglet Dossiers : agrégats récursifs par sous-dossier, et scope par préfixe.
    func testFolderEntriesAndScope() async throws {
        try await store.upsertBatch([
            meta("Été 2024/plage/a.jpg", size: 100),
            meta("Été 2024/plage/b.jpg", size: 200),
            meta("Été 2024/c.jpg", size: 50),
            meta("Laura.photoslibrary/originals/0/x.heic", size: 1000),
            meta("racine.jpg", size: 10),
        ], driveId: driveId, generation: 1)

        let rootEntries = try await database.writer.read { [driveId] db in
            try Queries.folderEntries(db, driveId: driveId, prefix: "")
        }
        XCTAssertEqual(rootEntries.count, 3, "Été 2024, Laura.photoslibrary, fichiers racine")
        let ete = try XCTUnwrap(rootEntries.first { $0.name == "Été 2024" })
        XCTAssertEqual(ete.count, 3)
        XCTAssertEqual(ete.bytes, 350)
        XCTAssertEqual(ete.untriagedCount, 3)
        let library = try XCTUnwrap(rootEntries.first { $0.name == "Laura.photoslibrary" })
        XCTAssertTrue(library.isPhotosLibrary)
        XCTAssertEqual(library.count, 1)
        let rootFiles = try XCTUnwrap(rootEntries.first { $0.name == nil })
        XCTAssertEqual(rootFiles.count, 1)

        // Niveau suivant : accents français dans le préfixe (substr en caractères).
        let subEntries = try await database.writer.read { [driveId] db in
            try Queries.folderEntries(db, driveId: driveId, prefix: "Été 2024")
        }
        XCTAssertEqual(subEntries.first { $0.name == "plage" }?.count, 2)
        XCTAssertEqual(subEntries.first { $0.name == nil }?.count, 1)

        // Scope : le deck restreint à un dossier ne voit que ses fichiers.
        let scoped = try await database.writer.read { [driveId] db in
            try Queries.untriagedCount(db, driveId: driveId, filter: .all, scope: "Été 2024/plage")
        }
        XCTAssertEqual(scoped, 2)
    }

    /// Purge : un fichier disparu du disque est retiré, sauf s'il est en corbeille.
    func testPruneStaleKeepsTrashed() async throws {
        try await store.upsertBatch(
            [meta("gone.jpg"), meta("trashed.jpg"), meta("still-here.jpg")],
            driveId: driveId, generation: 1
        )
        try await database.writer.write { db in
            try db.execute(
                sql: "UPDATE file SET status = ?, trashName = 'x' WHERE relativePath = 'trashed.jpg'",
                arguments: [FileStatus.trashed.rawValue]
            )
        }
        // Génération 2 : seul still-here.jpg est revu sur le disque.
        try await store.upsertBatch([meta("still-here.jpg")], driveId: driveId, generation: 2)
        try await store.pruneStale(driveId: driveId, generation: 2)

        let paths = try await database.writer.read { db in
            try String.fetchAll(db, sql: "SELECT relativePath FROM file ORDER BY relativePath")
        }
        XCTAssertEqual(paths, ["still-here.jpg", "trashed.jpg"],
                       "Le fichier disparu est purgé, le fichier en corbeille survit")
    }
}
