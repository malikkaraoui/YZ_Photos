import Foundation

/// Couche d'accès unifiée au support de stockage : un disque USB local
/// (FileManager) **ou** un partage réseau SMB (client natif). Le scan, les
/// empreintes, les miniatures et la corbeille passent par cette interface, donc
/// le reste de l'app ne sait pas (et n'a pas besoin de savoir) si le disque est
/// branché en USB-C ou accessible en SMB.
///
/// Tous les chemins sont **relatifs à la racine choisie** du disque.
protocol MediaStore: Sendable {
    /// Énumère en streaming tous les fichiers média.
    func enumerate() -> AsyncThrowingStream<FileMeta, Error>
    /// Lit une plage d'octets (empreintes : on ne lit que la tête/queue).
    func readRange(_ relativePath: String, offset: Int64, length: Int) async throws -> Data
    /// Lit tout le fichier (miniature, hash complet).
    func readFull(_ relativePath: String) async throws -> Data
    /// Lit le fichier à son emplacement **courant** (gère la corbeille).
    func data(for file: FileRecord) async throws -> Data
    /// Déplace un fichier vers `.YZTrash`. Renvoie son nom dans la corbeille.
    func moveToTrash(file: FileRecord) async throws -> String
    func restoreFromTrash(file: FileRecord) async throws
    func deletePermanently(file: FileRecord) async throws
    /// Le disque est-il accessible maintenant ?
    func isReachable() async -> Bool
    /// La lecture vidéo native (AVPlayer) est-elle possible ? (USB oui ; SMB : ultérieurement)
    var supportsVideo: Bool { get }
    /// URL fichier locale si elle existe (USB) — sinon nil (réseau).
    func localURL(for file: FileRecord) -> URL?
}

// MARK: - Disque local (USB-C)

/// Implémentation locale : conserve très exactement le comportement d'origine
/// (FileManager + FileEnumerator + TrashManager).
struct LocalMediaStore: MediaStore {
    let root: URL

    var supportsVideo: Bool { true }

    func enumerate() -> AsyncThrowingStream<FileMeta, Error> {
        FileEnumerator.enumerate(root: root)
    }

    func readRange(_ relativePath: String, offset: Int64, length: Int) async throws -> Data {
        let handle = try FileHandle(forReadingFrom: root.appending(path: relativePath))
        defer { try? handle.close() }
        try handle.seek(toOffset: UInt64(max(0, offset)))
        return (try handle.read(upToCount: length)) ?? Data()
    }

    func readFull(_ relativePath: String) async throws -> Data {
        try Data(contentsOf: root.appending(path: relativePath))
    }

    func data(for file: FileRecord) async throws -> Data {
        try Data(contentsOf: file.currentURL(driveRoot: root))
    }

    func moveToTrash(file: FileRecord) async throws -> String {
        let root = self.root
        return try await Task.detached(priority: .userInitiated) {
            try TrashManager.moveToTrash(file: file, driveRoot: root)
        }.value
    }

    func restoreFromTrash(file: FileRecord) async throws {
        let root = self.root
        try await Task.detached(priority: .userInitiated) {
            try TrashManager.restoreFromTrash(file: file, driveRoot: root)
        }.value
    }

    func deletePermanently(file: FileRecord) async throws {
        let root = self.root
        try await Task.detached(priority: .userInitiated) {
            try TrashManager.deletePermanently(file: file, driveRoot: root)
        }.value
    }

    func isReachable() async -> Bool {
        (try? root.checkResourceIsReachable()) == true
    }

    func localURL(for file: FileRecord) -> URL? {
        file.currentURL(driveRoot: root)
    }
}

// MARK: - Disque réseau (SMB)

/// Implémentation réseau : lit/écrit via le client SMB natif (`SMBStore`).
/// `basePath` = dossier choisi dans le partage (« / » = tout le partage).
struct SMBMediaStore: MediaStore {
    let store: SMBStore
    let basePath: String

    var supportsVideo: Bool { false } // lecture vidéo réseau : phase ultérieure

    func localURL(for file: FileRecord) -> URL? { nil }

    func isReachable() async -> Bool {
        (try? await store.list(basePath)) != nil
    }

    func readRange(_ relativePath: String, offset: Int64, length: Int) async throws -> Data {
        try await store.readRange(Self.join(basePath, relativePath), offset: offset, length: length)
    }

    func readFull(_ relativePath: String) async throws -> Data {
        try await store.read(Self.join(basePath, relativePath))
    }

    func data(for file: FileRecord) async throws -> Data {
        let rel: String
        if file.status == .trashed, let trashName = file.trashName {
            rel = "\(TrashManager.trashDirName)/\(trashName)"
        } else {
            rel = file.relativePath
        }
        return try await store.read(Self.join(basePath, rel))
    }

    func enumerate() -> AsyncThrowingStream<FileMeta, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await walk(rel: "", sourceType: .folder, continuation: continuation, isRoot: true)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Dossiers système (Windows/macOS) ignorés : illisibles ou sans intérêt.
    private static let systemDirs: Set<String> = [
        "$recycle.bin", "system volume information", ".spotlight-v100",
        ".trashes", ".fseventsd", "found.000", ".documentrevisions-v100",
    ]

    private func isSkippableDir(_ name: String) -> Bool {
        name == TrashManager.trashDirName || Self.systemDirs.contains(name.lowercased())
    }

    /// Parcours récursif côté SMB (même logique que FileEnumerator : ignore
    /// `.YZTrash` + dossiers système, descend `originals/`+`Masters/` des paquets
    /// `.photoslibrary`).
    ///
    /// Résilient : un sous-dossier illisible (permissions, dossier système
    /// protégé) est **sauté** sans interrompre tout le scan — indispensable pour
    /// choisir un disque ENTIER (sa racine contient souvent `$RECYCLE.BIN` &
    /// consorts en lecture refusée). Seule la racine choisie, si illisible, lève.
    private func walk(
        rel: String,
        sourceType: SourceType,
        continuation: AsyncThrowingStream<FileMeta, Error>.Continuation,
        isRoot: Bool = false
    ) async throws {
        try Task.checkCancellation()
        let entries: [SMBStore.Entry]
        do {
            entries = try await store.list(Self.join(basePath, rel.isEmpty ? "/" : rel))
        } catch {
            if isRoot { throw error }   // racine choisie illisible → vraie erreur
            return                      // sous-dossier illisible → on saute
        }
        for entry in entries.sorted(by: { $0.name < $1.name }) {
            try Task.checkCancellation()
            let childRel = Self.join(rel, entry.name)
            let name = entry.name
            if entry.isDirectory {
                if name.lowercased().hasSuffix(".photoslibrary") {
                    let pkg = (try? await store.list(Self.join(basePath, childRel))) ?? []
                    for sub in pkg where ["originals", "masters"].contains(sub.name.lowercased()) && sub.isDirectory {
                        try await walk(rel: Self.join(childRel, sub.name), sourceType: .photosLibrary, continuation: continuation)
                    }
                } else if !isSkippableDir(name) {
                    try await walk(rel: childRel, sourceType: sourceType, continuation: continuation)
                }
                continue
            }
            guard let kind = FileEnumerator.mediaKind(forExtension: (name as NSString).pathExtension),
                  entry.size > 0 else { continue }
            continuation.yield(FileMeta(
                relativePath: childRel.hasPrefix("/") ? String(childRel.dropFirst()) : childRel,
                fileName: name,
                ext: (name as NSString).pathExtension.lowercased(),
                kind: kind,
                sourceType: sourceType,
                sizeBytes: entry.size,
                modifiedAt: entry.modified ?? .distantPast
            ).normalizedPath())
        }
    }

    // MARK: Corbeille (déplacement = renommage côté serveur, instantané)

    func moveToTrash(file: FileRecord) async throws -> String {
        guard let id = file.id else { throw TrashManager.TrashError.missingFileID }
        let trashName = "\(id)_\(file.fileName)"
        try? await store.makeDirectory(Self.join(basePath, TrashManager.trashDirName))
        try await store.move(
            from: Self.join(basePath, file.relativePath),
            to: Self.join(basePath, "\(TrashManager.trashDirName)/\(trashName)")
        )
        return trashName
    }

    func restoreFromTrash(file: FileRecord) async throws {
        guard let trashName = file.trashName else { return }
        try await store.move(
            from: Self.join(basePath, "\(TrashManager.trashDirName)/\(trashName)"),
            to: Self.join(basePath, file.relativePath)
        )
    }

    func deletePermanently(file: FileRecord) async throws {
        guard let trashName = file.trashName else { return }
        try await store.remove(Self.join(basePath, "\(TrashManager.trashDirName)/\(trashName)"))
    }

    /// Concatène deux segments de chemin SMB proprement (séparateur `/`).
    static func join(_ a: String, _ b: String) -> String {
        var base = a
        if base.isEmpty { base = "/" }
        if !base.hasPrefix("/") { base = "/" + base }
        var sub = b
        while sub.hasPrefix("/") { sub.removeFirst() }
        if sub.isEmpty { return base }
        return base.hasSuffix("/") ? base + sub : base + "/" + sub
    }
}

private extension FileMeta {
    /// Normalise le chemin en NFC (cohérence avec FileEnumerator).
    func normalizedPath() -> FileMeta {
        var copy = self
        copy.relativePath = relativePath.precomposedStringWithCanonicalMapping
        return copy
    }
}
