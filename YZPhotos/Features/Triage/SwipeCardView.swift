import SwiftUI

/// Une carte du deck : image plein cadre + bandeau d'infos en bas
/// (les infos en un coup d'œil : nom, dossier, taille, dimensions, date).
struct SwipeCardView: View {
    let file: FileRecord
    let root: URL

    @Environment(AppEnvironment.self) private var env
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(.black)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
            }
            if file.kind == .video {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(radius: 8)
            }
        }
        .overlay(alignment: .bottom) { infoBar }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
        .task(id: file.id) {
            image = await env.thumbnails.cardImage(for: file, driveRoot: root)
        }
    }

    private var infoBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(file.fileName)
                    .font(.title3.bold())
                    .lineLimit(1)
                if file.isScreenshot {
                    badge("Capture", color: .purple)
                }
                if file.dupGroupId != nil {
                    badge(file.dupKind == .exact ? "Doublon" : "Similaire", color: .orange)
                }
                if let duration = file.durationSeconds {
                    badge(Fmt.duration(duration), color: .blue)
                }
                Spacer()
                Text(Fmt.bytes(file.sizeBytes))
                    .font(.title3.bold().monospacedDigit())
            }
            HStack(spacing: 14) {
                Text(folderName)
                    .lineLimit(1)
                if let w = file.pixelWidth, let h = file.pixelHeight {
                    Text("\(w) × \(h)")
                }
                Text(Fmt.date(file.captureDate ?? file.modifiedAt))
                Spacer()
            }
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.8))
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(
            LinearGradient(
                colors: [.black.opacity(0), .black.opacity(0.75)],
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

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.85), in: Capsule())
    }
}
