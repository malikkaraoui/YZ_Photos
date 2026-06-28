import XCTest
@testable import YZPhotos

/// Tests de la logique SÛRETÉ-CRITIQUE de « Fusionner tout » : quel fichier est
/// GARDÉ dans chaque groupe (donc lequel n'est PAS mis à la corbeille).
/// `mergeAllDuplicates` boucle juste `keepBest`, qui s'appuie sur `bestOfGroup`.
final class BestOfGroupTests: XCTestCase {

    private func file(id: Int64, w: Int?, h: Int?, size: Int64) -> FileRecord {
        FileRecord(
            id: id, driveId: "T", relativePath: "dossier/\(id).jpg", fileName: "\(id).jpg",
            ext: "jpg", kind: .photo, sourceType: .folder, sizeBytes: size,
            modifiedAt: Date(timeIntervalSince1970: 0), captureDate: nil,
            pixelWidth: w, pixelHeight: h, durationSeconds: nil, partialHash: nil,
            fullHash: nil, dHash: nil, analyzedAt: nil, isScreenshot: false,
            dupGroupId: 1, dupKind: .exact, status: .untriaged, trashName: nil,
            scanGeneration: 1
        )
    }

    /// On garde la PLUS HAUTE RÉSOLUTION (nombre de pixels), pas le plus gros fichier.
    func testKeepsHighestResolution() {
        let a = file(id: 1, w: 100, h: 100, size: 9000)   // 10 000 px, gros fichier
        let b = file(id: 2, w: 200, h: 150, size: 400)    // 30 000 px, petit fichier
        let c = file(id: 3, w: 120, h: 120, size: 8000)   // 14 400 px
        XCTAssertEqual(Queries.bestOfGroup([a, b, c])?.id, 2)
    }

    /// À résolution ÉGALE, on garde le plus gros (octets) — souvent la meilleure qualité.
    func testTieBreaksByLargestSize() {
        let a = file(id: 1, w: 100, h: 100, size: 500)
        let b = file(id: 2, w: 100, h: 100, size: 800)
        let c = file(id: 3, w: 100, h: 100, size: 700)
        XCTAssertEqual(Queries.bestOfGroup([a, b, c])?.id, 2)
    }

    /// Scan léger SMB : pas de dimensions connues → repli sur la taille (le plus gros).
    func testNilDimensionsFallBackToSize() {
        let a = file(id: 1, w: nil, h: nil, size: 1000)
        let b = file(id: 2, w: nil, h: nil, size: 3000)
        let c = file(id: 3, w: nil, h: nil, size: 2000)
        XCTAssertEqual(Queries.bestOfGroup([a, b, c])?.id, 2)
    }

    /// Le « meilleur » fait toujours partie du groupe (jamais un fichier inventé).
    func testBestIsAMemberOfTheGroup() {
        let group = [file(id: 10, w: 50, h: 50, size: 100),
                     file(id: 11, w: 80, h: 80, size: 100),
                     file(id: 12, w: 60, h: 60, size: 100)]
        let best = Queries.bestOfGroup(group)
        XCTAssertNotNil(best)
        XCTAssertTrue(group.contains { $0.id == best?.id })
    }

    func testEmptyGroupReturnsNil() {
        XCTAssertNil(Queries.bestOfGroup([]))
    }

    /// Un groupe d'un seul fichier garde ce fichier (rien à supprimer).
    func testSingleFileGroupKeepsIt() {
        let only = file(id: 7, w: 100, h: 100, size: 100)
        XCTAssertEqual(Queries.bestOfGroup([only])?.id, 7)
    }
}
