import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Génération et cache des miniatures (disque + mémoire), et analyse média :
/// un seul décodage sert à la fois la miniature, le dHash, les dimensions
/// et les métadonnées EXIF.
/// Sémaphore asynchrone : borne le nombre d'opérations LOURDES simultanées
/// (génération de vignettes vidéo) pour ne pas saturer la mémoire.
actor AsyncGate {
    private var available: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []
    init(_ count: Int) { available = count }
    func acquire() async {
        if available > 0 { available -= 1; return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func release() {
        if waiters.isEmpty { available += 1 }
        else { waiters.removeFirst().resume() }
    }
}

final class ThumbnailStore: @unchecked Sendable {
    static let maxPixelSize = 512

    /// Génération de vignettes VIDÉO : UNE à la fois. Décoder une image vidéo
    /// alloue un buffer pleine résolution (4K ≈ 33 Mo) → en paralléliser = jetsam.
    private let videoGate = AsyncGate(1)
    /// Horodatage de la dernière alerte mémoire : pendant un court répit, on
    /// saute la génération vidéo (la plus coûteuse) pour laisser respirer.
    private var lastMemoryWarning = Date.distantPast

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
        // Double plafond : nombre ET coût total en octets (le plus strict gagne).
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 40 * 1024 * 1024   // ~40 Mo de miniatures
        cardCache.countLimit = 5
        cardCache.totalCostLimit = 24 * 1024 * 1024
        // Filet de sécurité : à la moindre alerte mémoire du système, on vide les
        // caches mémoire (le cache disque reste, donc rien n'est reperdu).
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: nil
        ) { [weak self] _ in
            self?.purgeMemoryCaches()
            self?.lastMemoryWarning = Date()
            AppLog.log("Alerte mémoire système → caches miniatures vidés", "⚠️")
        }
    }

    /// Vrai si une alerte mémoire est survenue il y a moins de 8 s : on saute
    /// alors la génération vidéo (la plus lourde) pour laisser la mémoire respirer.
    private var underMemoryPressure: Bool {
        Date().timeIntervalSince(lastMemoryWarning) < 12
    }

    /// Coût mémoire approximatif d'une image (octets) pour le plafonnement NSCache.
    private static func cost(of image: UIImage) -> Int {
        let scale = image.scale
        return Int(image.size.width * scale * image.size.height * scale) * 4
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
        memoryCache.setObject(image, forKey: NSNumber(value: id), cost: Self.cost(of: image))
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
        } else if file.kind == .video {
            // Vidéo réseau (pas d'URL locale) : frame via lecture par plages SMB.
            // LOURD → une seule à la fois (videoGate) et pas sous pression mémoire.
            if !underMemoryPressure {
                await videoGate.acquire()
                let frame = await SMBVideoThumbnailer.frame(
                    store: store, relativePath: file.relativePath,
                    size: file.sizeBytes, ext: file.ext, maxPixelSize: Self.maxPixelSize
                )
                // Court répit AVANT de libérer : espace les décodages → la mémoire
                // a le temps d'être récupérée entre deux (anti-jetsam).
                try? await Task.sleep(nanoseconds: 150_000_000)
                await videoGate.release()
                if let frame { writeCache(frame, fileID: id) }
            }
        }
        return cachedThumbnail(forFileID: id)
    }

    /// Nombre de préchargements en cours + plafond strict. Au-delà, on **abandonne**
    /// le surplus (pas d'empilement) : c'est la clé anti-crash quand on fait
    /// défiler/sélectionner des centaines de photos (chaque lecture réseau charge
    /// une photo entière en RAM — il ne faut surtout pas en accumuler).
    private var prefetchInFlight = 0
    private static let prefetchMax = 3

    /// Précharge en arrière-plan (priorité basse, borné) les miniatures à venir,
    /// pour fluidifier le défilement. Ignore le cache déjà chaud ; coalescé avec
    /// les cellules visibles ; jette les demandes en trop plutôt que de saturer.
    func prefetch(_ files: [FileRecord], store: MediaStore) {
        for file in files {
            // Pas de préchargement pour les vidéos : trop coûteux (décodage) pour
            // du spéculatif. Elles se génèrent à la demande, une à une.
            guard let id = file.id, file.kind == .photo, cachedThumbnail(forFileID: id) == nil else { continue }
            let go: Bool = {
                inFlightLock.lock(); defer { inFlightLock.unlock() }
                guard inFlight[id] == nil, prefetchInFlight < Self.prefetchMax else { return false }
                prefetchInFlight += 1
                return true
            }()
            guard go else { continue }   // saturé → on abandonne (pas de file d'attente)
            Task.detached(priority: .utility) { [weak self] in
                _ = await self?.thumbnail(for: file, store: store)
                guard let self else { return }
                self.inFlightLock.lock(); self.prefetchInFlight -= 1; self.inFlightLock.unlock()
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
        } else if file.kind == .video {
            // Vidéo réseau : génère la frame (1 à la fois, sauf pression mémoire).
            if cachedThumbnail(forFileID: id) == nil, !underMemoryPressure {
                await videoGate.acquire()
                let frame = await SMBVideoThumbnailer.frame(
                    store: store, relativePath: file.relativePath,
                    size: file.sizeBytes, ext: file.ext, maxPixelSize: Self.maxPixelSize
                )
                await videoGate.release()
                if let frame { writeCache(frame, fileID: id) }
            }
            image = cachedThumbnail(forFileID: id)
        } else {
            image = cachedThumbnail(forFileID: id)
        }
        if let image {
            cardCache.setObject(image, forKey: NSNumber(value: id), cost: Self.cost(of: image))
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
