import SwiftUI

/// Échelle typographique YZPhotos — SF Pro système, valeurs issues de `tokens.json`.
/// Les titres « display » utilisent un poids fort (800) et un crénage négatif (-0.03em),
/// appliqué via `.yzTracking()` au niveau du `Text` (SwiftUI ne crénant pas la `Font` seule).
enum YZFont {
    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy) }

    static let largeTitle = Font.system(size: 34, weight: .bold)
    static let title1     = Font.system(size: 30, weight: .bold)
    static let title2     = Font.system(size: 22, weight: .semibold)
    static let headline   = Font.system(size: 17, weight: .semibold)
    static let body       = Font.system(size: 16, weight: .regular)
    static let bodyMedium = Font.system(size: 16, weight: .medium)
    static let subhead    = Font.system(size: 14, weight: .regular)
    static let subheadSemi = Font.system(size: 14, weight: .semibold)
    static let footnote   = Font.system(size: 13, weight: .regular)
    static let caption    = Font.system(size: 11, weight: .regular)
    static let captionSemi = Font.system(size: 11, weight: .semibold)
}

extension View {
    /// Crénage proportionnel à la taille (-0.03em) pour les titres display.
    func yzTracking(_ size: CGFloat) -> some View { tracking(size * -0.03) }
}

extension Text {
    /// Style « display » : poids 800 + crénage serré.
    func yzDisplay(_ size: CGFloat) -> Text {
        font(.system(size: size, weight: .heavy)).tracking(size * -0.03)
    }
}
