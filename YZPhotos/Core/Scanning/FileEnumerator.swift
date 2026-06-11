import Foundation

/// Énumération profonde du disque (passe 1, mono-tâche : DirectoryEnumerator
/// n'est pas thread-safe). Détecte les paquets `.photoslibrary` et n'indexe que
/// leur dossier interne `originals/` (ou `Masters/` pour les vieilles bibliothèques).
enum FileEnumerator {
    static let photoExtensions: Set<String> = [
        "jpg", "jpeg", "heic", "heif", "png", "gif", "tiff", "tif",
        "bmp", "webp", "dng", "raw", "cr2", "cr3", "nef", "arw", "jp2", "avif",
    ]
    static let videoExtensions: Set<String> = [
        "mov", "mp4", "m4v", "avi", "mts", "m2ts", "3gp", "mkv", "webm", "mpg", "mpeg",
    ]

    static func mediaKind(forExtension ext: String) -> MediaKind? {
        let lower = ext.lowercased()
        if photoExtensions.contains(lower) { return .photo }
        if videoExtensions.contains(lower) { return .video }
        return nil
    }

    private static let resourceKeys: [URLResourceKey] = [
        .isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .nameKey,
    ]

    /// Énumère tous les fichiers média sous `root`, en streaming.
    static func enumerate(root: URL) -> AsyncThrowingStream<FileMeta, Error> {
        AsyncThrowingStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                do {
                    try walk(directory: root, root: root, sourceType: .folder) { meta in
                        continuation.yield(meta)
                        return !Task.isCancelled
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Parcours récursif. `emit` renvoie false pour interrompre (annulation).
    private static func walk(
        directory: URL,
        root: URL,
        sourceType: SourceType,
        emit: (FileMeta) -> Bool
    ) throws {
        let fm = FileManager.default
        let children = try fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        )
        for child in children.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let values = try? child.resourceValues(forKeys: Set(resourceKeys))
            let isDirectory = values?.isDirectory ?? false
            let name = child.lastPathComponent

            if isDirectory {
                if name.lowercased().hasSuffix(".photoslibrary") {
                    // Paquet Photos.app : on ne descend que dans originals/ et Masters/.
                    for originals in ["originals", "Masters"] {
                        let sub = child.appendingPathComponent(originals, isDirectory: true)
                        var isDir: ObjCBool = false
                        if fm.fileExists(atPath: sub.path, isDirectory: &isDir), isDir.boolValue {
                            try walk(directory: sub, root: root, sourceType: .photosLibrary, emit: emit)
                        }
                    }
                } else if name != TrashManager.trashDirName {
                    try walk(directory: child, root: root, sourceType: sourceType, emit: emit)
                }
                continue
            }

            guard let kind = mediaKind(forExtension: child.pathExtension) else { continue }
            let size = Int64(values?.fileSize ?? 0)
            guard size > 0 else { continue }
            let meta = FileMeta(
                relativePath: relativePath(of: child, from: root),
                fileName: name,
                ext: child.pathExtension.lowercased(),
                kind: kind,
                sourceType: sourceType,
                sizeBytes: size,
                modifiedAt: values?.contentModificationDate ?? .distantPast
            )
            if !emit(meta) { return }
        }
    }

    /// Chemin relatif à la racine du disque, normalisé NFC (exFAT peut mélanger
    /// NFC/NFD avec les accents français — la clé en base doit être stable).
    static func relativePath(of url: URL, from root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let filePath = url.standardizedFileURL.path
        var relative = filePath
        if filePath.hasPrefix(rootPath) {
            relative = String(filePath.dropFirst(rootPath.count))
            if relative.hasPrefix("/") { relative.removeFirst() }
        }
        return relative.precomposedStringWithCanonicalMapping
    }
}
