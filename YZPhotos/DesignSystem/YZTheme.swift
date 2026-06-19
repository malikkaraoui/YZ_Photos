import SwiftUI

// MARK: - Color helpers

extension Color {
    /// Crée une couleur depuis un hex `0xRRGGBB` (ou `0xAARRGGBB`).
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    /// Blanc translucide (rôle fréquent dans le thème Verre).
    static func whiteA(_ a: Double) -> Color { Color(.sRGB, white: 1, opacity: a) }
    /// Noir translucide.
    static func blackA(_ a: Double) -> Color { Color(.sRGB, white: 0, opacity: a) }
}

// MARK: - Thème

/// Les trois univers visuels de YZPhotos.
/// `glass` (Verre) est l'identité par défaut ; `light`/`sombre` sont des replis sobres.
/// Valeurs issues du handoff design (`yz-shared.css`, palette « Optimistic Synergy »).
enum YZThemeKind: String, CaseIterable, Identifiable, Sendable {
    case glass = "Verre"
    case light = "Clair"
    case dark  = "Sombre"

    var id: String { rawValue }

    var sfSymbol: String {
        switch self {
        case .glass: "drop.halffull"
        case .light: "sun.max"
        case .dark:  "moon"
        }
    }

    /// Schéma de couleurs système forcé (status bar, contrôles natifs, claviers…).
    /// Le Verre repose sur un fond aurora sombre → schéma sombre.
    var colorScheme: ColorScheme {
        switch self {
        case .glass, .dark: .dark
        case .light: .light
        }
    }

    var theme: YZTheme { YZTheme.preset(self) }
}

/// Jeu de tokens sémantiques résolus pour un thème donné.
struct YZTheme: Equatable, Sendable {
    let kind: YZThemeKind

    // Fonds / surfaces
    var bg: Color          // fond principal
    var bg2: Color         // surface secondaire (cartes plates, champs)
    var bg3: Color         // surface tertiaire (pistes de progression, segments)
    var card: Color        // carte élevée
    var elev: Color        // surface flottante (modale)

    // Séparateurs
    var sep: Color
    var sep2: Color

    // Texte
    var t1: Color          // primaire
    var t2: Color          // secondaire
    var t3: Color          // tertiaire

    // Sémantique
    var accent: Color
    var accentSoft: Color
    var keep: Color
    var keepSoft: Color
    var trash: Color
    var trashSoft: Color
    var warn: Color
    var warnSoft: Color

    /// Vrai pour le thème Verre : les surfaces utilisent le matériau translucide.
    var isGlass: Bool { kind == .glass }

    static func preset(_ kind: YZThemeKind) -> YZTheme {
        switch kind {
        case .light:
            return YZTheme(
                kind: .light,
                bg: Color(hex: 0xFFFFFF), bg2: Color(hex: 0xF4F4F6), bg3: Color(hex: 0xECECEF),
                card: Color(hex: 0xFFFFFF), elev: Color(hex: 0xFFFFFF),
                sep: .blackA(0.075), sep2: .blackA(0.12),
                t1: Color(hex: 0x161618), t2: Color(hex: 0x6A6A70), t3: Color(hex: 0xA0A0A8),
                accent: Color(hex: 0x5B5BD6), accentSoft: Color(hex: 0xECECFB),
                keep: Color(hex: 0x28B463), keepSoft: Color(hex: 0xE6F7EE),
                trash: Color(hex: 0xE5484D), trashSoft: Color(hex: 0xFCEBEC),
                warn: Color(hex: 0xE08600), warnSoft: Color(hex: 0xFBF1E0)
            )
        case .dark:
            return YZTheme(
                kind: .dark,
                bg: Color(hex: 0x0C0C0E), bg2: Color(hex: 0x161618), bg3: Color(hex: 0x202024),
                card: Color(hex: 0x161618), elev: Color(hex: 0x1C1C20),
                sep: .whiteA(0.08), sep2: .whiteA(0.14),
                t1: Color(hex: 0xF4F4F6), t2: Color(hex: 0x9A9AA2), t3: Color(hex: 0x5E5E66),
                accent: Color(hex: 0x8A88FF), accentSoft: Color(hex: 0x22223A),
                keep: Color(hex: 0x3DD27F), keepSoft: Color(hex: 0x11271C),
                trash: Color(hex: 0xFF5C61), trashSoft: Color(hex: 0x2C1314),
                warn: Color(hex: 0xF5A623), warnSoft: Color(hex: 0x2A2010)
            )
        case .glass:
            return YZTheme(
                kind: .glass,
                bg: .clear, bg2: .whiteA(0.12), bg3: .whiteA(0.18),
                card: .whiteA(0.14), elev: Color(hex: 0x283E4A, alpha: 0.55),
                sep: .whiteA(0.16), sep2: .whiteA(0.30),
                t1: .whiteA(1), t2: .whiteA(0.82), t3: .whiteA(0.58),
                accent: .whiteA(1), accentSoft: .whiteA(0.22),
                keep: Color(hex: 0xB6D84B), keepSoft: Color(hex: 0xB6D84B, alpha: 0.28),
                trash: Color(hex: 0xF06A8C), trashSoft: Color(hex: 0xF06A8C, alpha: 0.28),
                warn: Color(hex: 0xF0B43E), warnSoft: Color(hex: 0xF0B43E, alpha: 0.26)
            )
        }
    }
}

// MARK: - Rayons

enum YZRadius {
    static let chip: CGFloat = 8
    static let button: CGFloat = 12
    static let card: CGFloat = 16
    static let modal: CGFloat = 22
}

// MARK: - Injection environnement

private struct YZThemeKey: EnvironmentKey {
    static let defaultValue = YZTheme.preset(.glass)
}

extension EnvironmentValues {
    var yzTheme: YZTheme {
        get { self[YZThemeKey.self] }
        set { self[YZThemeKey.self] = newValue }
    }
}
