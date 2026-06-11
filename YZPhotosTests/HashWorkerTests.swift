import XCTest
@testable import YZPhotos

final class HashWorkerTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func writeFile(_ name: String, _ data: Data) throws -> URL {
        let url = tempDir.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }

    func testPartialHashIsStable() throws {
        let data = Data((0..<500_000).map { UInt8($0 % 251) })
        let url = try writeFile("a.bin", data)
        let h1 = try HashWorker.partialHash(url: url, sizeBytes: Int64(data.count))
        let h2 = try HashWorker.partialHash(url: url, sizeBytes: Int64(data.count))
        XCTAssertEqual(h1, h2)
        XCTAssertEqual(h1.count, 32)
    }

    func testIdenticalContentSameHashDifferentContentDifferentHash() throws {
        let data = Data((0..<500_000).map { UInt8($0 % 251) })
        var tailChanged = data
        tailChanged[data.count - 1] = 0xFF

        let a = try writeFile("a.bin", data)
        let b = try writeFile("b.bin", data)
        let c = try writeFile("c.bin", tailChanged)

        let ha = try HashWorker.partialHash(url: a, sizeBytes: Int64(data.count))
        let hb = try HashWorker.partialHash(url: b, sizeBytes: Int64(data.count))
        let hc = try HashWorker.partialHash(url: c, sizeBytes: Int64(tailChanged.count))
        XCTAssertEqual(ha, hb, "Copies identiques → même hash partiel")
        XCTAssertNotEqual(ha, hc, "Changement dans la queue du fichier → hash différent")
    }

    /// La taille fait partie du hash : deux fichiers de tailles différentes
    /// ne peuvent jamais entrer en collision même si la tête/queue lues coïncident.
    func testSizeIsPartOfHash() throws {
        let small = Data(repeating: 7, count: 1000)
        let big = Data(repeating: 7, count: 2000)
        let a = try writeFile("small.bin", small)
        let b = try writeFile("big.bin", big)
        let ha = try HashWorker.partialHash(url: a, sizeBytes: Int64(small.count))
        let hb = try HashWorker.partialHash(url: b, sizeBytes: Int64(big.count))
        XCTAssertNotEqual(ha, hb)
    }

    func testFullHashMatchesForCopies() throws {
        let data = Data((0..<2_000_000).map { UInt8(($0 &* 31) % 255) })
        let a = try writeFile("a.bin", data)
        let b = try writeFile("b.bin", data)
        XCTAssertEqual(try HashWorker.fullHash(url: a), try HashWorker.fullHash(url: b))
    }
}
