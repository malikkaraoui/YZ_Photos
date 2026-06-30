import Foundation
import GRDB

/// Base SQLite unique de l'app (toutes les clés sont scopées par driveId).
/// WAL + synchronous NORMAL : optimisé pour des insertions par lots de 100k+ lignes.
final class AppDatabase: Sendable {
    let writer: any DatabaseWriter

    init(_ writer: any DatabaseWriter) throws {
        self.writer = writer
        try migrator.migrate(writer)
    }

    static func open() throws -> AppDatabase {
        let fm = FileManager.default
        let dir = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Database", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA synchronous = NORMAL")
        }
        let pool = try DatabasePool(path: dir.appendingPathComponent("yzphotos.sqlite").path, configuration: config)
        return try AppDatabase(pool)
    }

    static func inMemory() throws -> AppDatabase {
        try AppDatabase(DatabaseQueue())
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "drive") { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull()
                t.column("bookmarkData", .blob).notNull()
                t.column("totalBytes", .integer)
                t.column("lastScanCompletedAt", .datetime)
                t.column("scanGeneration", .integer).notNull().defaults(to: 0)
            }

            try db.create(table: "file") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("driveId", .text).notNull().references("drive", onDelete: .cascade)
                t.column("relativePath", .text).notNull()
                t.column("fileName", .text).notNull()
                t.column("ext", .text).notNull()
                t.column("kind", .integer).notNull()
                t.column("sourceType", .integer).notNull()
                t.column("sizeBytes", .integer).notNull()
                t.column("modifiedAt", .datetime).notNull()
                t.column("captureDate", .datetime)
                t.column("pixelWidth", .integer)
                t.column("pixelHeight", .integer)
                t.column("durationSeconds", .double)
                t.column("partialHash", .blob)
                t.column("fullHash", .blob)
                t.column("dHash", .integer)
                t.column("analyzedAt", .datetime)
                t.column("isScreenshot", .boolean).notNull().defaults(to: false)
                t.column("dupGroupId", .integer)
                t.column("dupKind", .integer)
                t.column("status", .integer).notNull().defaults(to: 0)
                t.column("trashName", .text)
                t.column("scanGeneration", .integer).notNull()
                t.uniqueKey(["driveId", "relativePath"])
            }
            try db.create(index: "idx_file_status", on: "file", columns: ["driveId", "status", "kind"])
            try db.create(index: "idx_file_size", on: "file", columns: ["driveId", "sizeBytes"])
            try db.create(index: "idx_file_partial", on: "file", columns: ["sizeBytes", "partialHash"])
            try db.create(index: "idx_file_dupgroup", on: "file", columns: ["dupGroupId"])

            try db.create(table: "triage_action") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("fileId", .integer).notNull().references("file", onDelete: .cascade)
                t.column("action", .integer).notNull()
                t.column("prevStatus", .integer).notNull()
                t.column("performedAt", .datetime).notNull()
            }
        }

        migrator.registerMigration("v2-deck-path-index") { db in
            // Index couvrant la requête du deck (WHERE driveId+status ORDER BY relativePath).
            // Sans lui, le tri du deck — et surtout la pagination par offset du mode
            // « aléatoire » — devait trier des dizaines de milliers de lignes à chaque
            // rechargement (lourd, le téléphone chauffait). Avec l'index : index scan
            // direct + saut d'offset instantané.
            try db.create(index: "idx_file_deck_path", on: "file",
                          columns: ["driveId", "status", "relativePath"], ifNotExists: true)
        }

        return migrator
    }
}
