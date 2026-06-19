import Foundation
import GRDB
import Observation

/// Erreurs d'accès au disque, avec messages clairs pour l'utilisateur
/// (USB-C comme réseau SMB via Freebox/NAS).
enum DriveAccessError: LocalizedError {
    case accessDenied(String)

    var errorDescription: String? {
        switch self {
        case .accessDenied(let name):
            return "iOS a refusé l'accès à « \(name) ». Rouvre le dossier depuis l'app Fichiers (USB-C ou serveur SMB), puis re-sélectionne-le ici."
        }
    }
}

/// Info de connexion d'un disque réseau, sérialisée dans `DriveRecord.bookmarkData`
/// (les disques USB y stockent un bookmark security-scoped brut ; les disques
/// réseau y stockent ce JSON — on les distingue en tentant de le décoder).
/// Le mot de passe n'est JAMAIS ici : il vit dans le trousseau (Keychain).
enum DriveConnection: Codable, Sendable {
    case smb(host: String, share: String, path: String, user: String)
}

/// Gère le cycle de vie de l'accès au SSD : sélection via le picker,
/// bookmarks security-scoped persistés en base, reconnexion au lancement,
/// détection de déconnexion.
@MainActor
@Observable
final class DriveAccessManager {
    enum State {
        case noDrive                     // aucun disque connu : afficher le picker
        case disconnected(DriveRecord)   // disque connu mais débranché
        case connected(DriveRecord, URL) // accès actif (scope démarré)
    }

    private(set) var state: State = .noDrive
    private(set) var knownDrives: [DriveRecord] = []
    /// Couche d'accès du disque branché (USB → local, réseau → SMB).
    private(set) var currentStore: MediaStore?

    private let database: AppDatabase
    private var accessedURL: URL?

    init(database: AppDatabase) {
        self.database = database
    }

    var connectedRoot: URL? {
        if case .connected(_, let url) = state { return url }
        return nil
    }

    var connectedDrive: DriveRecord? {
        if case .connected(let drive, _) = state { return drive }
        return nil
    }

    /// Au lancement : on ne reconnecte volontairement AUCUN disque
    /// automatiquement. On charge seulement la liste des disques connus (pour
    /// les Réglages et le basculement) et on laisse l'utilisateur rechoisir
    /// explicitement quel disque brancher à chaque ouverture de l'app.
    func restoreOnLaunch() async {
        do {
            knownDrives = try await database.writer.read { db in
                try DriveRecord.order(Column("lastScanCompletedAt").desc).fetchAll(db)
            }
        } catch {
            knownDrives = []
        }
        state = .noDrive
    }

    /// L'utilisateur vient de choisir la racine du disque dans le picker.
    func attach(pickedURL: URL) throws -> DriveRecord {
        detach()
        guard pickedURL.startAccessingSecurityScopedResource() else {
            throw DriveAccessError.accessDenied(pickedURL.lastPathComponent)
        }
        let identity = DriveIdentity.identify(url: pickedURL)
        // Le bookmark ne sert qu'à *reconnecter* au prochain lancement : il n'est
        // pas requis pour utiliser le disque dans la session courante. Sur un
        // volume réseau (SMB via Freebox/NAS), sa création échoue souvent
        // (NSFileReadNoSuchFileError) alors que l'accès live fonctionne — on le
        // rend donc best-effort plutôt que bloquant. Un bookmark vide signifie
        // simplement « pas de reconnexion automatique » : l'app redemandera le
        // disque, ce qui est déjà son comportement par défaut.
        let bookmark = (try? pickedURL.bookmarkData()) ?? Data()
        let drive = DriveRecord(
            id: identity.id,
            name: identity.name,
            bookmarkData: bookmark,
            totalBytes: identity.totalBytes,
            lastScanCompletedAt: nil,
            scanGeneration: existingGeneration(for: identity.id)
        )
        let saved: DriveRecord = try database.writer.write { db in
            // Conserve la génération et la date de scan si le disque est déjà connu.
            if let existing = try DriveRecord.fetchOne(db, key: identity.id) {
                var updated = existing
                updated.name = identity.name
                updated.bookmarkData = bookmark
                updated.totalBytes = identity.totalBytes
                try updated.update(db)
                return updated
            } else {
                try drive.insert(db)
                return drive
            }
        }
        accessedURL = pickedURL
        currentStore = LocalMediaStore(root: pickedURL)
        state = .connected(saved, pickedURL)
        if !knownDrives.contains(where: { $0.id == saved.id }) {
            knownDrives.append(saved)
        }
        return saved
    }

    /// Branche un disque **réseau SMB** : connexion directe (client natif),
    /// persistance de la fiche + de l'info de connexion, mot de passe au trousseau.
    func attachSMB(host: String, share: String, path: String, user: String, password: String) async throws -> DriveRecord {
        detach()
        let basePath = path.isEmpty ? "/" : path
        let smb = SMBStore(host: host, share: share, user: user, password: password)
        try await smb.connect()
        let media = SMBMediaStore(store: smb, basePath: basePath)

        let id = "smb:\(host):\(share):\(basePath)"
        let name = (basePath == "/" ? share : (basePath as NSString).lastPathComponent)
        let connection = DriveConnection.smb(host: host, share: share, path: basePath, user: user)
        let bookmark = (try? JSONEncoder().encode(connection)) ?? Data()
        Keychain.set(password, account: id)

        let drive = DriveRecord(
            id: id, name: name, bookmarkData: bookmark, totalBytes: nil,
            lastScanCompletedAt: nil, scanGeneration: existingGeneration(for: id)
        )
        let saved: DriveRecord = try await database.writer.write { db in
            if let existing = try DriveRecord.fetchOne(db, key: id) {
                var updated = existing
                updated.name = name
                updated.bookmarkData = bookmark
                try updated.update(db)
                return updated
            } else {
                try drive.insert(db)
                return drive
            }
        }
        currentStore = media
        state = .connected(saved, URL(string: "smb://\(host)/\(share)")!)
        if !knownDrives.contains(where: { $0.id == saved.id }) {
            knownDrives.append(saved)
        }
        return saved
    }

    /// Tente de rouvrir l'accès via le bookmark persisté. Renvoie false si le
    /// disque n'est pas branché ou si le bookmark est périmé.
    @discardableResult
    func reconnect(_ drive: DriveRecord) -> Bool {
        detach()
        // Disque réseau : la reconnexion est asynchrone (connexion SMB) et passe
        // par l'écran « Disque réseau ». Ici on ne peut pas la faire en synchrone.
        if (try? JSONDecoder().decode(DriveConnection.self, from: drive.bookmarkData)) != nil {
            state = .disconnected(drive)
            return false
        }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: drive.bookmarkData,
            bookmarkDataIsStale: &isStale
        ) else {
            state = .disconnected(drive)
            return false
        }
        guard url.startAccessingSecurityScopedResource() else {
            state = .disconnected(drive)
            return false
        }
        guard (try? url.checkResourceIsReachable()) == true else {
            url.stopAccessingSecurityScopedResource()
            state = .disconnected(drive)
            return false
        }
        if isStale, let fresh = try? url.bookmarkData() {
            try? database.writer.write { db in
                try db.execute(
                    sql: "UPDATE drive SET bookmarkData = ? WHERE id = ?",
                    arguments: [fresh, drive.id]
                )
            }
        }
        accessedURL = url
        currentStore = LocalMediaStore(root: url)
        state = .connected(drive, url)
        return true
    }

    /// À appeler quand une opération fichier échoue parce que le disque a disparu.
    func handleDisconnection() {
        guard case .connected(let drive, _) = state else { return }
        detach()
        state = .disconnected(drive)
    }

    /// Éjection volontaire depuis les Réglages : libère l'accès et revient à
    /// l'écran de sélection pour brancher un autre disque. Contrairement à
    /// `handleDisconnection`, c'est une action explicite de l'utilisateur — on
    /// ne propose pas de « réessayer », on repart du choix de disque.
    func eject() {
        detach()
        state = .noDrive
    }

    /// Suppression définitive d'un disque connu : efface sa fiche en base et,
    /// par cascade (ON DELETE CASCADE), tous ses fichiers, statistiques, tri et
    /// corbeille. Le contenu du disque physique n'est jamais touché. Si c'est le
    /// disque actuellement branché (ou affiché comme débranché), on libère
    /// d'abord l'accès et on revient à l'écran de sélection.
    func forget(_ drive: DriveRecord) async throws {
        switch state {
        case .connected(let d, _) where d.id == drive.id:
            detach()
            state = .noDrive
        case .disconnected(let d) where d.id == drive.id:
            state = .noDrive
        default:
            break
        }
        try await database.writer.write { db in
            _ = try DriveRecord.deleteOne(db, key: drive.id)
        }
        Keychain.delete(account: drive.id)
        knownDrives.removeAll { $0.id == drive.id }
    }

    func detach() {
        accessedURL?.stopAccessingSecurityScopedResource()
        accessedURL = nil
        currentStore = nil
    }

    private func existingGeneration(for driveId: String) -> Int64 {
        (try? database.writer.read { db in
            try DriveRecord.fetchOne(db, key: driveId)?.scanGeneration
        }) ?? 0
    }
}
