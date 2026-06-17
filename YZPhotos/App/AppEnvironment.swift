import Foundation
import Observation

/// Racine de composition : construit et possède tous les services.
@MainActor
@Observable
final class AppEnvironment {
    let database: AppDatabase
    let thumbnails: ThumbnailStore
    let driveAccess: DriveAccessManager
    let scan: ScanCoordinator
    let duplicates: DuplicateRunController
    let settings = AppSettings()
    private(set) var triage: TriageService?

    init() {
        do {
            database = try AppDatabase.open()
        } catch {
            fatalError("Impossible d'ouvrir la base : \(error)")
        }
        thumbnails = ThumbnailStore()
        driveAccess = DriveAccessManager(database: database)
        scan = ScanCoordinator(database: database, thumbnails: thumbnails)
        duplicates = DuplicateRunController(database: database)
    }

    /// À appeler dès qu'un disque est connecté : câble le service de tri
    /// et lance automatiquement le scan (incrémental, donc peu coûteux).
    func driveDidConnect(_ drive: DriveRecord, root: URL) {
        triage = TriageService(database: database, driveRoot: root, driveId: drive.id)
        scan.startScan(drive: drive, root: root)
    }

    func driveDidDisconnect() {
        scan.cancel()
        duplicates.cancel()
        triage = nil
        driveAccess.handleDisconnection()
    }

    /// Éjection volontaire (bouton Réglages) : on arrête tout travail en cours —
    /// scan, recherche de doublons, tri — puis on libère l'accès. Le travail
    /// déjà accompli est en base : aucune perte, la reprise est gratuite si on
    /// rebranche ce disque plus tard.
    func ejectDrive() {
        scan.cancel()
        duplicates.cancel()
        triage = nil
        driveAccess.eject()
    }

    /// Bascule vers un autre disque déjà connu (via son bookmark persisté),
    /// sans repasser par le picker. Arrête d'abord le travail du disque courant.
    /// Renvoie false si le disque cible n'est pas branché/joignable.
    @discardableResult
    func switchDrive(to drive: DriveRecord) -> Bool {
        scan.cancel()
        duplicates.cancel()
        triage = nil
        guard driveAccess.reconnect(drive),
              case .connected(let connected, let url) = driveAccess.state else {
            return false
        }
        driveDidConnect(connected, root: url)
        return true
    }

    /// Supprime définitivement un disque connu : sa fiche et toutes ses données
    /// locales (statistiques, tri, corbeille) sont effacées de la base. Si c'est
    /// le disque actuellement branché, on arrête d'abord proprement tout le
    /// travail en cours. Le contenu du disque physique n'est pas touché.
    func forgetDrive(_ drive: DriveRecord) async throws {
        if driveAccess.connectedDrive?.id == drive.id {
            scan.cancel()
            duplicates.cancel()
            triage = nil
        }
        try await driveAccess.forget(drive)
    }

    /// Attache un disque fraîchement choisi dans le picker, en remplaçant le
    /// disque courant (dont on arrête d'abord proprement le travail).
    func attachNewDrive(pickedURL: URL) throws {
        scan.cancel()
        duplicates.cancel()
        triage = nil
        let drive = try driveAccess.attach(pickedURL: pickedURL)
        driveDidConnect(drive, root: pickedURL)
    }
}
