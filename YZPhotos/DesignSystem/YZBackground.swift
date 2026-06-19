import SwiftUI

/// Fond plein écran propre au thème.
/// Verre → dégradé aurora « Storm Blue » + halos colorés en dérive (jamais statiques).
/// Clair / Sombre → fond uni.
struct YZBackground: View {
    let theme: YZTheme

    var body: some View {
        if theme.isGlass {
            AuroraBackground()
        } else {
            theme.bg
        }
    }
}

/// Aurora « Optimistic Synergy » : dégradé Storm Blue + 4 halos qui dérivent en continu.
struct AuroraBackground: View {
    /// Halos : (couleur, point d'ancrage, taille relative, vitesse de dérive Hz).
    private struct Blob {
        let color: Color
        let anchor: UnitPoint
        let radiusFraction: CGFloat
        let speed: Double
        let phase: Double
    }

    private let blobs: [Blob] = [
        Blob(color: Color(hex: 0xE87B3E, alpha: 0.50), anchor: UnitPoint(x: 0.14, y: 0.16), radiusFraction: 0.42, speed: 0.30, phase: 0.0),
        Blob(color: Color(hex: 0xC3D24A, alpha: 0.40), anchor: UnitPoint(x: 0.88, y: 0.12), radiusFraction: 0.40, speed: 0.22, phase: 1.6),
        Blob(color: Color(hex: 0xB23A5D, alpha: 0.48), anchor: UnitPoint(x: 0.90, y: 0.90), radiusFraction: 0.46, speed: 0.26, phase: 3.0),
        Blob(color: Color(hex: 0xE88AA0, alpha: 0.40), anchor: UnitPoint(x: 0.08, y: 0.92), radiusFraction: 0.44, speed: 0.20, phase: 4.4),
    ]

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack {
                    LinearGradient(
                        stops: [
                            .init(color: Color(hex: 0x3A5C6E), location: 0),
                            .init(color: Color(hex: 0x244252), location: 0.48),
                            .init(color: Color(hex: 0x152D3A), location: 1),
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    ForEach(0..<blobs.count, id: \.self) { i in
                        let b = blobs[i]
                        // centre = ancre + 5% d'amplitude * sin(2π·vitesse·t + phase)
                        let amp: CGFloat = 0.05
                        let dx = amp * CGFloat(sin(2 * .pi * b.speed * t + b.phase))
                        let dy = amp * CGFloat(cos(2 * .pi * b.speed * t + b.phase))
                        RadialGradient(
                            colors: [b.color, b.color.opacity(0)],
                            center: UnitPoint(x: b.anchor.x + dx, y: b.anchor.y + dy),
                            startRadius: 0,
                            endRadius: max(w, h) * b.radiusFraction
                        )
                    }
                }
                .blur(radius: 10)
                .ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
    }
}
