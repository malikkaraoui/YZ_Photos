import Foundation
import GRDB
import Observation

/// Service central des décisions de tri. Toutes les vues (deck, doublons,
/// corbeille) passent par lui : il garantit la cohérence base ↔ disque et
/// alimente la pile d'annulation.
@MainActor
@Observable
final class TriageService {
    private let database: AppDatabase
    private let store: MediaStore
    private let driveId: String

    /// Pile d'annulation en mémoire (miroir de la table triage_action).
    private(set) var undoCount: Int = 0

    /// Incrémenté à chaque mutation (garder/poubelle/undo/restaurer/supprimer) :
    /// les écrans l'observent pour se recharger après une action globale.
    private(set) var changeTick: Int = 0

    init(database: AppDatabase, store: MediaStore, driveId: String) {
        self.database = database
        self.store = store
        self.driveId = driveId
        refreshUndoCount()
    }

    var canUndo: Bool { undoCount > 0 }

    // MARK: - Décisions

    /// Swipe droite : le fichier reste en place, marqué « gardé ».
    func keep(_ file: FileRecord) async throws {
        guard let id = file.id else { return }
        try await database.writer.write { db in
            try db.execute(
                sql: "UPDATE file SET status = ? WHERE id = ?",
                arguments: [FileStatus.kept.rawValue, id]
            )
            var action = TriageActionRecord(
                id: nil, fileId: id, action: .keep,
                prevStatus: file.status, performedAt: Date()
            )
            try action.insert(db)
        }
        undoCount += 1
        changeTick += 1
    }

    /// Swipe gauche : déplacement instantané vers .YZTrash (même volume).
    /// Cœur de la mise à la poubelle (déplacement SMB + base), SANS notifier la vue
    /// (`changeTick`). Permet à `trashAll` de regrouper les notifications.
    private func trashCore(_ file: FileRecord) async throws {
        guard let id = file.id else { return }
        let trashName = try await store.moveToTrash(file: file)
        try await database.writer.write { db in
            try db.execute(
                sql: "UPDATE file SET status = ?, trashName = ? WHERE id = ?",
                arguments: [FileStatus.trashed.rawValue, trashName, id]
            )
            var action = TriageActionRecord(
                id: nil, fileId: id, action: .trash,
                prevStatus: file.status, performedAt: Date()
            )
            try action.insert(db)
        }
        undoCount += 1
    }

    func trash(_ file: FileRecord) async throws {
        try await trashCore(file)
        changeTick += 1
    }

    /// Retour en arrière : annule la dernière décision (garder OU poubelle).
    /// Renvoie le fichier restauré pour que le deck puisse le réafficher.
    @discardableResult
    func undo() async throws -> FileRecord? {
        let last = try await database.writer.read { db in
            try TriageActionRecord.order(Column("id").desc).fetchOne(db)
        }
        guard let last, let actionId = last.id else { return nil }
        guard var file = try await database.writer.read({ db in
            try FileRecord.fetchOne(db, key: last.fileId)
        }) else {
            // Fichier disparu (vidage de corbeille…) : on purge l'action.
            try await deleteAction(actionId)
            return nil
        }

        if last.action == .trash, file.status == .trashed {
            try await store.restoreFromTrash(file: file)
        }

        try await database.writer.write { db in
            try db.execute(
                sql: "UPDATE file SET status = ?, trashName = NULL WHERE id = ?",
                arguments: [last.prevStatus.rawValue, last.fileId]
            )
            try db.execute(sql: "DELETE FROM triage_action WHERE id = ?", arguments: [actionId])
        }
        undoCount = max(0, undoCount - 1)
        changeTick += 1
        file.status = last.prevStatus
        file.trashName = nil
        return file
    }

    // MARK: - Corbeille

    /// Restaure un fichier depuis l'onglet Corbeille (hors pile d'undo).
    func restore(_ file: FileRecord) async throws {
        guard let id = file.id else { return }
        try await store.restoreFromTrash(file: file)
        try await database.writer.write { db in
            try db.execute(
                sql: "UPDATE file SET status = ?, trashName = NULL WHERE id = ?",
                arguments: [FileStatus.untriaged.rawValue, id]
            )
            // Les actions pointant sur ce fichier ne sont plus annulables proprement.
            try db.execute(sql: "DELETE FROM triage_action WHERE fileId = ?", arguments: [id])
        }
        refreshUndoCount()
    }

    /// Vide la corbeille : suppression définitive de tous les fichiers trashés.
    /// Renvoie (nombre, octets libérés).
    func emptyTrash() async throws -> (count: Int, bytes: Int64) {
        let driveId = self.driveId
        let files = try await database.writer.read { db in
            try Queries.trashedFiles(driveId: driveId).fetchAll(db)
        }
        return try await deletePermanently(files)
    }

    /// Suppression définitive d'une sélection de fichiers de la corbeille.
    /// Renvoie (nombre, octets libérés). Irréversible.
    func deletePermanently(_ files: [FileRecord]) async throws -> (count: Int, bytes: Int64) {
        guard !files.isEmpty else { return (0, 0) }
        let ids = files.compactMap(\.id)
        let bytes = files.reduce(Int64(0)) { $0 + $1.sizeBytes }
        // 1. Base D'ABORD : la corbeille se vide INSTANTANÉMENT à l'écran (au lieu
        //    d'attendre des centaines d'allers-retours réseau).
        try await database.writer.write { db in
            let marks = databaseQuestionMarks(count: ids.count)
            try db.execute(
                sql: "UPDATE file SET status = ?, trashName = NULL WHERE id IN (\(marks))",
                arguments: StatementArguments([FileStatus.deleted.rawValue] + ids)
            )
            try db.execute(
                sql: "DELETE FROM triage_action WHERE fileId IN (\(marks))",
                arguments: StatementArguments(ids)
            )
        }
        refreshUndoCount()
        // 2. Suppressions disque RÉELLES en arrière-plan : l'espace se libère au fil
        //    de l'eau (chaque objet capturé garde son trashName), sans bloquer
        //    l'utilisateur. SMBStore réessaie déjà sur coupure réseau.
        let store = self.store
        Task.detached(priority: .utility) {
            for file in files {
                try? await store.deletePermanently(file: file)
            }
        }
        return (files.count, bytes)
    }

    // MARK: - Doublons

    /// Met à la poubelle plusieurs fichiers d'un coup (sélection multiple).
    /// Chaque fichier passe par trash() : tout reste annulable un par un.
    func trashAll(_ files: [FileRecord]) async throws {
        AppLog.log("trashAll: début (\(files.count) fichiers)", "🗑️")
        for (i, file) in files.enumerated() {
            do {
                try await trashCore(file)
            } catch {
                AppLog.error("trashAll échec à \(i + 1)/\(files.count) sur « \(file.fileName) »", error)
                changeTick += 1
                throw error
            }
            // Notifie la Corbeille par PAQUETS (tous les 20 fichiers), pas à chaque
            // fichier : sinon des dizaines de rechargements successifs la figeaient
            // ~30 s. Elle se remplit progressivement et reste réactive.
            if i % 20 == 19 { changeTick += 1 }
        }
        changeTick += 1   // dernier paquet
        AppLog.log("trashAll: terminé (\(files.count))", "🗑️")
    }

    /// Garde plusieurs fichiers d'un coup (sélection multiple).
    func keepAll(_ files: [FileRecord]) async throws {
        for file in files {
            try await keep(file)
        }
    }

    /// Restaure plusieurs fichiers de la corbeille d'un coup.
    func restoreAll(_ files: [FileRecord]) async throws {
        for file in files {
            try await restore(file)
        }
    }

    /// « Garder la meilleure » : garde le meilleur fichier du groupe, met le reste à la poubelle.
    func keepBest(of group: [FileRecord]) async throws {
        guard let best = Queries.bestOfGroup(group) else { return }
        for file in group {
            if file.id == best.id {
                try await keep(file)
            } else {
                try await trash(file)
            }
        }
    }

    // MARK: - Privé

    private func deleteAction(_ actionId: Int64) async throws {
        try await database.writer.write { db in
            try db.execute(sql: "DELETE FROM triage_action WHERE id = ?", arguments: [actionId])
        }
        undoCount = max(0, undoCount - 1)
        changeTick += 1
    }

    private func refreshUndoCount() {
        undoCount = (try? database.writer.read { db in
            try TriageActionRecord.fetchCount(db)
        }) ?? 0
        changeTick += 1
    }
}
