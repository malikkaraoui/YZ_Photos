import AMSMB2
import Foundation

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

    private func requireClient() throws -> SMB2Manager {
        guard let client else { throw SMBError.notConnected }
        return client
    }

    /// Contenu d'un dossier (chemin relatif au partage, `/` = racine).
    func list(_ path: String) async throws -> [Entry] {
        let client = try requireClient()
        let raw = try await client.contentsOfDirectory(atPath: Self.normalize(path))
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
        let client = try requireClient()
        return try await client.contents(atPath: Self.normalize(path))
    }

    /// Lecture d'une plage d'octets (pour les empreintes : on ne lit que les
    /// premiers Ko, pas tout le fichier — crucial sur le réseau).
    func readRange(_ path: String, offset: Int64, length: Int) async throws -> Data {
        let client = try requireClient()
        let upper = offset + Int64(length)
        return try await client.contents(atPath: Self.normalize(path), range: offset..<upper)
    }

    /// Écrit (ou crée) un fichier — utilisé pour les fichiers témoins de test.
    func write(_ data: Data, to path: String) async throws {
        let client = try requireClient()
        try await client.write(data: data, toPath: Self.normalize(path), progress: nil)
    }

    /// Déplacement (renommage) — c'est l'opération « mettre à la corbeille » :
    /// instantanée côté serveur, jamais une copie.
    func move(from: String, to: String) async throws {
        let client = try requireClient()
        try await client.moveItem(atPath: Self.normalize(from), toPath: Self.normalize(to))
    }

    func makeDirectory(_ path: String) async throws {
        let client = try requireClient()
        try await client.createDirectory(atPath: Self.normalize(path))
    }

    func remove(_ path: String) async throws {
        let client = try requireClient()
        try await client.removeFile(atPath: Self.normalize(path))
    }

    /// AMSMB2 attend des chemins relatifs au partage commençant par `/`.
    private static func normalize(_ path: String) -> String {
        if path.isEmpty || path == "/" { return "/" }
        return path.hasPrefix("/") ? path : "/" + path
    }
}
