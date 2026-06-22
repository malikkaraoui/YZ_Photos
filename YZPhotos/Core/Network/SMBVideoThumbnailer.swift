import AVFoundation
import CoreGraphics
import Foundation
import UniformTypeIdentifiers

/// Génère une vignette de vidéo stockée sur un disque **réseau (SMB)**, sans la
/// télécharger en entier : un `AVAssetResourceLoaderDelegate` sert à AVFoundation
/// uniquement les plages d'octets qu'il réclame (l'atome `moov` + la 1ʳᵉ image),
/// lues à la demande via `MediaStore.readRange`.
enum SMBVideoThumbnailer {

    /// Délègue le chargement des octets de la vidéo au disque réseau, par plages.
    final class Loader: NSObject, AVAssetResourceLoaderDelegate, @unchecked Sendable {
        let store: MediaStore
        let relativePath: String
        let size: Int64
        let contentTypeUTI: String

        init(store: MediaStore, relativePath: String, size: Int64, contentTypeUTI: String) {
            self.store = store
            self.relativePath = relativePath
            self.size = size
            self.contentTypeUTI = contentTypeUTI
        }

        func resourceLoader(
            _ resourceLoader: AVAssetResourceLoader,
            shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
        ) -> Bool {
            // 1) Info contenu : type + taille + accès par plages (clé pour éviter
            //    qu'AVFoundation réclame tout le fichier d'un coup).
            if let info = loadingRequest.contentInformationRequest {
                info.contentType = contentTypeUTI
                info.contentLength = size
                info.isByteRangeAccessSupported = true
            }
            // 2) Demande de données : on lit la plage exacte via SMB.
            guard let dataRequest = loadingRequest.dataRequest else {
                loadingRequest.finishLoading()
                return true
            }
            let offset = dataRequest.requestedOffset
            let remaining = max(0, size - offset)
            let length = min(Int64(dataRequest.requestedLength), remaining)
            guard length > 0 else {
                loadingRequest.finishLoading()
                return true
            }
            let path = relativePath
            let store = self.store
            Task {
                do {
                    let data = try await store.readRange(path, offset: offset, length: Int(length))
                    dataRequest.respond(with: data)
                    loadingRequest.finishLoading()
                } catch {
                    loadingRequest.finishLoading(with: error)
                }
            }
            return true
        }
    }

    /// Renvoie une image (CGImage) d'une frame proche du début de la vidéo réseau,
    /// bornée à `maxPixelSize`. nil si le format ne se laisse pas décoder.
    static func frame(
        store: MediaStore, relativePath: String, size: Int64, ext: String, maxPixelSize: Int
    ) async -> CGImage? {
        guard size > 0 else { return nil }
        let uti = UTType(filenameExtension: ext)?.identifier ?? UTType.mpeg4Movie.identifier
        let loader = Loader(store: store, relativePath: relativePath, size: size, contentTypeUTI: uti)
        // Schéma custom → AVFoundation passe par notre delegate (le chemin importe peu).
        guard let url = URL(string: "yzsmb://video.\(ext.isEmpty ? "mov" : ext)") else { return nil }
        let asset = AVURLAsset(url: url)
        asset.resourceLoader.setDelegate(loader, queue: DispatchQueue(label: "yz.smb.resourceloader"))

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxPixelSize, height: maxPixelSize)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 1, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 1, preferredTimescale: 600)

        let durationSeconds = (try? await asset.load(.duration))?.seconds ?? 0
        let target = durationSeconds.isFinite && durationSeconds > 0 ? min(0.5, durationSeconds / 2) : 0
        let time = CMTime(seconds: target, preferredTimescale: 600)

        let image = try? await generator.image(at: time).image
        withExtendedLifetime(loader) {}   // garder le delegate vivant jusqu'au bout
        return image
    }
}
