import AVKit
import SwiftUI

/// Volet d'aperçu permanent à droite, style macOS : la photo/vidéo s'affiche
/// ici quand on la touche dans une grille — sans jamais prendre tout l'écran.
struct FilePreviewPane: View {
    @Binding var file: FileRecord?
    let root: URL
    var onAction: () -> Void = {}

    @Environment(AppEnvironment.self) private var env
    @State private var image: UIImage?
    @State private var player: AVPlayer?
    @State private var errorMessage: String?
    /// Pinch zoom dans l'image d'aperçu (double-tap = retour à 100 %).
    @State private var zoom: CGFloat = 1
    @State private var baseZoom: CGFloat = 1
    @State private var showFullScreenVideo = false

    static let defaultWidth: CGFloat = 380

    var body: some View {
        Group {
            if let file {
                content(file)
            } else {
                ContentUnavailableView(
                    "Aperçu",
                    systemImage: "sidebar.right",
                    description: Text("Touche une photo ou une vidéo pour l'afficher ici.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .task(id: file?.id) { await load() }
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
    private func content(_ file: FileRecord) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(file.fileName)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button {
                    self.file = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)

            ZStack {
                Color.black
                if file.kind == .video, let player {
                    VideoPlayer(player: player)
                        // Plein écran (le X en haut à gauche permet d'en sortir,
                        // la lecture continue au même endroit).
                        .overlay(alignment: .topTrailing) {
                            Button {
                                showFullScreenVideo = true
                            } label: {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.title3.bold())
                                    .foregroundStyle(.white)
                                    .padding(8)
                                    .background(.black.opacity(0.55), in: Circle())
                                    .padding(10)
                            }
                        }
                        .fullScreenCover(isPresented: $showFullScreenVideo) {
                            FullScreenPlayerView(player: player)
                        }
                } else if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(zoom)
                        .gesture(
                            MagnifyGesture()
                                .onChanged { value in
                                    zoom = min(max(baseZoom * value.magnification, 1), 6)
                                }
                                .onEnded { _ in baseZoom = zoom }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring(duration: 0.3)) {
                                zoom = 1
                                baseZoom = 1
                            }
                        }
                } else {
                    ProgressView().tint(.white)
                }
            }
            .frame(maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 12)

            infoSection(file)
            actionButtons(file)
        }
    }

    private func infoSection(_ file: FileRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            infoRow("Poids", Fmt.bytes(file.sizeBytes))
            if let w = file.pixelWidth, let h = file.pixelHeight {
                infoRow("Dimensions", "\(w) × \(h)")
            }
            if let duration = file.durationSeconds {
                infoRow("Durée", Fmt.duration(duration))
            }
            infoRow("Date", Fmt.date(file.captureDate ?? file.modifiedAt))
            infoRow("Dossier", (file.relativePath as NSString).deletingLastPathComponent.isEmpty
                    ? "Racine du disque"
                    : (file.relativePath as NSString).deletingLastPathComponent)
            HStack(spacing: 6) {
                if file.isScreenshot { previewBadge("Capture", .purple) }
                if file.dupGroupId != nil {
                    previewBadge(file.dupKind == .exact ? "Doublon exact" : "Similaire", .orange)
                }
                if file.status == .kept { previewBadge("Gardée ✓", .green) }
                if file.status == .trashed { previewBadge("Corbeille", .red) }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.subheadline.bold())
                .lineLimit(2)
                .truncationMode(.head)
        }
    }

    private func previewBadge(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.85), in: Capsule())
    }

    private func actionButtons(_ file: FileRecord) -> some View {
        HStack(spacing: 12) {
            if file.status == .trashed {
                paneButton("Restaurer", icon: "arrow.uturn.backward", color: .orange) {
                    try await env.triage?.restore(file)
                }
            } else {
                paneButton("Poubelle", icon: "trash.fill", color: .red) {
                    try await env.triage?.trash(file)
                }
                paneButton("Garder", icon: "checkmark", color: .green) {
                    try await env.triage?.keep(file)
                }
            }
        }
        .padding(12)
    }

    private func paneButton(
        _ title: String, icon: String, color: Color,
        action: @escaping () async throws -> Void
    ) -> some View {
        Button {
            Task {
                do {
                    try await action()
                    file = nil
                    onAction()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        } label: {
            Label(title, systemImage: icon)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
    }

    private func load() async {
        player?.pause()
        player = nil
        image = nil
        zoom = 1
        baseZoom = 1
        guard let file else { return }
        if file.kind == .video {
            let p = AVPlayer(url: file.currentURL(driveRoot: root))
            player = p
            // Lecture automatique selon le réglage (Réglages → Vidéos).
            if env.settings.autoPlayVideos {
                p.play()
            }
        } else {
            image = await env.thumbnails.cardImage(for: file, driveRoot: root)
        }
    }
}

/// Vidéo en plein écran depuis l'aperçu : même lecteur (la position de
/// lecture est conservée), bouton X pour sortir.
struct FullScreenPlayerView: View {
    let player: AVPlayer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topLeading) {
            VideoPlayer(player: player)
                .ignoresSafeArea()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(20)
            }
        }
        .background(.black)
    }
}

/// Récapitulatif d'une sélection multiple, affiché à droite à la place de
/// l'aperçu (qui n'a plus de sens quand plusieurs éléments sont cochés).
struct SelectionSummary {
    var files: [FileRecord]

    var count: Int { files.count }
    var bytes: Int64 { files.reduce(0) { $0 + $1.sizeBytes } }
    var photoCount: Int { files.count(where: { $0.kind == .photo }) }
    var videoCount: Int { files.count(where: { $0.kind == .video }) }
    var videoBytes: Int64 { files.filter { $0.kind == .video }.reduce(0) { $0 + $1.sizeBytes } }
    var screenshotCount: Int { files.count(where: \.isScreenshot) }
    var duplicateCount: Int { files.count(where: { $0.dupGroupId != nil }) }
}

struct SelectionSummaryPane: View {
    let summary: SelectionSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Sélection", systemImage: "checkmark.circle.fill")
                .font(.title2.bold())
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(Fmt.count(summary.count))
                    .font(.system(size: 52, weight: .bold).monospacedDigit())
                Text("éléments sélectionnés")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(Fmt.bytes(summary.bytes))
                    .font(.system(size: 36, weight: .bold).monospacedDigit())
                    .foregroundStyle(.red)
                Text("au total")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            summaryRow(icon: "photo", color: .blue,
                       text: "\(Fmt.count(summary.photoCount)) photos")
            summaryRow(icon: "video", color: .purple,
                       text: "\(Fmt.count(summary.videoCount)) vidéos"
                       + (summary.videoCount > 0 ? " · \(Fmt.bytes(summary.videoBytes))" : ""))
            if summary.screenshotCount > 0 {
                summaryRow(icon: "camera.viewfinder", color: .indigo,
                           text: "\(Fmt.count(summary.screenshotCount)) captures d'écran")
            }
            if summary.duplicateCount > 0 {
                summaryRow(icon: "square.on.square", color: .orange,
                           text: "\(Fmt.count(summary.duplicateCount)) doublons")
            }

            Spacer()

            Text("Utilise les boutons en haut pour garder, jeter ou restaurer toute la sélection.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.systemGroupedBackground))
    }

    private func summaryRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 30)
            Text(text)
                .font(.headline.monospacedDigit())
        }
    }
}

/// Conteneur maître/détail : contenu à gauche, volet d'aperçu à droite.
/// En sélection multiple, le volet bascule sur le récapitulatif.
/// En largeur compacte (Split View), retombe sur la visionneuse plein écran.
struct MasterDetailLayout<Master: View>: View {
    @Binding var selectedFile: FileRecord?
    let root: URL
    var onAction: () -> Void = {}
    /// Non-nil quand une sélection multiple est en cours.
    var selectionSummary: SelectionSummary?
    @ViewBuilder var master: () -> Master

    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        if hSize == .regular {
            HStack(spacing: 0) {
                master()
                Divider()
                Group {
                    if let selectionSummary {
                        SelectionSummaryPane(summary: selectionSummary)
                    } else {
                        FilePreviewPane(file: $selectedFile, root: root, onAction: onAction)
                    }
                }
                .frame(width: FilePreviewPane.defaultWidth)
            }
        } else {
            master()
                .sheet(item: $selectedFile) { file in
                    FileViewerSheet(file: file, root: root, onAction: onAction)
                        .environment(env)
                }
        }
    }
}
