import Foundation

/// BK-tree sur des hashes 64 bits avec la distance de Hamming comme métrique.
/// Permet de chercher tous les hashes à distance ≤ r sans comparaison exhaustive.
/// 100k hashes ≈ 800 Ko en mémoire.
final class BKTree {
    /// Valeur associée à chaque hash (id du fichier en base).
    struct Match: Equatable, Hashable {
        var hash: UInt64
        var value: Int64
    }

    private final class Node {
        let hash: UInt64
        let value: Int64
        var children: [Int: Node] = [:]

        init(hash: UInt64, value: Int64) {
            self.hash = hash
            self.value = value
        }
    }

    private var root: Node?
    private(set) var count = 0

    func insert(hash: UInt64, value: Int64) {
        count += 1
        guard let root else {
            self.root = Node(hash: hash, value: value)
            return
        }
        var node = root
        while true {
            let distance = DHash.hammingDistance(hash, node.hash)
            if let child = node.children[distance] {
                node = child
            } else {
                node.children[distance] = Node(hash: hash, value: value)
                return
            }
        }
    }

    /// Tous les éléments à distance de Hamming ≤ radius du hash donné.
    func search(hash: UInt64, radius: Int) -> [Match] {
        guard let root else { return [] }
        var results: [Match] = []
        var stack: [Node] = [root]
        while let node = stack.popLast() {
            let distance = DHash.hammingDistance(hash, node.hash)
            if distance <= radius {
                results.append(Match(hash: node.hash, value: node.value))
            }
            let low = distance - radius
            let high = distance + radius
            for (childDistance, child) in node.children
            where childDistance >= low && childDistance <= high {
                stack.append(child)
            }
        }
        return results
    }
}
