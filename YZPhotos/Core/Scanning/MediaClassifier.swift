import Foundation

/// Détection de captures d'écran par score d'indices :
/// PNG (+2), dimensions = écran Apple connu (+2), pas d'EXIF appareil photo (+1),
/// nom de fichier typique (+3). Capture si score ≥ 5.
enum MediaClassifier {
    /// Dimensions (pixels) des écrans Apple, normalisées (min, max) pour couvrir
    /// les deux orientations. iPhone, iPad et tailles Retina Mac courantes.
    static let appleScreenSizes: Set<ScreenSize> = {
        let raw: [(Int, Int)] = [
            // iPhone
            (640, 960), (640, 1136), (750, 1334), (828, 1792),
            (1080, 1920), (1080, 2340), (1125, 2436), (1170, 2532),
            (1179, 2556), (1206, 2622), (1242, 2208), (1242, 2688),
            (1284, 2778), (1290, 2796), (1320, 2868),
            // iPad
            (768, 1024), (1536, 2048), (1620, 2160), (1640, 2360),
            (1668, 2224), (1668, 2388), (1488, 2266), (2048, 2732),
            (2064, 2752), (2360, 1640),
            // Mac Retina
            (2560, 1600), (2880, 1800), (3024, 1964), (3456, 2234),
            (2560, 1664), (2880, 1864), (4480, 2520), (5120, 2880),
        ]
        return Set(raw.map { ScreenSize(min($0.0, $0.1), max($0.0, $0.1)) })
    }()

    struct ScreenSize: Hashable {
        let small: Int
        let large: Int

        init(_ a: Int, _ b: Int) {
            small = Swift.min(a, b)
            large = Swift.max(a, b)
        }
    }

    private static let namePatterns = [
        "screenshot", "screen shot", "capture d'écran", "capture d’écran",
        "capture décran", "bildschirmfoto", "schermafbeelding",
    ]

    static func isScreenshot(
        ext: String,
        fileName: String,
        pixelWidth: Int?,
        pixelHeight: Int?,
        hasCameraExif: Bool
    ) -> Bool {
        var score = 0
        if ext.lowercased() == "png" { score += 2 }
        if let w = pixelWidth, let h = pixelHeight,
           appleScreenSizes.contains(ScreenSize(w, h)) {
            score += 2
        }
        if !hasCameraExif { score += 1 }
        let lowerName = fileName.lowercased().precomposedStringWithCanonicalMapping
        if namePatterns.contains(where: { lowerName.contains($0.precomposedStringWithCanonicalMapping) }) {
            score += 3
        }
        return score >= 5
    }
}
