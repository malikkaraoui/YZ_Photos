import SwiftUI

/// Une carte du deck : la photo (ou vidéo) en **remplissage** plein cadre,
/// coins très arrondis, sans aucune métadonnée. Son seul rôle : présenter le
/// média pour décider — garder ou jeter. Pour les détails (nom, chemin, taille)
/// et la photo entière, on tape la carte (→ `FullScreenMediaView`).
struct SwipeCardView: View {
    let file: FileRecord
    let root: URL
    /// Affiche la barre glass (nom · taille) en bas — seulement sur la carte du dessus.
    var showInfo: Bool = false

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
            // Barre glass nom · taille, posée en bas de la carte (façon mockup).
            .overlay(alignment: .bottom) {
                if showInfo {
                    HStack(spacing: 7) {
                        Image(systemName: file.kind == .video ? "video.fill" : "photo.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("\(file.fileName)  ·  \(Fmt.bytes(file.sizeBytes))")
                            .font(.system(size: 13.5, weight: .medium))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background {
                        Capsule().fill(.ultraThinMaterial)
                        Capsule().fill(.black.opacity(0.28))
                    }
                    .overlay { Capsule().strokeBorder(.white.opacity(0.28), lineWidth: 0.5) }
                    .padding(14)
                }
            }
            .shadow(color: .black.opacity(0.40), radius: 26, y: 16)
        }
        .task(id: file.id) {
            let store = env.currentStore ?? LocalMediaStore(root: root)
            // Réessaie si le décodage rend nil (pression mémoire passagère, coupure
            // réseau) → la carte ne reste plus bloquée sur le spinner.
            for _ in 0..<5 {
                if Task.isCancelled { return }
                if let img = await env.thumbnails.cardImage(for: file, store: store) {
                    image = img
                    return
                }
                try? await Task.sleep(for: .seconds(1.5))
            }
        }
    }
}
