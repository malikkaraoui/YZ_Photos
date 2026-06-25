import SwiftUI

/// Une carte du deck : la photo (ou vidéo) en **remplissage** plein cadre,
/// coins très arrondis, sans aucune métadonnée. Son seul rôle : présenter le
/// média pour décider — garder ou jeter. Pour les détails (nom, chemin, taille)
/// et la photo entière, on tape la carte (→ `FullScreenMediaView`).
struct SwipeCardView: View {
    let file: FileRecord
    let root: URL

    @Environment(AppEnvironment.self) private var env
    @State private var image: UIImage?

    private let radius: CGFloat = 28

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Fond sombre tant que la miniature charge (jamais de bandes noires
                // visibles ensuite : l'image REMPLIT la carte).
                Rectangle().fill(Color.black.opacity(0.25))
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                }
                if file.kind == .video {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.white.opacity(0.92))
                        .shadow(radius: 8)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(.white.opacity(0.16), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.40), radius: 26, y: 16)
        }
        .task(id: file.id) {
            image = await env.thumbnails.cardImage(for: file, store: env.currentStore ?? LocalMediaStore(root: root))
        }
    }
}
