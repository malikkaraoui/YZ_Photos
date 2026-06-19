import XCTest
@testable import YZPhotos

/// Garantit que l'empreinte calculée « par octets » (lecture réseau SMB) est
/// IDENTIQUE à l'empreinte calculée par fichier (USB). Sinon la détection de
/// doublons serait incohérente entre un disque local et un disque réseau.
final class HashWorkerDataTests: XCTestCase {
    private func tempFile(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try data.write(to: url)
        return url
    }

    private func pattern(_ n: Int) -> Data {
        Data((0..<n).map { UInt8($0 % 251) })
    }

    func testSmallFileDataEqualsURL() throws {
        let data = pattern(1000)
        let url = try tempFile(data)
        defer { try? FileManager.default.removeItem(at: url) }
        let viaURL = try HashWorker.partialHash(url: url, sizeBytes: Int64(data.count))
        let viaData = HashWorker.partialHash(sizeBytes: Int64(data.count), head: data, tail: nil)
        XCTAssertEqual(viaURL, viaData)
    }

    func testLargeFileDataEqualsURL() throws {
        let chunk = HashWorker.chunkSize
        let size = chunk * 3 + 123
        let data = pattern(size)
        let url = try tempFile(data)
        defer { try? FileManager.default.removeItem(at: url) }
        let viaURL = try HashWorker.partialHash(url: url, sizeBytes: Int64(size))
        let head = Data(data.prefix(chunk))
        let tail = Data(data.suffix(chunk))
        let viaData = HashWorker.partialHash(sizeBytes: Int64(size), head: head, tail: tail)
        XCTAssertEqual(viaURL, viaData)
    }

    func testBoundarySizeEqualsURL() throws {
        // Pile à la limite tête+queue (2× chunk) : doit lire le fichier entier.
        let chunk = HashWorker.chunkSize
        let data = pattern(chunk * 2)
        let url = try tempFile(data)
        defer { try? FileManager.default.removeItem(at: url) }
        let viaURL = try HashWorker.partialHash(url: url, sizeBytes: Int64(data.count))
        let viaData = HashWorker.partialHash(sizeBytes: Int64(data.count), head: data, tail: nil)
        XCTAssertEqual(viaURL, viaData)
    }

    func testFullHashDataEqualsURL() throws {
        let data = pattern(1024 * 1024 + 5)
        let url = try tempFile(data)
        defer { try? FileManager.default.removeItem(at: url) }
        let viaURL = try HashWorker.fullHash(url: url)
        let viaData = HashWorker.fullHash(data: data)
        XCTAssertEqual(viaURL, viaData)
    }
}
