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

    /// Fichiers ENCORE en cours de mise à la corbeille (remplissage) en arrière-plan.
    private(set) var trashingCount = 0
    /// Fichiers ENCORE en cours de suppression définitive (vidage) en arrière-plan.
    private(set) var deletingCount = 0
    var isTrashBusy: Bool { trashingCount > 0 || deletingCount > 0 }

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
        // IDEMPOTENT : si le fichier est DÉJÀ à la corbeille / supprimé (un état
        // périmé réaffiché après un redimensionnement de fenêtre peut être
        // re-supprimé), on ne le redéplace pas → plus d'erreur « Name Collision ».
        let currentStatus = try? await database.writer.read { db in
            try Int.fetchOne(db, sql: "SELECT status FROM file WHERE id = ?", arguments: [id])
        }
        if let s = currentStatus,
           s == FileStatus.trashed.rawValue || s == FileStatus.deleting.rawValue || s == FileStatus.deleted.rawValue {
            return
        }
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
        // 1. Statut .deleting (PAS .deleted) : la corbeille se vide tout de suite à
        //    l'écran, MAIS on garde le trashName en base → si l'app se ferme avant
        //    la fin, la suppression REPREND au prochain lancement (pas d'orphelins).
        try await database.writer.write { db in
            let marks = databaseQuestionMarks(count: ids.count)
            try db.execute(
                sql: "UPDATE file SET status = ? WHERE id IN (\(marks))",
                arguments: StatementArguments([FileStatus.deleting.rawValue] + ids)
            )
            try db.execute(
                sql: "DELETE FROM triage_action WHERE fileId IN (\(marks))",
                arguments: StatementArguments(ids)
            )
        }
        refreshUndoCount()
        // 2. Suppressions disque réelles en arrière-plan ; chaque fichier passe
        //    .deleting → .deleted une fois RÉELLEMENT effacé.
        deletingCount += files.count
        Task { await removePending(files) }
        return (files.count, bytes)
    }

    /// Reprend les suppressions définitives RESTÉES en cours (fichiers .deleting
    /// après une fermeture d'app avant la fin). À appeler à la connexion du disque.
    func resumePendingDeletions() {
        let driveId = self.driveId, database = self.database
        Task {
            let pending = (try? await database.writer.read { db in
                try FileRecord
                    .filter(Column("driveId") == driveId)
                    .filter(Column("status") == FileStatus.deleting.rawValue)
                    .fetchAll(db)
            }) ?? []
            guard !pending.isEmpty else { return }
            AppLog.log("Reprise suppression corbeille : \(pending.count) fichier(s) restés en cours", "🗑️")
            deletingCount += pending.count
            await removePending(pending)
        }
    }

    /// Efface réellement du disque les fichiers .deleting et passe chacun à .deleted
    /// une fois fait. Décrémente `deletingCount` au fil de l'eau (indicateur « vidage »).
    /// Un échec RÉSEAU laisse le fichier .deleting (repris au prochain lancement) ;
    /// un fichier déjà absent est considéré comme supprimé. Les E/S sont awaitées
    /// (hors MainActor) → la boucle ne bloque pas l'interface.
    private func removePending(_ files: [FileRecord]) async {
        for file in files {
            defer { deletingCount = max(0, deletingCount - 1) }
            guard let id = file.id else { continue }
            var done = false
            do {
                try await store.deletePermanently(file: file)
                done = true
            } catch {
                if SMBStore.isPathError(error) { done = true }   // déjà absent = supprimé
            }
            guard done else { continue }   // sinon (réseau) : reste .deleting → repris
            try? await database.writer.write { db in
                try db.execute(
                    sql: "UPDATE file SET status = ?, trashName = NULL WHERE id = ?",
                    arguments: [FileStatus.deleted.rawValue, id]
                )
            }
        }
    }

    // MARK: - Doublons

    /// Met à la poubelle plusieurs fichiers d'un coup (sélection multiple).
    /// Chaque fichier passe par trash() : tout reste annulable un par un.
    func trashAll(_ files: [FileRecord]) async throws {
        AppLog.log("trashAll: début (\(files.count) fichiers)", "🗑️")
        trashingCount += files.count
        var failures: [FileRecord] = []
        for (i, file) in files.enumerated() {
            do {
                try await trashCore(file)
            } catch {
                // On N'ABANDONNE PAS tout le lot à la première erreur (connexion qui
                // décroche) — sinon des centaines de fichiers restaient non traités.
                // On note l'échec et on CONTINUE avec les suivants.
                failures.append(file)
                AppLog.error("trashAll: échec sur « \(file.fileName) » (on continue)", error)
            }
            trashingCount = max(0, trashingCount - 1)
            // Notifie la Corbeille par PAQUETS (tous les 20 fichiers), pas à chaque
            // fichier : sinon des dizaines de rechargements successifs la figeaient.
            if i % 20 == 19 { changeTick += 1 }
        }
        // 2e passe : on RÉESSAIE les échecs (souvent une coupure réseau brève).
        if !failures.isEmpty {
            AppLog.log("trashAll: 2e essai sur \(failures.count) échec(s)", "🗑️")
            trashingCount += failures.count
            var stillFailed = 0
            for file in failures {
                do { try await trashCore(file) } catch { stillFailed += 1 }
                trashingCount = max(0, trashingCount - 1)
            }
            if stillFailed > 0 {
                AppLog.log("\(stillFailed) fichier(s) NON déplacés (connexion instable) — ils réapparaîtront, à refaire quand le disque est stable", "⚠️")
            }
        }
        changeTick += 1
        AppLog.log("trashAll: terminé — \(files.count - failures.count)/\(files.count) au 1er essai", "🗑️")
    }

    /// « Fusionner tout » : garde la meilleure de CHAQUE groupe et met le reste à la
    /// corbeille (récupérable). Appelle `onProgress(traités)` après chaque groupe et
    /// s'arrête tôt si `isCancelled()` devient vrai. Renvoie le nombre de groupes
    /// effectivement traités. Lourd (beaucoup de déplacements réseau) → toujours
    /// appelé en arrière-plan avec progression + annulation.
    @discardableResult
    func mergeAllDuplicates(
        _ groups: [[FileRecord]],
        isCancelled: () -> Bool = { false },
        onProgress: (Int) -> Void = { _ in }
    ) async -> Int {
        var done = 0
        for group in groups {
            if isCancelled() { break }
            try? await keepBest(of: group)
            done += 1
            onProgress(done)
        }
        return done
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

    /// « Garder la meilleure » : met à la corbeille toutes les copies SAUF la
    /// meilleure du groupe.
    func keepBest(of group: [FileRecord]) async throws {
        guard let best = Queries.bestOfGroup(group) else { return }
        // Chaque mise à la corbeille est INDÉPENDANTE : si un fichier résiste
        // (déplacement réseau qui échoue), on le LOGUE et on CONTINUE — un seul
        // fichier coincé ne doit plus laisser tout le groupe bloqué (« doublon qui
        // reste, impossible à supprimer »).
        var failed = 0
        for file in group where file.id != best.id {
            do {
                try await trash(file)
            } catch {
                failed += 1
                AppLog.error("keepBest: échec corbeille « \(file.fileName) » (groupe \(best.dupGroupId.map(String.init) ?? "?"))", error)
            }
        }
        // Le meilleur reste EN PLACE (statut INCHANGÉ → pas de faux « gardé » vert
        // partout) et perd son marquage de doublon → le groupe DISPARAÎT de la liste,
        // même si une copie a résisté.
        if let id = best.id {
            try? await database.writer.write { db in
                try db.execute(
                    sql: "UPDATE file SET dupGroupId = NULL, dupKind = NULL WHERE id = ?",
                    arguments: [id]
                )
            }
        }
        if failed > 0 {
            AppLog.log("keepBest: \(failed) copie(s) NON déplacée(s) (connexion ?) — voir log", "⚠️")
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
