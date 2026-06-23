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
    let thumbnailFiller: ThumbnailFiller
    let settings = AppSettings()
    private(set) var triage: TriageService?

    /// Couche d'accès du disque branché (USB local ou réseau SMB).
    var currentStore: MediaStore? { driveAccess.currentStore }

    /// Incrémenté quand la base change hors tri normal (ex. purge de fichiers
    /// non-média) → les écrans qui l'observent rechargent leur fenêtre.
    private(set) var libraryReloadTick = 0

    init() {
        AppLog.installCrashHandlers()
        do {
            database = try AppDatabase.open()
        } catch {
            AppLog.error("Ouverture base impossible", error)
            fatalError("Impossible d'ouvrir la base : \(error)")
        }
        thumbnails = ThumbnailStore()
        driveAccess = DriveAccessManager(database: database)
        scan = ScanCoordinator(database: database, thumbnails: thumbnails)
        duplicates = DuplicateRunController(database: database)
        thumbnailFiller = ThumbnailFiller(database: database, thumbnails: thumbnails)
    }

    /// À appeler dès qu'un disque est connecté : câble le service de tri
    /// et lance automatiquement le scan (incrémental, donc peu coûteux).
    func driveDidConnect(_ drive: DriveRecord, root: URL) {
        let store = driveAccess.currentStore ?? LocalMediaStore(root: root)
        AppLog.log("Disque connecté : « \(drive.name) » (\(drive.id)) — déjà scanné: \(drive.lastScanCompletedAt != nil)", "🔌")
        triage = TriageService(database: database, store: store, driveId: drive.id)
        // Nettoyage instantané (DB seule, sans re-scan ni accès disque) : retire
        // les fichiers indexés à tort comme média (ex. .ts TypeScript).
        Task {
            if let purged = try? await FileStore(database: self.database).purgeNonMedia(driveId: drive.id),
               purged > 0 {
                AppLog.log("Purge non-média : \(purged) fichiers retirés de la base", "🧹")
                self.libraryReloadTick += 1
            }
        }
        // On NE relance PAS l'analyse si le disque a déjà été analysé entièrement :
        // tout est en base, l'app s'ouvre directement sur la bibliothèque (pas de
        // re-parcours réseau inutile). Pour prendre en compte des ajouts, l'analyse
        // se relance à la main (onglets Analyse / Stats → « Relancer l'analyse »).
        if drive.lastScanCompletedAt == nil {
            scan.startScan(drive: drive, store: store)
        }
        // Remplit progressivement les vignettes vidéo manquantes en arrière-plan
        // (en pause tant qu'une analyse tourne). PAS sur iPhone : budget mémoire
        // trop serré pour un décodage vidéo soutenu en fond (jetsam). Les vignettes
        // s'y génèrent à la demande quand on regarde la grille Vidéos.
        if !thumbnails.isPhone {
            thumbnailFiller.start(driveId: drive.id, store: store) { [weak self] in
                self?.scan.isRunning ?? false
            }
        }
    }

    /// Branche un disque réseau SMB choisi dans l'écran de connexion, puis
    /// démarre le tri + le scan comme pour un disque USB.
    func attachSMBDrive(host: String, share: String, path: String, user: String, password: String) async throws {
        scan.cancel()
        duplicates.cancel()
        triage = nil
        let drive = try await driveAccess.attachSMB(host: host, share: share, path: path, user: user, password: password)
        if case .connected(_, let url) = driveAccess.state {
            driveDidConnect(drive, root: url)
        }
    }

    func driveDidDisconnect() {
        scan.cancel()
        duplicates.cancel()
        thumbnailFiller.stop()
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
