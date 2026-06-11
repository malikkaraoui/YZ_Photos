import Foundation
import GRDB

enum MediaKind: Int, Codable, Sendable {
    case photo = 0
    case video = 1
}

enum SourceType: Int, Codable, Sendable {
    case folder = 0
    case photosLibrary = 1
}

enum FileStatus: Int, Codable, Sendable {
    case untriaged = 0
    case kept = 1
    case trashed = 2
    case deleted = 3
}

enum DupKind: Int, Codable, Sendable {
    case exact = 1
    case near = 2
}

enum TriageActionKind: Int, Codable, Sendable {
    case keep = 1
    case trash = 2
}

struct DriveRecord: Codable, FetchableRecord, PersistableRecord, Sendable, Identifiable {
    static let databaseTableName = "drive"

    var id: String
    var name: String
    var bookmarkData: Data
    var totalBytes: Int64?
    var lastScanCompletedAt: Date?
    var scanGeneration: Int64
}

struct FileRecord: Codable, FetchableRecord, MutablePersistableRecord, Sendable, Identifiable, Hashable {
    static let databaseTableName = "file"

    var id: Int64?
    var driveId: String
    var relativePath: String
    var fileName: String
    var ext: String
    var kind: MediaKind
    var sourceType: SourceType
    var sizeBytes: Int64
    var modifiedAt: Date
    var captureDate: Date?
    var pixelWidth: Int?
    var pixelHeight: Int?
    var durationSeconds: Double?
    var partialHash: Data?
    var fullHash: Data?
    var dHash: Int64?
    var analyzedAt: Date?
    var isScreenshot: Bool
    var dupGroupId: Int64?
    var dupKind: DupKind?
    var status: FileStatus
    var trashName: String?
    var scanGeneration: Int64

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    /// URL absolue du fichier à son emplacement courant (chemin d'origine ou corbeille).
    func currentURL(driveRoot: URL) -> URL {
        if status == .trashed, let trashName {
            return driveRoot
                .appendingPathComponent(TrashManager.trashDirName, isDirectory: true)
                .appendingPathComponent(trashName)
        }
        return driveRoot.appending(path: relativePath)
    }
}

struct TriageActionRecord: Codable, FetchableRecord, MutablePersistableRecord, Sendable, Identifiable {
    static let databaseTableName = "triage_action"

    var id: Int64?
    var fileId: Int64
    var action: TriageActionKind
    var prevStatus: FileStatus
    var performedAt: Date

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
