import Foundation
import GRDB

/// Détection de doublons, lancée après le scan :
/// 1. exacts — candidats par (taille, hash partiel), confirmés par SHA-256 complet
///    (calculé uniquement sur collision) ;
/// 2. quasi-doublons — BK-tree sur les dHash, distance de Hamming ≤ 8 ;
/// 3. clustering union-find, écriture des dupGroupId/dupKind en base.
struct DuplicateFinder: Sendable {
    let database: AppDatabase

    @discardableResult
    func run(driveId: String, root: URL, controller: DuplicateRunController? = nil) async throws -> Int {
        // Repart de zéro : les groupes sont recalculés à chaque recherche.
        try await database.writer.write { db in
            try db.execute(
                sql: "UPDATE file SET dupGroupId = NULL, dupKind = NULL WHERE driveId = ?",
                arguments: [driveId]
            )
        }

        var unionFind = UnionFind()
        var exactIds = Set<Int64>()

        // — Doublons exacts —
        let candidateGroups = try await fetchExactCandidates(driveId: driveId)
        await controller?.reportCandidates(candidateGroups.count)
        for group in candidateGroups {
            try await controller?.checkpoint()
            try Task.checkCancellation()
            var byHash: [Data: [Int64]] = [:]
            for file in group {
                guard let id = file.id else { continue }
                let hash: Data
                if let existing = file.fullHash {
                    hash = existing
                } else {
                    try await controller?.checkpoint()
                    let url = root.appending(path: file.relativePath)
                    guard let computed = try? HashWorker.fullHash(url: url) else { continue }
                    hash = computed
                    try await database.writer.write { db in
                        try db.execute(
                            sql: "UPDATE file SET fullHash = ? WHERE id = ?",
                            arguments: [computed, id]
                        )
                    }
                }
                byHash[hash, default: []].append(id)
            }
            for ids in byHash.values where ids.count > 1 {
                for id in ids.dropFirst() {
                    unionFind.union(ids[0], id)
                }
                exactIds.formUnion(ids)
            }
            await controller?.reportGroupConfirmed()
        }

        // — Quasi-doublons (photos uniquement) —
        let photos = try await database.writer.read { db in
            try Row.fetchAll(db, sql: """
                SELECT id, dHash FROM file
                WHERE driveId = ? AND kind = 0 AND status IN (0, 1) AND dHash IS NOT NULL
                """, arguments: [driveId])
        }
        await controller?.reportPerceptualStart(total: photos.count)
        let tree = BKTree()
        for (index, row) in photos.enumerated() {
            if index % 500 == 0 {
                try await controller?.checkpoint()
                await controller?.reportPerceptualProgress(index)
            }
            let id: Int64 = row["id"]
            let hash = UInt64(bitPattern: row["dHash"] as Int64)
            // Recherche avant insertion : chaque paire n'est vue qu'une fois.
            for match in tree.search(hash: hash, radius: DHash.nearDuplicateThreshold) {
                unionFind.union(id, match.value)
            }
            tree.insert(hash: hash, value: id)
        }
        await controller?.reportPerceptualProgress(photos.count)
        await controller?.reportWriting()

        // — Clusters → écriture —
        var clusters: [Int64: [Int64]] = [:]
        for element in unionFind.allElements {
            clusters[unionFind.find(element), default: []].append(element)
        }
        let finalClusters = clusters.values.filter { $0.count > 1 }
        try await database.writer.write { db in
            var groupId: Int64 = 0
            for cluster in finalClusters.sorted(by: { ($0.min() ?? 0) < ($1.min() ?? 0) }) {
                groupId += 1
                for id in cluster {
                    let kind: DupKind = exactIds.contains(id) ? .exact : .near
                    try db.execute(
                        sql: "UPDATE file SET dupGroupId = ?, dupKind = ? WHERE id = ?",
                        arguments: [groupId, kind.rawValue, id]
                    )
                }
            }
        }
        return finalClusters.count
    }

    /// Groupes candidats au doublon exact : même taille ET même hash partiel.
    private func fetchExactCandidates(driveId: String) async throws -> [[FileRecord]] {
        try await database.writer.read { db in
            let keys = try Row.fetchAll(db, sql: """
                SELECT sizeBytes, partialHash FROM file
                WHERE driveId = ? AND status IN (0, 1) AND partialHash IS NOT NULL
                GROUP BY sizeBytes, partialHash
                HAVING COUNT(*) > 1
                """, arguments: [driveId])
            return try keys.map { key in
                try FileRecord
                    .filter(Column("driveId") == driveId)
                    .filter([FileStatus.untriaged.rawValue, FileStatus.kept.rawValue].contains(Column("status")))
                    .filter(Column("sizeBytes") == (key["sizeBytes"] as Int64))
                    .filter(Column("partialHash") == (key["partialHash"] as Data))
                    .fetchAll(db)
            }
        }
    }
}

/// Union-find avec compression de chemin, sur les ids de fichiers.
struct UnionFind {
    private var parent: [Int64: Int64] = [:]

    var allElements: [Int64] { Array(parent.keys) }

    mutating func find(_ x: Int64) -> Int64 {
        guard let p = parent[x] else {
            parent[x] = x
            return x
        }
        if p == x { return x }
        let root = find(p)
        parent[x] = root
        return root
    }

    mutating func union(_ a: Int64, _ b: Int64) {
        let rootA = find(a)
        let rootB = find(b)
        if rootA != rootB {
            parent[rootB] = rootA
        }
    }
}
