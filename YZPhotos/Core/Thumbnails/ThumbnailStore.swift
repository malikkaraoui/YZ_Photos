import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Génération et cache des miniatures (disque + mémoire), et analyse média :
/// un seul décodage sert à la fois la miniature, le dHash, les dimensions
/// et les métadonnées EXIF.
final class ThumbnailStore: @unchecked Sendable {
    static let maxPixelSize = 512

    struct PhotoAnalysis {
        var pixelWidth: Int?
        var pixelHeight: Int?
        var captureDate: Date?
        var hasCameraExif: Bool
        var dHash: UInt64?
    }

    struct VideoAnalysis {
        var pixelWidth: Int?
        var pixelHeight: Int?
        var durationSeconds: Double?
    }

    private let memoryCache = NSCache<NSNumber, UIImage>()
    /// Images de cartes du deck (1280 px) : permet le préchargement des suivantes.
    private let cardCache = NSCache<NSNumber, UIImage>()
    private let cacheRoot: URL

    /// Lectures de miniatures en cours, par id : coalesce les demandes simultanées
    /// (cellule visible + préchargement) → une seule lecture réseau par fichier.
    private var inFlight: [Int64: Task<UIImage?, Never>] = [:]
    private let inFlightLock = NSLock()

    private static let exifDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return f
    }()

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheRoot = caches.appendingPathComponent("Thumbnails", isDirectory: true)
        // Limites mémoire prudentes : une UIImage 512 px ≈ 1 Mo, une carte
        // 1280 px ≈ 6,5 Mo. Trop d'images en RAM = l'app se fait tuer.
        memoryCache.countLimit = 250
        cardCache.countLimit = 12
    }

    // MARK: - Cache

    /// Vide les caches mémoire (garde-fou anti-jetsam pendant le scan).
    /// Le cache disque, lui, reste intact.
    func purgeMemoryCaches() {
        memoryCache.removeAllObjects()
        cardCache.removeAllObjects()
    }

    /// Sous-dossiers par id % 256 : évite 100k fichiers dans un seul dossier.
    func cacheURL(forFileID id: Int64) -> URL {
        let bucket = String(format: "%02x", id % 256)
        return cacheRoot
            .appendingPathComponent(bucket, isDirectory: true)
            .appendingPathComponent("\(id).jpg")
    }

    func cachedThumbnail(forFileID id: Int64) -> UIImage? {
        if let image = memoryCache.object(forKey: NSNumber(value: id)) {
            return image
        }
        let url = cacheURL(forFileID: id)
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        memoryCache.setObject(image, forKey: NSNumber(value: id))
        return image
    }

    /// Miniature pour l'UI : cache, sinon génération à la demande.
    /// USB → décodage direct depuis l'URL ; réseau → lecture des octets via SMB.
    /// Les demandes simultanées sur le même fichier sont coalescées (une lecture).
    func thumbnail(for file: FileRecord, store: MediaStore) async -> UIImage? {
        guard let id = file.id else { return nil }
        if let cached = cachedThumbnail(forFileID: id) { return cached }

        let task: Task<UIImage?, Never> = {
            inFlightLock.lock(); defer { inFlightLock.unlock() }
            if let existing = inFlight[id] { return existing }
            let created = Task<UIImage?, Never> { [weak self] in
                await self?.generateThumbnail(id: id, file: file, store: store) ?? nil
            }
            inFlight[id] = created
            return created
        }()

        let result = await task.value
        inFlightLock.lock(); inFlight[id] = nil; inFlightLock.unlock()
        return result
    }

    private func generateThumbnail(id: Int64, file: FileRecord, store: MediaStore) async -> UIImage? {
        if let url = store.localURL(for: file) {
            switch file.kind {
            case .photo: _ = analyzePhoto(fileID: id, url: url)
            case .video: _ = await analyzeVideo(fileID: id, url: url)
            }
        } else if file.kind == .photo, let data = try? await store.data(for: file) {
            _ = autoreleasepool { analyzePhoto(fileID: id, data: data) }
        }
        // Vidéo réseau : pas de miniature pour l'instant (lecture réseau ultérieure).
        return cachedThumbnail(forFileID: id)
    }

    /// Précharge en arrière-plan (priorité basse) les miniatures d'une liste de
    /// fichiers — pour que la grille soit déjà prête quand on y arrive. Ignore
    /// ceux déjà en cache ; la coalescence évite tout double-travail avec les
    /// cellules visibles. Sur réseau, les lectures restent sérialisées par SMB.
    func prefetch(_ files: [FileRecord], store: MediaStore) {
        for file in files {
            guard let id = file.id, cachedThumbnail(forFileID: id) == nil else { continue }
            Task.detached(priority: .utility) { [weak self] in
                _ = await self?.thumbnail(for: file, store: store)
            }
        }
    }

    /// Image pleine qualité pour la carte du deck (décodage à 1280 px), avec cache
    /// mémoire court pour le préchargement des cartes suivantes.
    func cardImage(for file: FileRecord, store: MediaStore) async -> UIImage? {
        guard let id = file.id else { return nil }
        if let cached = cardCache.object(forKey: NSNumber(value: id)) { return cached }
        var image: UIImage?
        if let url = store.localURL(for: file) {
            switch file.kind {
            case .photo:
                image = decodeImage(url: url, maxPixelSize: 1280).map(UIImage.init(cgImage:))
            case .video:
                if cachedThumbnail(forFileID: id) == nil {
                    _ = await analyzeVideo(fileID: id, url: url)
                }
                image = cachedThumbnail(forFileID: id)
            }
        } else if file.kind == .photo, let data = try? await store.data(for: file) {
            image = autoreleasepool { decodeImage(data: data, maxPixelSize: 1280).map(UIImage.init(cgImage:)) }
        } else {
            // Vidéo réseau : pas d'aperçu plein cadre pour l'instant (phase ultérieure).
            image = cachedThumbnail(forFileID: id)
        }
        if let image {
            cardCache.setObject(image, forKey: NSNumber(value: id))
        }
        return image
    }

    // MARK: - Analyse (passe 2 du scan)

    func analyzePhoto(fileID: Int64, url: URL) -> PhotoAnalysis? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else {
            return nil
        }
        return analyzePhoto(fileID: fileID, source: source)
    }

    /// Variante réseau : décodage depuis les octets lus en SMB.
    func analyzePhoto(fileID: Int64, data: Data) -> PhotoAnalysis? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }
        return analyzePhoto(fileID: fileID, source: source)
    }

    private func analyzePhoto(fileID: Int64, source: CGImageSource) -> PhotoAnalysis? {
        var analysis = PhotoAnalysis(hasCameraExif: false)

        if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
            analysis.pixelWidth = properties[kCGImagePropertyPixelWidth] as? Int
            analysis.pixelHeight = properties[kCGImagePropertyPixelHeight] as? Int
            let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
            analysis.hasCameraExif = tiff?[kCGImagePropertyTIFFMake] != nil
                || tiff?[kCGImagePropertyTIFFModel] != nil
            let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
            if let dateString = exif?[kCGImagePropertyExifDateTimeOriginal] as? String {
                analysis.captureDate = Self.exifDateFormatter.date(from: dateString)
            }
        }

        let thumbOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: Self.maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ] as [CFString: Any] as CFDictionary
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions) else {
            return analysis
        }
        analysis.dHash = DHash.compute(from: thumbnail)
        writeCache(thumbnail, fileID: fileID)
        return analysis
    }

    func analyzeVideo(fileID: Int64, url: URL) async -> VideoAnalysis {
        var analysis = VideoAnalysis()
        let asset = AVURLAsset(url: url)
        if let duration = try? await asset.load(.duration) {
            analysis.durationSeconds = duration.seconds.isFinite ? duration.seconds : nil
        }
        if let track = try? await asset.loadTracks(withMediaType: .video).first,
           let size = try? await track.load(.naturalSize) {
            analysis.pixelWidth = Int(abs(size.width))
            analysis.pixelHeight = Int(abs(size.height))
        }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: Self.maxPixelSize, height: Self.maxPixelSize)
        let seconds = min(0.5, (analysis.durationSeconds ?? 0) / 2)
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        if let result = try? await generator.image(at: time) {
            writeCache(result.image, fileID: fileID)
        }
        return analysis
    }

    // MARK: - Privé

    private func decodeImage(url: URL, maxPixelSize: Int) -> CGImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else {
            return nil
        }
        return makeThumbnail(source: source, maxPixelSize: maxPixelSize)
    }

    private func decodeImage(data: Data, maxPixelSize: Int) -> CGImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }
        return makeThumbnail(source: source, maxPixelSize: maxPixelSize)
    }

    private func makeThumbnail(source: CGImageSource, maxPixelSize: Int) -> CGImage? {
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
        ] as [CFString: Any] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }

    private func writeCache(_ image: CGImage, fileID: Int64) {
        let url = cacheURL(forFileID: fileID)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return }
        let properties = [kCGImageDestinationLossyCompressionQuality: 0.75] as CFDictionary
        CGImageDestinationAddImage(destination, image, properties)
        CGImageDestinationFinalize(destination)
    }
}
