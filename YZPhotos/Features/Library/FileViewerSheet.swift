import AVKit
import SwiftUI

/// Visionneuse plein écran depuis les grilles : image ou vidéo,
/// avec actions garder / poubelle / restaurer selon l'état du fichier.
struct FileViewerSheet: View {
    let file: FileRecord
    let root: URL
    let onAction: () -> Void

    @Environment(AppEnvironment.self) private var env
    @Environment(\.yzTheme) private var theme
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
            let store = env.currentStore ?? LocalMediaStore(root: root)
            if file.kind == .photo {
                image = await env.thumbnails.cardImage(for: file, store: store)
            } else if let url = store.localURL(for: file) {
                let p = AVPlayer(url: url)
                player = p
                // Lecture automatique selon le réglage (Réglages → Vidéos).
                if env.settings.autoPlayVideos {
                    p.play()
                }
            } else {
                // Vidéo sur disque réseau : lecture native pas encore disponible.
                errorMessage = "La lecture des vidéos sur disque réseau arrive bientôt. Le tri (garder/poubelle) fonctionne déjà."
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
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.fileName).font(YZFont.headline).foregroundStyle(theme.t1).lineLimit(1)
                    Text("\(Fmt.bytes(file.sizeBytes)) · \(Fmt.date(file.captureDate ?? file.modifiedAt))")
                        .font(YZFont.subhead)
                        .foregroundStyle(theme.t2)
                }
                Spacer()
                Button("Fermer") { dismiss() }
                    .font(YZFont.subheadSemi)
                    .foregroundStyle(theme.t2)
            }
            HStack(spacing: 12) {
                if file.status == .trashed {
                    actionButton("Restaurer", icon: "arrow.uturn.backward", variant: .primary) {
                        try await env.triage?.restore(file)
                    }
                } else {
                    actionButton("Poubelle", icon: "trash.fill", variant: .destructive) {
                        try await env.triage?.trash(file)
                    }
                    actionButton("Garder", icon: "checkmark", variant: .primary) {
                        try await env.triage?.keep(file)
                    }
                }
            }
        }
        .padding(16)
        .background(theme.bg)
        .overlay(alignment: .top) { Rectangle().fill(theme.sep).frame(height: 0.5) }
    }

    private func actionButton(
        _ title: String, icon: String, variant: YZButtonStyle.Variant,
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
        }
        .buttonStyle(YZButtonStyle(variant, size: .lg, fullWidth: true))
    }
}
