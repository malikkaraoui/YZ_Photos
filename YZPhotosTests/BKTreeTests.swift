import XCTest
@testable import YZPhotos

final class BKTreeTests: XCTestCase {
    /// PRNG déterministe (SplitMix64) : le test est reproductible.
    private struct SplitMix64 {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    /// Le BK-tree doit renvoyer exactement le même résultat que la force brute.
    func testSearchMatchesBruteForce() {
        var rng = SplitMix64(state: 42)
        let hashes = (0..<1000).map { i in (hash: rng.next(), id: Int64(i)) }

        let tree = BKTree()
        for entry in hashes {
            tree.insert(hash: entry.hash, value: entry.id)
        }
        XCTAssertEqual(tree.count, 1000)

        for radius in [0, 4, 8, 16] {
            for probeIndex in stride(from: 0, to: 1000, by: 97) {
                let probe = hashes[probeIndex].hash
                let expected = Set(
                    hashes
                        .filter { DHash.hammingDistance($0.hash, probe) <= radius }
                        .map(\.id)
                )
                let found = Set(tree.search(hash: probe, radius: radius).map(\.value))
                XCTAssertEqual(found, expected, "radius=\(radius) probe=\(probeIndex)")
            }
        }
    }

    func testFindsCloseVariant() {
        let tree = BKTree()
        let base: UInt64 = 0xDEADBEEF_CAFEBABE
        tree.insert(hash: base, value: 1)
        tree.insert(hash: ~base, value: 2)
        // 3 bits de différence : doit matcher à radius 8, pas à radius 2.
        let variant = base ^ 0b10110
        XCTAssertEqual(tree.search(hash: variant, radius: 8).map(\.value), [1])
        XCTAssertTrue(tree.search(hash: variant, radius: 2).isEmpty)
    }
}
