import SwiftUI

/// Une carte du deck : image plein cadre + bandeau d'infos en bas
/// (les infos en un coup d'œil : nom, dossier, taille, dimensions, date).
struct SwipeCardView: View {
    let file: FileRecord
    let root: URL

    @Environment(AppEnvironment.self) private var env
    @State private var image: UIImage?

    private let radius: CGFloat = 24

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(.black)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()   // photo ENTIÈRE visible (ajustée, jamais recadrée/zoomée)
            } else {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
            }
            if file.kind == .video {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(radius: 8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(alignment: .bottom) { infoBar }
        .overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .shadow(color: .black.opacity(0.45), radius: 30, y: 18)
        .task(id: file.id) {
            image = await env.thumbnails.cardImage(for: file, store: env.currentStore ?? LocalMediaStore(root: root))
        }
    }

    private var infoBar: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                if file.isScreenshot { badge("Capture", icon: "camera.viewfinder") }
                if file.dupGroupId != nil {
                    badge(file.dupKind == .exact ? "Doublon" : "Similaire", icon: "square.on.square")
                }
                if let duration = file.durationSeconds {
                    badge(Fmt.duration(duration), icon: "play.fill")
                }
                Spacer()
            }
            HStack(spacing: 8) {
                Text(file.fileName)
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                Text(Fmt.bytes(file.sizeBytes))
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
            }
            HStack(spacing: 12) {
                Text(folderName).lineLimit(1)
                if let w = file.pixelWidth, let h = file.pixelHeight {
                    Text("\(w) × \(h)")
                }
                Text(Fmt.date(file.captureDate ?? file.modifiedAt))
                Spacer()
            }
            .font(.system(size: 12.5))
            .foregroundStyle(.white.opacity(0.82))
        }
        .foregroundStyle(.white)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [.black.opacity(0), .black.opacity(0.55)],
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    private var folderName: String {
        let dir = (file.relativePath as NSString).deletingLastPathComponent
        if file.sourceType == .photosLibrary {
            let lib = dir.components(separatedBy: "/").first { $0.lowercased().hasSuffix(".photoslibrary") }
            return "📚 \(lib ?? "Bibliothèque Photos")"
        }
        return dir.isEmpty ? "Racine du disque" : dir
    }

    private func badge(_ text: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay { Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.5) }
    }
}
