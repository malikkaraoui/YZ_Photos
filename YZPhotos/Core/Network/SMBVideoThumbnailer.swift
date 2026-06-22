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
            // Plafond par lecture (8 Mo) : sinon AMSMB2 alloue une Data énorme pour
            // une requête « tout le reste » et l'app crashe (allocation). On répond
            // partiellement ; AVFoundation redemande la suite.
            let length = min(Int64(dataRequest.requestedLength), remaining, 8_000_000)
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
                    AppLog.error("vidéo SMB readRange @\(offset)+\(length) \(path)", error)
                    loadingRequest.finishLoading(with: error)
                }
            }
            return true
        }
    }

    /// Construit un `AVURLAsset` qui **streame** la vidéo réseau par plages (pour
    /// la LECTURE). Garder le `Loader` retourné vivant tant que le lecteur existe
    /// (le resource loader ne retient pas son delegate).
    static func streamingAsset(
        store: MediaStore, relativePath: String, size: Int64, ext: String
    ) -> (asset: AVURLAsset, loader: Loader)? {
        guard size > 0, let url = URL(string: "yzsmb://video.\(ext.isEmpty ? "mov" : ext)") else { return nil }
        let uti = UTType(filenameExtension: ext)?.identifier ?? UTType.mpeg4Movie.identifier
        let loader = Loader(store: store, relativePath: relativePath, size: size, contentTypeUTI: uti)
        let asset = AVURLAsset(url: url)
        asset.resourceLoader.setDelegate(loader, queue: DispatchQueue(label: "yz.smb.player"))
        return (asset, loader)
    }

    /// Taille de chaque morceau lu (tête et queue). ~8 Mo couvrent l'index `moov`
    /// et la première image clé de la quasi-totalité des vidéos.
    static let chunkSize: Int64 = 8_000_000
    /// Plafond pour le repli « fichier complet » (si tête+queue ne suffit pas).
    static let maxDownloadForThumbnail: Int64 = 45_000_000

    /// Vignette d'une vidéo réseau, **sans télécharger toute la vidéo** :
    /// on ne lit que la TÊTE + la QUEUE (~16 Mo max, quelle que soit la taille)
    /// dans un fichier creux local. La queue porte l'index (moov souvent en fin
    /// sur les .mov iPhone), la tête la 1ʳᵉ image → AVFoundation décode sans le
    /// milieu. Repli sur le fichier complet (petites vidéos) si ça échoue.
    static func frame(
        store: MediaStore, relativePath: String, size: Int64, ext: String, maxPixelSize: Int
    ) async -> CGImage? {
        guard size > 0 else { return nil }

        // Petite vidéo : la tête+queue se recouvrent → autant tout lire (c'est petit).
        if size <= chunkSize * 2 {
            return await decodeFrame(store: store, relativePath: relativePath, size: size,
                                     ext: ext, maxPixelSize: maxPixelSize, headTail: false)
        }
        // Grosse vidéo : tête + queue uniquement (~16 Mo), quelle que soit la taille.
        if let img = await decodeFrame(store: store, relativePath: relativePath, size: size,
                                       ext: ext, maxPixelSize: maxPixelSize, headTail: true) {
            return img
        }
        // Repli : fichier complet, seulement si raisonnable.
        guard size <= maxDownloadForThumbnail else { return nil }
        return await decodeFrame(store: store, relativePath: relativePath, size: size,
                                 ext: ext, maxPixelSize: maxPixelSize, headTail: false)
    }

    private static func decodeFrame(
        store: MediaStore, relativePath: String, size: Int64, ext: String,
        maxPixelSize: Int, headTail: Bool
    ) async -> CGImage? {
        let safeExt = ext.isEmpty ? "mov" : ext
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("yzvid_\(UUID().uuidString).\(safeExt)")
        defer { try? FileManager.default.removeItem(at: tmp) }

        do {
            FileManager.default.createFile(atPath: tmp.path, contents: nil)
            let fh = try FileHandle(forWritingTo: tmp)
            defer { try? fh.close() }
            if headTail {
                // Fichier creux à la vraie taille : le milieu reste des zéros
                // (jamais téléchargé), AVFoundation n'en a pas besoin pour la 1ʳᵉ image.
                try fh.truncate(atOffset: UInt64(size))
                let head = try await store.readRange(relativePath, offset: 0, length: Int(chunkSize))
                try fh.seek(toOffset: 0)
                try fh.write(contentsOf: head)
                let tailOffset = size - chunkSize
                let tail = try await store.readRange(relativePath, offset: tailOffset, length: Int(chunkSize))
                try fh.seek(toOffset: UInt64(tailOffset))
                try fh.write(contentsOf: tail)
            } else {
                let data = try await store.readRange(relativePath, offset: 0, length: Int(size))
                guard !data.isEmpty else { return nil }
                try fh.write(contentsOf: data)
            }
        } catch {
            AppLog.error("vidéo SMB lecture \(relativePath)", error)
            return nil
        }

        let asset = AVURLAsset(url: tmp)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxPixelSize, height: maxPixelSize)
        generator.requestedTimeToleranceBefore = .positiveInfinity
        generator.requestedTimeToleranceAfter = .positiveInfinity

        let durationSeconds = (try? await asset.load(.duration))?.seconds ?? 0
        let target = durationSeconds.isFinite && durationSeconds > 2 ? min(1, durationSeconds / 2) : 0
        let time = CMTime(seconds: target, preferredTimescale: 600)

        defer { generator.cancelAllCGImageGeneration() }   // libère le décodeur
        do {
            let result = try await generator.image(at: time)
            AppLog.log("vidéo SMB : miniature OK (\(headTail ? "tête+queue" : "complet") \(relativePath))", "🎞️")
            return result.image
        } catch {
            return nil
        }
    }
}
