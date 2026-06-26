import AMSMB2
import CryptoKit
import Foundation

/// Accumulateur SHA-256 thread-safe : alimenté chunk par chunk depuis le callback
/// de lecture d'AMSMB2 (qui s'exécute sur sa file interne). `@unchecked Sendable`
/// + verrou car le callback est `@Sendable`.
private final class StreamingSHA256: @unchecked Sendable {
    private var hasher = SHA256()
    private let lock = NSLock()
    func update(_ data: Data) {
        lock.lock(); defer { lock.unlock() }
        hasher.update(data: data)
    }
    func finalize() -> Data {
        lock.lock(); defer { lock.unlock() }
        return Data(hasher.finalize())
    }
}

/// Erreurs du client SMB natif, avec messages clairs.
enum SMBError: LocalizedError {
    case badHost
    case initFailed
    case notConnected

    var errorDescription: String? {
        switch self {
        case .badHost: "Adresse de serveur invalide."
        case .initFailed: "Impossible d'initialiser la connexion SMB."
        case .notConnected: "Pas connecté au partage."
        }
    }
}

/// Client SMB2/3 **natif** (au-dessus d'AMSMB2 → libsmb2), totalement indépendant
/// de l'app Fichiers d'iOS. C'est « notre propre SMB » : connexion directe avec
/// identifiants, lecture **et** écriture (déplacement → corbeille).
///
/// `actor` : libsmb2 sérialise une connexion ; on isole tous les appels.
actor SMBStore {
    struct Entry: Sendable, Hashable {
        let name: String
        let isDirectory: Bool
        let size: Int64
        let modified: Date?
    }

    let host: String
    let share: String
    private let user: String
    private let password: String
    private var client: SMB2Manager?

    init(host: String, share: String, user: String, password: String) {
        self.host = host
        self.share = share
        self.user = user
        self.password = password
    }

    private static func makeClient(host: String, user: String, password: String) throws -> SMB2Manager {
        guard let url = URL(string: "smb://\(host)") else { throw SMBError.badHost }
        let credential = URLCredential(user: user, password: password, persistence: .forSession)
        guard let client = SMB2Manager(url: url, credential: credential) else { throw SMBError.initFailed }
        return client
    }

    /// Liste les partages exposés par un serveur (ex. `freebox`, `Malik`, `T7`),
    /// sans monter de partage précis.
    static func listShares(host: String, user: String, password: String) async throws -> [String] {
        let client = try makeClient(host: host, user: user, password: password)
        return try await client.listShares().map(\.name)
    }

    /// Monte le partage et garde la connexion ouverte.
    func connect() async throws {
        let client = try Self.makeClient(host: host, user: user, password: password)
        try await client.connectShare(name: share)
        self.client = client
    }

    func disconnect() async {
        try? await client?.disconnectShare()
        client = nil
    }

    /// Recycle la connexion : détruit le contexte libsmb2 courant et en recrée un
    /// neuf. C'est le SEUL moyen de LIBÉRER la mémoire que libsmb2 accumule au fil
    /// de milliers de lectures (chaque lecture rouvre le fichier ; le contexte
    /// garde des tampons → l'empreinte gonfle de quelques Mo par lecture sans
    /// jamais retomber, jusqu'au jetsam). À appeler périodiquement pendant une
    /// passe très gourmande en lectures (recherche de doublons).
    func recycle() async {
        try? await client?.disconnectShare()
        client = nil
        try? await reestablish()
    }

    private func requireClient() throws -> SMB2Manager {
        guard let client else { throw SMBError.notConnected }
        return client
    }

    /// Rétablit la connexion (nouveau contexte libsmb2 + remontage du partage).
    private func reestablish() async throws {
        client = nil
        let fresh = try Self.makeClient(host: host, user: user, password: password)
        try await fresh.connectShare(name: share)
        client = fresh
    }

    /// Exécute une opération SMB ; si elle échoue à cause de la **connexion**
    /// (session recyclée, time-out réseau), **reconnecte et réessaie UNE fois**.
    /// En revanche, une erreur **liée au chemin** (permission refusée, dossier
    /// invalide…) est rejetée immédiatement SANS reconnexion : reconstruire la
    /// connexion n'y changerait rien et provoquerait des tempêtes de
    /// reconnexions qui figeraient le scan d'un disque entier (dossiers système
    /// / privés à la racine). L'appelant (énumération) saute alors ce dossier.
    private func withReconnect<T>(_ op: (SMB2Manager) async throws -> T) async throws -> T {
        let current = try requireClient()
        do {
            return try await op(current)
        } catch {
            if Self.isPathError(error) { throw error }
            try await reestablish()
            let fresh = try requireClient()
            return try await op(fresh)
        }
    }

    /// Erreur locale au fichier/dossier (et non à la connexion) : permission,
    /// inexistant, argument invalide, déjà présent, etc. → ne pas reconnecter.
    nonisolated static func isPathError(_ error: Error) -> Bool {
        let pathCodes: Set<Int> = [
            Int(EPERM), Int(ENOENT), Int(EACCES), Int(EEXIST),
            Int(ENOTDIR), Int(EISDIR), Int(EINVAL), Int(ENAMETOOLONG),
        ]
        return pathCodes.contains((error as NSError).code)
    }

    /// Contenu d'un dossier (chemin relatif au partage, `/` = racine).
    func list(_ path: String) async throws -> [Entry] {
        let raw = try await withReconnect { try await $0.contentsOfDirectory(atPath: Self.normalize(path)) }
        return raw.compactMap { item in
            let name = item[.nameKey] as? String ?? ""
            guard !name.isEmpty, name != ".", name != ".." else { return nil }
            return Entry(
                name: name,
                isDirectory: (item[.fileResourceTypeKey] as? URLFileResourceType) == .directory,
                size: Int64(item[.fileSizeKey] as? Int ?? 0),
                modified: item[.contentModificationDateKey] as? Date
            )
        }
    }

    /// Lecture complète d'un fichier.
    func read(_ path: String) async throws -> Data {
        try await withReconnect { try await $0.contents(atPath: Self.normalize(path)) }
    }

    /// SHA-256 complet d'un fichier, lu en STREAMING par chunks via le callback
    /// d'AMSMB2. Crucial : `contents(atPath:)` (lecture en un bloc) passe par
    /// `OutputStream.toMemory()` qui RETIENT toute la mémoire lue (~taille du
    /// fichier par lecture, jamais libérée → jetsam pendant les doublons). Ici on
    /// hache chunk par chunk : la mémoire reste plate quelle que soit la taille.
    func fullHashStreaming(_ path: String) async throws -> Data {
        try await withReconnect { client in
            let acc = StreamingSHA256()
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
                client.contents(
                    atPath: Self.normalize(path),
                    fetchedData: { _, _, data in
                        acc.update(data)
                        return true
                    },
                    completionHandler: { error in
                        if let error { cont.resume(throwing: error) }
                        else { cont.resume() }
                    }
                )
            }
            return acc.finalize()
        }
    }

    /// Capacité du système de fichiers du partage (total / libre), en octets.
    func capacity() async throws -> (total: Int64, free: Int64) {
        try await withReconnect { client in
            let attrs = try await client.attributesOfFileSystem(forPath: "/")
            let total = (attrs[.systemSize] as? NSNumber)?.int64Value ?? 0
            let free = (attrs[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
            return (total, free)
        }
    }

    /// Lecture d'une plage d'octets (pour les empreintes : on ne lit que les
    /// premiers Ko, pas tout le fichier — crucial sur le réseau).
    func readRange(_ path: String, offset: Int64, length: Int) async throws -> Data {
        let upper = offset + Int64(length)
        return try await withReconnect { try await $0.contents(atPath: Self.normalize(path), range: offset..<upper) }
    }

    /// Écrit (ou crée) un fichier — utilisé pour les fichiers témoins de test.
    func write(_ data: Data, to path: String) async throws {
        try await withReconnect { try await $0.write(data: data, toPath: Self.normalize(path), progress: nil) }
    }

    /// Déplacement (renommage) — c'est l'opération « mettre à la corbeille » :
    /// instantanée côté serveur, jamais une copie.
    func move(from: String, to: String) async throws {
        try await withReconnect { try await $0.moveItem(atPath: Self.normalize(from), toPath: Self.normalize(to)) }
    }

    func makeDirectory(_ path: String) async throws {
        try await withReconnect { try await $0.createDirectory(atPath: Self.normalize(path)) }
    }

    func remove(_ path: String) async throws {
        try await withReconnect { try await $0.removeFile(atPath: Self.normalize(path)) }
    }

    /// AMSMB2 attend des chemins relatifs au partage commençant par `/`.
    private static func normalize(_ path: String) -> String {
        if path.isEmpty || path == "/" { return "/" }
        return path.hasPrefix("/") ? path : "/" + path
    }
}
