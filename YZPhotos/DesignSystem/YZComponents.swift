import SwiftUI

// MARK: - Surface (carte / verre)

extension View {
    /// Applique le matériau de surface du thème : verre translucide (Verre) ou
    /// carte pleine + ombre (Clair/Sombre).
    func yzSurface(_ theme: YZTheme,
                   radius: CGFloat = YZRadius.card,
                   strong: Bool = false,
                   elevated: Bool = false) -> some View {
        modifier(YZSurfaceModifier(theme: theme, radius: radius, strong: strong, elevated: elevated))
    }

    /// Fond plein écran du thème, posé derrière le contenu.
    func yzScreenBackground(_ theme: YZTheme) -> some View {
        background(YZBackground(theme: theme))
    }
}

private struct YZSurfaceModifier: ViewModifier {
    let theme: YZTheme
    let radius: CGFloat
    let strong: Bool
    let elevated: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if theme.isGlass {
            content
                .background {
                    ZStack {
                        shape.fill(.ultraThinMaterial)
                        shape.fill(strong ? Color.whiteA(0.22) : Color.whiteA(0.14))
                    }
                }
                .overlay { shape.strokeBorder(Color.whiteA(0.42), lineWidth: 0.5) }
                .shadow(color: Color(hex: 0x081C26, alpha: 0.30),
                        radius: elevated ? 20 : 12, y: elevated ? 12 : 8)
        } else {
            content
                .background((elevated ? theme.elev : theme.card), in: shape)
                .overlay { shape.strokeBorder(theme.sep, lineWidth: 0.5) }
                .shadow(color: .blackA(theme.kind == .dark ? 0.40 : 0.08),
                        radius: elevated ? 24 : 10, y: elevated ? 12 : 4)
        }
    }
}

// MARK: - Boutons

struct YZButtonStyle: ButtonStyle {
    enum Variant { case primary, secondary, destructive, keep }
    enum Size { case md, lg }

    var variant: Variant = .primary
    var size: Size = .md
    var fullWidth: Bool = false

    init(_ variant: Variant = .primary, size: Size = .md, fullWidth: Bool = false) {
        self.variant = variant
        self.size = size
        self.fullWidth = fullWidth
    }

    func makeBody(configuration: Configuration) -> some View {
        Inner(variant: variant, size: size, fullWidth: fullWidth, configuration: configuration)
    }

    struct Inner: View {
        let variant: Variant
        let size: Size
        let fullWidth: Bool
        let configuration: ButtonStyleConfiguration
        @Environment(\.yzTheme) private var theme

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: YZRadius.button, style: .continuous)
            configuration.label
                .font(.system(size: size == .lg ? 15.5 : 14, weight: .semibold))
                .foregroundStyle(fg)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .padding(.vertical, size == .lg ? 13 : 9)
                .padding(.horizontal, size == .lg ? 22 : 16)
                .background { background(shape) }
                .overlay { if needsBorder { shape.strokeBorder(borderColor, lineWidth: 0.5) } }
                .opacity(configuration.isPressed ? 0.82 : 1)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        }

        @ViewBuilder private func background(_ shape: RoundedRectangle) -> some View {
            switch variant {
            case .primary:
                if theme.isGlass {
                    ZStack { shape.fill(.ultraThinMaterial); shape.fill(Color(hex: 0xE87B3E, alpha: 0.42)) }
                } else { shape.fill(theme.accent) }
            case .destructive:
                if theme.isGlass {
                    ZStack { shape.fill(.ultraThinMaterial); shape.fill(Color(hex: 0xF06A8C, alpha: 0.40)) }
                } else { shape.fill(theme.trash) }
            case .keep:
                if theme.isGlass {
                    ZStack { shape.fill(.ultraThinMaterial); shape.fill(Color(hex: 0xB6D84B, alpha: 0.42)) }
                } else { shape.fill(theme.keep) }
            case .secondary:
                if theme.isGlass {
                    ZStack { shape.fill(.ultraThinMaterial); shape.fill(Color.whiteA(0.14)) }
                } else { shape.fill(theme.bg2) }
            }
        }

        private var fg: Color {
            switch variant {
            case .primary, .destructive, .keep: return .white
            case .secondary: return theme.isGlass ? .white : theme.t1
            }
        }
        private var needsBorder: Bool { theme.isGlass || variant == .secondary }
        private var borderColor: Color { theme.isGlass ? .whiteA(0.42) : theme.sep }
    }
}

// MARK: - Badge / pastille

struct YZBadge: View {
    enum Tone { case neutral, accent, keep, trash, warn }
    var text: String
    var systemImage: String?
    var tone: Tone = .neutral
    @Environment(\.yzTheme) private var theme

    init(_ text: String, systemImage: String? = nil, tone: Tone = .neutral) {
        self.text = text; self.systemImage = systemImage; self.tone = tone
    }

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage { Image(systemName: systemImage) }
            Text(text)
        }
        .font(.system(size: 12.5, weight: .semibold))
        .foregroundStyle(fg)
        .padding(.vertical, 5)
        .padding(.horizontal, 11)
        .background(bg, in: Capsule())
    }

    private var pair: (Color, Color) {
        switch tone {
        case .neutral: (theme.t2, theme.bg3)
        case .accent:  (theme.accent, theme.accentSoft)
        case .keep:    (theme.keep, theme.keepSoft)
        case .trash:   (theme.trash, theme.trashSoft)
        case .warn:    (theme.warn, theme.warnSoft)
        }
    }
    private var fg: Color { theme.isGlass ? .white : pair.0 }
    private var bg: Color { pair.1 }
}

// MARK: - Barre de progression

struct YZProgressBar: View {
    var value: Double            // 0...1
    var tone: Color?
    var height: CGFloat = 6
    @Environment(\.yzTheme) private var theme

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.isGlass ? Color.whiteA(0.22) : theme.bg3)
                Capsule().fill(tone ?? theme.accent)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}

// MARK: - État vide

struct YZEmptyState: View {
    var systemImage: String
    var title: String
    var message: String?
    @Environment(\.yzTheme) private var theme

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(theme.t3)
                .frame(width: 80, height: 80)
                .background {
                    Circle().fill(theme.isGlass ? Color.whiteA(0.14) : theme.bg2)
                    if theme.isGlass { Circle().fill(.ultraThinMaterial) }
                }
                .overlay { if theme.isGlass { Circle().strokeBorder(Color.whiteA(0.42), lineWidth: 0.5) } }
                .padding(.bottom, 10)
            Text(title).font(.system(size: 20, weight: .bold)).foregroundStyle(theme.t1)
            if let message {
                Text(message)
                    .font(YZFont.subhead)
                    .foregroundStyle(theme.t2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
