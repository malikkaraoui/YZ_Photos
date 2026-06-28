import Foundation
import GRDB

/// Filtre de la file de tri (le deck peut être alimenté depuis n'importe quel onglet).
enum TriageFilter: Hashable, Sendable {
    case all
    case photos
    case videos
    case screenshots
    case bySize
    case duplicates

    var title: String {
        switch self {
        case .all: "Tout"
        case .photos: "Photos"
        case .videos: "Vidéos"
        case .screenshots: "Captures d'écran"
        case .bySize: "Par taille"
        case .duplicates: "Doublons"
        }
    }
}

struct DriveStats: Equatable, Sendable {
    var totalCount: Int = 0
    var totalBytes: Int64 = 0
    var untriagedCount: Int = 0
    var keptCount: Int = 0
    var trashedCount: Int = 0
    var trashedBytes: Int64 = 0
    var deletedCount: Int = 0
    var freedBytes: Int64 = 0
    var photoCount: Int = 0
    var videoCount: Int = 0
    var screenshotCount: Int = 0
    var duplicateCount: Int = 0

    var triagedCount: Int { keptCount + trashedCount + deletedCount }
    var progress: Double {
        let total = totalCount + deletedCount
        guard total > 0 else { return 0 }
        return Double(triagedCount) / Double(total)
    }
}

/// Une entrée de l'onglet Dossiers : un sous-dossier (ou les fichiers du niveau)
/// avec ses agrégats récursifs.
struct FolderEntry: Identifiable, Sendable {
    /// Nom du sous-dossier ; nil = fichiers directement à ce niveau.
    var name: String?
    var count: Int
    var bytes: Int64
    var untriagedCount: Int

    var id: String { name ?? "•files" }
    var isPhotosLibrary: Bool { name?.lowercased().hasSuffix(".photoslibrary") ?? false }
}

/// Ordre d'affichage des grilles — « Ranger par… » disponible partout.
enum GridOrder: String, CaseIterable, Identifiable {
    case byFolder = "Dossier"
    case bySizeAsc = "Taille (petites d'abord)"
    case bySizeDesc = "Taille (grandes d'abord)"
    case byDateAsc = "Date (anciennes d'abord)"
    case byDateDesc = "Date (récentes d'abord)"
    case byKindPhotoFirst = "Genre (photos d'abord)"
    case byKindVideoFirst = "Genre (vidéos d'abord)"

    var id: String { rawValue }

    /// Critère de tri SANS la direction (pour le menu : un clic choisit le critère,
    /// un re-clic bascule croissant ↔ décroissant).
    enum Field: CaseIterable, Identifiable {
        case folder, size, date, kind
        var id: Self { self }
        var label: String {
            switch self {
            case .folder: "Dossier"
            case .size: "Taille"
            case .date: "Date"
            case .kind: "Genre"
            }
        }
        /// Ordre par défaut au PREMIER clic (croissant).
        var ascending: GridOrder {
            switch self {
            case .folder: .byFolder
            case .size: .bySizeAsc
            case .date: .byDateAsc
            case .kind: .byKindPhotoFirst
            }
        }
    }

    var field: Field {
        switch self {
        case .byFolder: .folder
        case .bySizeAsc, .bySizeDesc: .size
        case .byDateAsc, .byDateDesc: .date
        case .byKindPhotoFirst, .byKindVideoFirst: .kind
        }
    }

    var isDescending: Bool {
        switch self {
        case .bySizeDesc, .byDateDesc, .byKindVideoFirst: true
        default: false
        }
    }

    /// Même critère, direction inversée (le dossier n'a pas de direction).
    var toggled: GridOrder {
        switch self {
        case .byFolder: .byFolder
        case .bySizeAsc: .bySizeDesc
        case .bySizeDesc: .bySizeAsc
        case .byDateAsc: .byDateDesc
        case .byDateDesc: .byDateAsc
        case .byKindPhotoFirst: .byKindVideoFirst
        case .byKindVideoFirst: .byKindPhotoFirst
        }
    }

    var icon: String {
        switch field {
        case .folder: "folder"
        case .size: "arrow.up.arrow.down.square"
        case .date: "calendar"
        case .kind: "photo.on.rectangle"
        }
    }
}

enum Queries {
    /// Borne les chemins au sous-arbre `scope` (sans LIKE : pas d'échappement,
    /// et l'index UNIQUE(driveId, relativePath) reste utilisable).
    /// "0" est le caractère qui suit "/" en ASCII.
    static func applyScope(_ request: QueryInterfaceRequest<FileRecord>, _ scope: String?) -> QueryInterfaceRequest<FileRecord> {
        guard let scope, !scope.isEmpty else { return request }
        return request
            .filter(Column("relativePath") >= scope + "/")
            .filter(Column("relativePath") < scope + "0")
    }

    /// Fenêtre de fichiers non triés pour le deck, selon le filtre.
    /// Ordonnés par dossier puis nom (les rafales apparaissent consécutivement),
    /// sauf « par taille » (les plus gros d'abord).
    static func untriagedWindow(_ db: Database, driveId: String, filter: TriageFilter, scope: String? = nil, limit: Int) throws -> [FileRecord] {
        var request = FileRecord
            .filter(Column("driveId") == driveId)
            .filter(Column("status") == FileStatus.untriaged.rawValue)
        request = applyFilter(request, filter)
        request = applyScope(request, scope)
        if filter == .bySize {
            request = request.order(Column("sizeBytes").desc)
        } else {
            request = request.order(Column("relativePath").asc)
        }
        return try request.limit(limit).fetchAll(db)
    }

    /// Grille d'un onglet : fichiers visibles (non triés + gardés).
    static func gridRequest(driveId: String, filter: TriageFilter, scope: String? = nil, order: GridOrder = .byFolder) -> QueryInterfaceRequest<FileRecord> {
        var request = FileRecord
            .filter(Column("driveId") == driveId)
            .filter([FileStatus.untriaged.rawValue, FileStatus.kept.rawValue].contains(Column("status")))
        request = applyFilter(request, filter)
        request = applyScope(request, scope)
        switch order {
        case .byFolder:
            request = request.order(Column("relativePath").asc)
        case .bySizeAsc:
            request = request.order(Column("sizeBytes").asc)
        case .bySizeDesc:
            request = request.order(Column("sizeBytes").desc)
        case .byDateAsc:
            request = request.order((Column("captureDate") ?? Column("modifiedAt")).asc)
        case .byDateDesc:
            // Date de prise de vue si connue, sinon date de modification.
            request = request.order((Column("captureDate") ?? Column("modifiedAt")).desc)
        case .byKindPhotoFirst:
            request = request.order(Column("kind").asc, Column("relativePath").asc)
        case .byKindVideoFirst:
            request = request.order(Column("kind").desc, Column("relativePath").asc)
        }
        return request
    }

    static func untriagedCount(_ db: Database, driveId: String, filter: TriageFilter, scope: String? = nil) throws -> Int {
        var request = FileRecord
            .filter(Column("driveId") == driveId)
            .filter(Column("status") == FileStatus.untriaged.rawValue)
        request = applyFilter(request, filter)
        request = applyScope(request, scope)
        return try request.fetchCount(db)
    }

    /// Totaux affichés en tête de grille : (nombre de fichiers, octets).
    static func gridTotals(_ db: Database, driveId: String, filter: TriageFilter, scope: String? = nil) throws -> (count: Int, bytes: Int64) {
        let request = gridRequest(driveId: driveId, filter: filter, scope: scope)
        let count = try request.fetchCount(db)
        let bytes = try Int64.fetchOne(db, request.select(sum(Column("sizeBytes")))) ?? 0
        return (count, bytes)
    }

    /// Contenu d'un niveau de l'arborescence : sous-dossiers avec agrégats
    /// récursifs (nb fichiers, octets, restant à trier), triés par taille.
    /// `prefix` vide = racine du disque. La ligne `name == nil` regroupe les
    /// fichiers posés directement à ce niveau.
    static func folderEntries(_ db: Database, driveId: String, prefix: String) throws -> [FolderEntry] {
        let lower: String
        let upper: String
        let restStart: Int
        if prefix.isEmpty {
            lower = ""
            upper = "\u{10FFFF}"
            restStart = 1
        } else {
            lower = prefix + "/"
            upper = prefix + "0"
            restStart = lower.count + 1 // substr() de SQLite est 1-indexé, en caractères
        }
        let rows = try Row.fetchAll(db, sql: """
            SELECT
                CASE WHEN instr(rest, '/') = 0 THEN NULL
                     ELSE substr(rest, 1, instr(rest, '/') - 1) END AS folder,
                COUNT(*) AS c,
                SUM(sizeBytes) AS bytes,
                SUM(CASE WHEN status = 0 THEN 1 ELSE 0 END) AS untriaged
            FROM (
                SELECT substr(relativePath, ?) AS rest, sizeBytes, status
                FROM file
                WHERE driveId = ? AND status != 3
                  AND relativePath >= ? AND relativePath < ?
            )
            GROUP BY folder
            ORDER BY bytes DESC
            """, arguments: [restStart, driveId, lower, upper])
        return rows.map { row in
            FolderEntry(
                name: row["folder"],
                count: row["c"],
                bytes: row["bytes"] ?? 0,
                untriagedCount: row["untriaged"] ?? 0
            )
        }
    }

    private static func applyFilter(_ request: QueryInterfaceRequest<FileRecord>, _ filter: TriageFilter) -> QueryInterfaceRequest<FileRecord> {
        switch filter {
        case .all, .bySize:
            return request
        case .photos:
            return request.filter(Column("kind") == MediaKind.photo.rawValue)
        case .videos:
            return request.filter(Column("kind") == MediaKind.video.rawValue)
        case .screenshots:
            return request.filter(Column("isScreenshot") == true)
        case .duplicates:
            return request.filter(Column("dupGroupId") != nil)
        }
    }

    static func trashedFiles(driveId: String) -> QueryInterfaceRequest<FileRecord> {
        FileRecord
            .filter(Column("driveId") == driveId)
            .filter(Column("status") == FileStatus.trashed.rawValue)
            .order(Column("sizeBytes").desc)
    }

    /// Groupes de doublons encore visibles, les plus gros gains d'abord.
    /// Statut courant d'un fichier (ou nil s'il n'existe plus) — pour vérifier
    /// qu'un fichier en aperçu est encore valide (pas déjà à la corbeille).
    static func fileStatus(_ db: Database, id: Int64) throws -> Int? {
        try Int.fetchOne(db, sql: "SELECT status FROM file WHERE id = ?", arguments: [id])
    }

    /// Efface le marquage de doublon (dupGroupId, dupKind) des fichiers dont le
    /// groupe n'a PLUS qu'un seul membre « à trier / gardé » → le calque « doublon »
    /// disparaît dès qu'il n'y a plus de copie (suppression manuelle, fusion, ou
    /// anciennes données restées marquées). Idempotent (rien à faire si déjà propre).
    static func pruneSingletonDupGroups(_ db: Database, driveId: String) throws {
        let u = FileStatus.untriaged.rawValue, k = FileStatus.kept.rawValue
        try db.execute(sql: """
            UPDATE file SET dupGroupId = NULL, dupKind = NULL
            WHERE driveId = ? AND status IN (?, ?) AND dupGroupId IN (
                SELECT dupGroupId FROM file
                WHERE driveId = ? AND status IN (?, ?) AND dupGroupId IS NOT NULL
                GROUP BY dupGroupId HAVING COUNT(*) <= 1
            )
            """, arguments: [driveId, u, k, driveId, u, k])
    }

    static func duplicateGroups(_ db: Database, driveId: String) throws -> [[FileRecord]] {
        let files = try FileRecord
            .filter(Column("driveId") == driveId)
            .filter(Column("dupGroupId") != nil)
            .filter([FileStatus.untriaged.rawValue, FileStatus.kept.rawValue].contains(Column("status")))
            .fetchAll(db)
        // Pas de tri ici : la vue applique son propre tri (applySort) juste après.
        // Trier deux fois ~32 000 groupes (en recalculant reclaimableBytes) ralentit
        // l'ouverture de l'onglet pour rien.
        return Dictionary(grouping: files, by: { $0.dupGroupId! })
            .values
            .filter { $0.count > 1 }
            .map { $0 }
    }

    /// Octets récupérables dans un groupe si on ne garde que le meilleur fichier.
    static func reclaimableBytes(_ group: [FileRecord]) -> Int64 {
        guard let best = bestOfGroup(group) else { return 0 }
        return group.filter { $0.id != best.id }.reduce(0) { $0 + $1.sizeBytes }
    }

    /// Le « meilleur » fichier d'un groupe : plus grande résolution, puis plus gros.
    static func bestOfGroup(_ group: [FileRecord]) -> FileRecord? {
        group.max { a, b in
            let aPixels = (a.pixelWidth ?? 0) * (a.pixelHeight ?? 0)
            let bPixels = (b.pixelWidth ?? 0) * (b.pixelHeight ?? 0)
            if aPixels != bPixels { return aPixels < bPixels }
            return a.sizeBytes < b.sizeBytes
        }
    }

    static func stats(_ db: Database, driveId: String) throws -> DriveStats {
        var s = DriveStats()
        let rows = try Row.fetchAll(db, sql: """
            SELECT status, kind, COUNT(*) AS c, SUM(sizeBytes) AS bytes
            FROM file WHERE driveId = ?
            GROUP BY status, kind
            """, arguments: [driveId])
        for row in rows {
            let status = FileStatus(rawValue: row["status"]) ?? .untriaged
            let kind = MediaKind(rawValue: row["kind"]) ?? .photo
            let count: Int = row["c"]
            let bytes: Int64 = row["bytes"] ?? 0
            // .deleting = suppression définitive en cours → traité comme « parti »
            // (ni dans le total, ni dans la corbeille).
            if status != .deleted && status != .deleting {
                s.totalCount += count
                s.totalBytes += bytes
                if kind == .photo { s.photoCount += count } else { s.videoCount += count }
            }
            switch status {
            case .untriaged: s.untriagedCount += count
            case .kept: s.keptCount += count
            case .trashed:
                s.trashedCount += count
                s.trashedBytes += bytes
            case .deleted:
                s.deletedCount += count
                s.freedBytes += bytes
            case .deleting:
                s.deletedCount += count   // considéré supprimé côté utilisateur
            }
        }
        s.screenshotCount = try Int.fetchOne(db, sql: """
            SELECT COUNT(*) FROM file
            WHERE driveId = ? AND isScreenshot = 1 AND status IN (0, 1)
            """, arguments: [driveId]) ?? 0
        s.duplicateCount = try Int.fetchOne(db, sql: """
            SELECT COUNT(*) FROM file
            WHERE driveId = ? AND dupGroupId IS NOT NULL AND status IN (0, 1)
            """, arguments: [driveId]) ?? 0
        return s
    }
}
