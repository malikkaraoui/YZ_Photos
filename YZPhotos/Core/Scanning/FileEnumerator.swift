import Foundation

/// Énumération profonde du disque (passe 1, mono-tâche : DirectoryEnumerator
/// n'est pas thread-safe). Détecte les paquets `.photoslibrary` et n'indexe que
/// leur dossier interne `originals/` (ou `Masters/` pour les vieilles bibliothèques).
enum FileEnumerator {
    static let photoExtensions: Set<String> = [
        "jpg", "jpeg", "jfif", "heic", "heif", "png", "gif", "tiff", "tif",
        "bmp", "webp", "avif", "jp2",
        // RAW courants (tous fabricants)
        "dng", "raw", "cr2", "cr3", "nef", "nrw", "arw", "sr2", "raf",
        "orf", "rw2", "pef", "srw", "x3f", "erf", "kdc",
    ]
    static let videoExtensions: Set<String> = [
        "mov", "mp4", "m4v", "avi", "mts", "m2ts", "3gp", "3g2", "mkv",
        "webm", "mpg", "mpeg", "m2v", "ts", "vob", "wmv", "flv", "ogv", "mxf",
    ]

    static func mediaKind(forExtension ext: String) -> MediaKind? {
        let lower = ext.lowercased()
        if photoExtensions.contains(lower) { return .photo }
        if videoExtensions.contains(lower) { return .video }
        return nil
    }

    /// Dossiers entièrement ignorés pendant le parcours : système (Windows/macOS)
    /// + dev/build/dépendances. On n'y descend même pas — ça évite de ramper dans
    /// des `node_modules`/builds (lent sur le réseau) et garde le scan focalisé
    /// sur les photos/vidéos. (Les fichiers non-média sont de toute façon filtrés
    /// par extension ; ceci est une optimisation de parcours.)
    static let skippedDirectoryNames: Set<String> = [
        // Système
        "$recycle.bin", "system volume information", ".spotlight-v100",
        ".trashes", ".fseventsd", "found.000", ".documentrevisions-v100",
        ".temporaryitems", ".apdisk",
        // Dev / build / dépendances
        "node_modules", ".git", ".svn", ".hg", "__pycache__", ".gradle",
        ".cache", ".next", ".nuxt", "bower_components", "pods", "deriveddata",
        "build", "dist", "target", ".venv", "venv", ".idea", ".vscode",
        "cmakefiles", ".terraform", ".dart_tool", ".pub-cache",
    ]

    /// Faut-il ignorer ce dossier ? (insensible à la casse, + `.YZTrash`)
    static func shouldSkipDirectory(_ name: String) -> Bool {
        name == TrashManager.trashDirName || skippedDirectoryNames.contains(name.lowercased())
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
        let children = try contents(of: directory)
        for child in children.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let values = try? child.resourceValues(forKeys: Set(resourceKeys))
            let isDirectory = values?.isDirectory ?? false
            let name = child.lastPathComponent

            if isDirectory {
                if name.lowercased().hasSuffix(".photoslibrary") {
                    // Paquet Photos.app : on ne descend que dans originals/ et Masters/.
                    // (Détection par énumération coordonnée, pas par `fileExists`
                    //  POSIX — qui ne marche pas sur un File Provider réseau.)
                    let pkg = (try? contents(of: child)) ?? []
                    for sub in pkg where ["originals", "masters"].contains(sub.lastPathComponent.lowercased()) {
                        if (try? sub.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                            try walk(directory: sub, root: root, sourceType: .photosLibrary, emit: emit)
                        }
                    }
                } else if !shouldSkipDirectory(name) {
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

    /// Liste le contenu d'un dossier via une **lecture coordonnée**
    /// (`NSFileCoordinator`). Indispensable pour un partage réseau exposé par un
    /// File Provider (SMB via Fichiers, ex. Freebox/NAS) : sans coordination, le
    /// provider ne matérialise pas le listing et `contentsOfDirectory` renvoie
    /// vide. Sur un volume local (USB-C) la coordination est transparente.
    private static func contents(of directory: URL) throws -> [URL] {
        let fm = FileManager.default
        let coordinator = NSFileCoordinator()
        var coordError: NSError?
        var result: [URL] = []
        var readError: Error?
        coordinator.coordinate(readingItemAt: directory, options: [], error: &coordError) { url in
            do {
                result = try fm.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: resourceKeys,
                    options: [.skipsHiddenFiles]
                )
            } catch {
                readError = error
            }
        }
        if let coordError { throw coordError }
        if let readError { throw readError }
        return result
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
