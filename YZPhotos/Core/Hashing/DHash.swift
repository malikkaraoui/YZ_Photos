import CoreGraphics
import Foundation

/// Hash perceptuel dHash 64 bits : l'image est réduite en 9×8 niveaux de gris,
/// chaque bit encode « pixel plus clair que son voisin de droite ».
/// Robuste à la recompression et au redimensionnement, <1 ms sur une miniature
/// déjà décodée.
enum DHash {
    static let width = 9
    static let height = 8

    static func compute(from image: CGImage) -> UInt64? {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        var pixels = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var hash: UInt64 = 0
        for row in 0..<height {
            for col in 0..<(width - 1) {
                let left = pixels[row * width + col]
                let right = pixels[row * width + col + 1]
                hash <<= 1
                if left > right { hash |= 1 }
            }
        }
        return hash
    }

    static func hammingDistance(_ a: UInt64, _ b: UInt64) -> Int {
        (a ^ b).nonzeroBitCount
    }

    /// Seuil de Hamming en dessous duquel deux images sont quasi-doublons.
    static let nearDuplicateThreshold = 8
}
