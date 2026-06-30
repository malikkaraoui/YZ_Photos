import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Rotation d'image de 90° vers la DROITE, enregistrée par-dessus l'original.
/// - JPEG / HEIC / TIFF : on change UNIQUEMENT le tag d'orientation EXIF → **sans
///   perte** et instantané (les pixels compressés ne sont pas touchés).
/// - PNG (pas d'orientation EXIF) : on pivote les pixels et on ré-encode — PNG étant
///   lossless, aucune perte non plus.
enum ImageRotator {
    /// EXIF orientation → orientation après une rotation de 90° dans le sens horaire.
    /// (Cycle non-miroir : 1→6→3→8→1, qui couvre la quasi-totalité des photos.)
    private static let clockwise: [UInt32: UInt32] =
        [1: 6, 2: 7, 3: 8, 4: 5, 5: 2, 6: 3, 7: 4, 8: 1]

    /// Données de l'image pivotée de 90° à droite, ou nil si illisible.
    static func rotatedRightData(from data: Data, ext: String) -> Data? {
        // PNG : pas d'EXIF orientation → rotation des pixels.
        if ext.lowercased() == "png" {
            guard let img = UIImage(data: data) else { return nil }
            return img.rotatedRight90().pngData()
        }
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(src) else { return nil }
        let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any]
        let current = (props?[kCGImagePropertyOrientation] as? UInt32) ?? 1
        let new = clockwise[current] ?? 6
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, type, 1, nil) else { return nil }
        // AddImageFromSource COPIE les données encodées (pas de recompression) et
        // applique seulement le nouveau tag d'orientation → strictement sans perte.
        CGImageDestinationAddImageFromSource(
            dest, src, 0, [kCGImagePropertyOrientation: new] as CFDictionary
        )
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }

    /// Pivote (90° droite) et ENREGISTRE par-dessus l'original (USB ou SMB), puis
    /// invalide les caches de vignettes du fichier. Renvoie true si l'écriture a réussi.
    @discardableResult
    static func rotateRightAndSave(file: FileRecord, store: MediaStore, thumbnails: ThumbnailStore) async -> Bool {
        guard let data = try? await store.data(for: file),
              let rotated = rotatedRightData(from: data, ext: file.ext) else { return false }
        do {
            try await store.write(rotated, for: file)
        } catch {
            AppLog.error("Rotation : écriture impossible (\(file.fileName))", error)
            return false
        }
        if let id = file.id { thumbnails.invalidate(fileID: id) }
        AppLog.log("Photo pivotée et enregistrée : \(file.fileName)", "🔄")
        return true
    }
}

extension UIImage {
    /// Nouvelle image pivotée de 90° dans le sens horaire (orientation aplatie).
    /// Conserve l'échelle et la transparence (utile pour le PNG + l'aperçu optimiste).
    func rotatedRight90() -> UIImage {
        let newSize = CGSize(width: size.height, height: size.width)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = scale
        return UIGraphicsImageRenderer(size: newSize, format: format).image { ctx in
            let cg = ctx.cgContext
            cg.translateBy(x: newSize.width, y: 0)
            cg.rotate(by: .pi / 2)
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
