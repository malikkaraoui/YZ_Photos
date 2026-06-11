import AVKit
import SwiftUI

/// Visionneuse plein écran depuis les grilles : image ou vidéo,
/// avec actions garder / poubelle / restaurer selon l'état du fichier.
struct FileViewerSheet: View {
    let file: FileRecord
    let root: URL
    let onAction: () -> Void

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var player: AVPlayer?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black)
            actionBar
        }
        .task {
            if file.kind == .photo {
                image = await env.thumbnails.cardImage(for: file, driveRoot: root)
            } else {
                let p = AVPlayer(url: file.currentURL(driveRoot: root))
                player = p
                // Lecture automatique selon le réglage (Réglages → Vidéos).
                if env.settings.autoPlayVideos {
                    p.play()
                }
            }
        }
        .onDisappear { player?.pause() }
        .alert("Erreur", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        if file.kind == .video, let player {
            VideoPlayer(player: player)
        } else if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            ProgressView().tint(.white)
        }
    }

    private var actionBar: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.fileName).font(.headline).lineLimit(1)
                    Text("\(Fmt.bytes(file.sizeBytes)) · \(Fmt.date(file.captureDate ?? file.modifiedAt))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Fermer") { dismiss() }
                    .font(.title3)
            }
            HStack(spacing: 20) {
                if file.status == .trashed {
                    actionButton("Restaurer", icon: "arrow.uturn.backward", color: .orange) {
                        try await env.triage?.restore(file)
                    }
                } else {
                    actionButton("Poubelle", icon: "trash.fill", color: .red) {
                        try await env.triage?.trash(file)
                    }
                    actionButton("Garder", icon: "checkmark", color: .green) {
                        try await env.triage?.keep(file)
                    }
                }
            }
        }
        .padding(16)
    }

    private func actionButton(
        _ title: String, icon: String, color: Color,
        action: @escaping () async throws -> Void
    ) -> some View {
        Button {
            Task {
                do {
                    try await action()
                    onAction()
                    dismiss()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        } label: {
            Label(title, systemImage: icon)
                .font(.title3.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
    }
}
