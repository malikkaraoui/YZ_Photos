import Foundation

/// Opérations fichier de la corbeille différée : `.YZTrash/` à la racine du SSD.
/// Move same-volume = rename instantané, aucune copie de données.
/// Les mises à jour de la base sont faites par TriageService.
struct TrashManager: Sendable {
    static let trashDirName = ".YZTrash"

    enum TrashError: LocalizedError {
        case missingFileID

        var errorDescription: String? {
            "Fichier sans identifiant en base."
        }
    }

    private nonisolated(unsafe) static let fm = FileManager.default

    static func trashDirURL(driveRoot: URL) -> URL {
        driveRoot.appendingPathComponent(trashDirName, isDirectory: true)
    }

    /// Déplace le fichier vers .YZTrash. Renvoie le nom dans la corbeille
    /// (préfixé par l'id en base : insensible aux collisions de noms).
    static func moveToTrash(file: FileRecord, driveRoot: URL) throws -> String {
        guard let id = file.id else { throw TrashError.missingFileID }
        let trashDir = trashDirURL(driveRoot: driveRoot)
        try fm.createDirectory(at: trashDir, withIntermediateDirectories: true)
        let trashName = "\(id)_\(file.fileName)"
        let source = driveRoot.appending(path: file.relativePath)
        let destination = trashDir.appendingPathComponent(trashName)
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.moveItem(at: source, to: destination)
        return trashName
    }

    /// Restaure un fichier de la corbeille vers son chemin d'origine.
    static func restoreFromTrash(file: FileRecord, driveRoot: URL) throws {
        guard let trashName = file.trashName else { return }
        let source = trashDirURL(driveRoot: driveRoot).appendingPathComponent(trashName)
        let destination = driveRoot.appending(path: file.relativePath)
        try fm.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fm.moveItem(at: source, to: destination)
    }

    /// Suppression définitive d'un fichier de la corbeille.
    static func deletePermanently(file: FileRecord, driveRoot: URL) throws {
        guard let trashName = file.trashName else { return }
        let url = trashDirURL(driveRoot: driveRoot).appendingPathComponent(trashName)
        if fm.fileExists(atPath: url.path) {
            try fm.removeItem(at: url)
        }
    }
}
