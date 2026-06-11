import Foundation
import GRDB
import Observation

/// Alimentation paginée des grilles (Photos, Vidéos, Captures, Par taille).
@MainActor
@Observable
final class LibraryViewModel {
    let filter: TriageFilter
    /// Préfixe de chemin : restreint la grille à un dossier (nil = tout le disque).
    let scope: String?
    /// « Ranger par… » : dossier, taille, date ou genre.
    var order: GridOrder
    private let database: AppDatabase
    private let driveId: String

    private(set) var files: [FileRecord] = []
    private(set) var totalCount = 0
    private(set) var totalBytes: Int64 = 0
    private var loadedAll = false
    private var isLoading = false

    private static let pageSize = 400

    init(database: AppDatabase, driveId: String, filter: TriageFilter, scope: String? = nil, defaultOrder: GridOrder = .byFolder) {
        self.database = database
        self.driveId = driveId
        self.filter = filter
        self.scope = scope
        // « Par taille » garde son ordre ; les autres suivent le réglage.
        self.order = filter == .bySize ? .bySizeDesc : defaultOrder
    }

    func reload() async {
        loadedAll = false
        let driveId = self.driveId
        let filter = self.filter
        let scope = self.scope
        let order = self.order
        // Recharge AUTANT d'éléments que ce qui était affiché : sinon, après
        // une suppression en bas de grille, l'ascenseur sauterait en haut.
        let keepCount = max(Self.pageSize, files.count)
        do {
            let (page, totals) = try await database.writer.read { db in
                (
                    try Queries.gridRequest(driveId: driveId, filter: filter, scope: scope, order: order)
                        .limit(keepCount)
                        .fetchAll(db),
                    try Queries.gridTotals(db, driveId: driveId, filter: filter, scope: scope)
                )
            }
            files = page
            totalCount = totals.count
            totalBytes = totals.bytes
            loadedAll = page.count < keepCount
        } catch {
            files = []
        }
    }

    /// À appeler quand la dernière cellule apparaît.
    func loadMoreIfNeeded(current file: FileRecord) async {
        guard !loadedAll, !isLoading, file.id == files.last?.id else { return }
        isLoading = true
        defer { isLoading = false }
        let driveId = self.driveId
        let filter = self.filter
        let scope = self.scope
        let order = self.order
        let offset = files.count
        do {
            let page = try await database.writer.read { db in
                try Queries.gridRequest(driveId: driveId, filter: filter, scope: scope, order: order)
                    .limit(Self.pageSize, offset: offset)
                    .fetchAll(db)
            }
            files.append(contentsOf: page)
            loadedAll = page.count < Self.pageSize
        } catch {
            loadedAll = true
        }
    }
}
