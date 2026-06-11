import UIKit
import XCTest
@testable import YZPhotos

final class DHashTests: XCTestCase {
    /// Image de test : dégradé horizontal (structure stable pour le dHash).
    private func gradientImage(size: Int = 256) -> CGImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { ctx in
            for x in 0..<size where x.isMultiple(of: 4) {
                let level = CGFloat(x) / CGFloat(size)
                ctx.cgContext.setFillColor(UIColor(white: level, alpha: 1).cgColor)
                ctx.cgContext.fill(CGRect(x: x, y: 0, width: 4, height: size))
            }
        }
        return image.cgImage!
    }

    private func checkerboardImage(size: Int = 256) -> CGImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { ctx in
            let cell = size / 8
            for row in 0..<8 {
                for col in 0..<8 {
                    let white = (row + col).isMultiple(of: 2)
                    ctx.cgContext.setFillColor(UIColor(white: white ? 1 : 0, alpha: 1).cgColor)
                    ctx.cgContext.fill(CGRect(x: col * cell, y: row * cell, width: cell, height: cell))
                }
            }
        }
        return image.cgImage!
    }

    func testIdenticalImagesHaveSameHash() {
        let image = gradientImage()
        let a = DHash.compute(from: image)
        let b = DHash.compute(from: image)
        XCTAssertNotNil(a)
        XCTAssertEqual(a, b)
    }

    /// Invariance à la recompression JPEG : le cas « même photo recompressée ».
    func testRecompressedImageIsNearDuplicate() throws {
        let original = gradientImage()
        let jpegData = try XCTUnwrap(UIImage(cgImage: original).jpegData(compressionQuality: 0.4))
        let recompressed = try XCTUnwrap(UIImage(data: jpegData)?.cgImage)

        let a = try XCTUnwrap(DHash.compute(from: original))
        let b = try XCTUnwrap(DHash.compute(from: recompressed))
        XCTAssertLessThanOrEqual(
            DHash.hammingDistance(a, b),
            DHash.nearDuplicateThreshold,
            "Une image recompressée doit rester un quasi-doublon"
        )
    }

    /// Invariance au redimensionnement.
    func testResizedImageIsNearDuplicate() throws {
        let a = try XCTUnwrap(DHash.compute(from: gradientImage(size: 512)))
        let b = try XCTUnwrap(DHash.compute(from: gradientImage(size: 128)))
        XCTAssertLessThanOrEqual(DHash.hammingDistance(a, b), DHash.nearDuplicateThreshold)
    }

    func testDifferentImagesAreFarApart() throws {
        let a = try XCTUnwrap(DHash.compute(from: gradientImage()))
        let b = try XCTUnwrap(DHash.compute(from: checkerboardImage()))
        XCTAssertGreaterThan(
            DHash.hammingDistance(a, b),
            DHash.nearDuplicateThreshold,
            "Deux images différentes ne doivent pas être groupées"
        )
    }
}
