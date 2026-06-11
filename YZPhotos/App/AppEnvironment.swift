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
}
