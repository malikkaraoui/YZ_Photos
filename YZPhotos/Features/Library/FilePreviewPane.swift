import AVKit
import SwiftUI

/// Volet d'aperçu permanent à droite, style macOS : la photo/vidéo s'affiche
/// ici quand on la touche dans une grille — sans jamais prendre tout l'écran.
struct FilePreviewPane: View {
    @Binding var file: FileRecord?
    let root: URL
    var onAction: () -> Void = {}

    @Environment(AppEnvironment.self) private var env
    @Environment(\.yzTheme) private var theme
    @State private var image: UIImage?
    @State private var player: AVPlayer?
    /// Retient le resource loader SMB tant que le lecteur vit.
    @State private var smbLoader: AVAssetResourceLoaderDelegate?
    @State private var errorMessage: String?
    /// Pinch zoom dans l'image d'aperçu (double-tap = retour à 100 %).
    @State private var zoom: CGFloat = 1
    @State private var baseZoom: CGFloat = 1
    /// Décalage horizontal du swipe-tri (comme le deck).
    @State private var dragX: CGFloat = 0
    private let swipeThreshold: CGFloat = 100
    /// Partage : préparation (téléchargement temporaire pour un fichier réseau) puis
    /// feuille de partage iOS (Photos / Fichiers / AirDrop…).
    @State private var preparingShare = false
    @State private var sharePayload: SharePayload?

    static let defaultWidth: CGFloat = 380

    var body: some View {
        Group {
            if let file {
                content(file)
            } else {
                YZEmptyState(
                    systemImage: "sidebar.right",
                    title: "Aperçu",
                    message: "Touche une photo ou une vidéo pour l'afficher ici."
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg)
        .task(id: file?.id) { await load() }
        .alert("Erreur", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(item: $sharePayload) { payload in
            ShareSheet(url: payload.url)
        }
    }

    /// Prépare le fichier pour le partage : URL locale directe en USB, sinon on
    /// télécharge le fichier réseau dans un dossier temporaire, puis on ouvre la
    /// feuille de partage iOS (Photos / Fichiers / AirDrop…).
    private func prepareShare(_ file: FileRecord) async {
        preparingShare = true
        defer { preparingShare = false }
        let store = env.currentStore ?? LocalMediaStore(root: root)
        if let local = store.localURL(for: file) {
            sharePayload = SharePayload(url: local)
            return
        }
        do {
            let data = try await store.data(for: file)
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(file.fileName)
            try? FileManager.default.removeItem(at: tmp)
            try data.write(to: tmp, options: .atomic)
            sharePayload = SharePayload(url: tmp)
        } catch {
            errorMessage = "Impossible de préparer le partage : \(error.localizedDescription)"
        }
    }

    @ViewBuilder
    private func content(_ file: FileRecord) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(file.fileName)
                    .font(YZFont.headline)
                    .foregroundStyle(theme.t1)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                // Partager / enregistrer en local (Photos, Fichiers, AirDrop…).
                Button {
                    Task { await prepareShare(file) }
                } label: {
                    if preparingShare {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                            .foregroundStyle(theme.accent)
                    }
                }
                .disabled(preparingShare)
                .accessibilityLabel("Partager")
                Button {
                    self.file = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(theme.t2)
                }
            }
            .padding(12)

            ZStack {
                Color.black
                if file.kind == .video, let player {
                    // Contrôles 100 % NATIFS d'AVKit (son, AirPlay, plein écran) :
                    // on a retiré le bouton plein écran CUSTOM qui se superposait pile
                    // sur les contrôles natifs (son/expand) en haut à droite — d'où
                    // l'impossibilité de gérer le son (un tap lançait le plein écran).
                    VideoPlayer(player: player)
                } else if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(zoom)
                        .offset(x: dragX)
                        .rotationEffect(.degrees(Double(dragX / 26)))
                        .gesture(
                            MagnifyGesture()
                                .onChanged { value in
                                    zoom = min(max(baseZoom * value.magnification, 1), 6)
                                }
                                .onEnded { _ in baseZoom = zoom }
                        )
                        // Swipe horizontal (hors zoom) = trier, comme le deck :
                        // gauche → poubelle, droite → garder.
                        .simultaneousGesture(swipeGesture(file))
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
            .clipShape(RoundedRectangle(cornerRadius: YZRadius.card, style: .continuous))
            .overlay { swipeFeedback }
            .padding(.horizontal, 12)

            infoSection(file)
            actionButtons(file)
        }
    }

    /// Swipe de tri sur la photo (n'agit qu'à zoom 1, sinon laisse le pincer).
    private func swipeGesture(_ file: FileRecord) -> some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { value in
                guard zoom <= 1, abs(value.translation.width) > abs(value.translation.height) else { return }
                dragX = value.translation.width
            }
            .onEnded { _ in
                guard zoom <= 1 else { dragX = 0; return }
                if dragX < -swipeThreshold {
                    flyAndDecide(file, keep: false)
                } else if dragX > swipeThreshold {
                    flyAndDecide(file, keep: true)
                } else {
                    withAnimation(.spring(duration: 0.3)) { dragX = 0 }
                }
            }
    }

    /// Teinte + icône qui suivent le swipe (rouge poubelle ← / vert garder →).
    @ViewBuilder private var swipeFeedback: some View {
        if dragX != 0 {
            let keep = dragX > 0
            ZStack {
                RoundedRectangle(cornerRadius: YZRadius.card, style: .continuous)
                    .fill((keep ? theme.keep : theme.trash).opacity(min(abs(dragX) / 320, 0.4)))
                Image(systemName: keep ? "checkmark.circle.fill" : "trash.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.white)
                    .opacity(min(abs(dragX) / swipeThreshold, 1))
            }
            .allowsHitTesting(false)
        }
    }

    private func flyAndDecide(_ file: FileRecord, keep: Bool) {
        withAnimation(.easeOut(duration: 0.22)) { dragX = keep ? 1000 : -1000 }
        Task {
            do {
                if keep { try await env.triage?.keep(file) } else { try await env.triage?.trash(file) }
                onAction()   // auto-avance vers la suivante (géré par MediaGridView)
            } catch {
                errorMessage = error.localizedDescription
                withAnimation { dragX = 0 }
            }
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
                if file.isScreenshot { YZBadge("Capture", systemImage: "camera.viewfinder", tone: .accent) }
                if file.dupGroupId != nil {
                    YZBadge(file.dupKind == .exact ? "Doublon exact" : "Similaire",
                            systemImage: "square.on.square", tone: .warn)
                }
                if file.status == .kept { YZBadge("Gardée", systemImage: "checkmark", tone: .keep) }
                if file.status == .trashed { YZBadge("Corbeille", systemImage: "trash", tone: .trash) }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(YZFont.subhead)
                .foregroundStyle(theme.t2)
                .frame(width: 90, alignment: .leading)
            Spacer(minLength: 8)
            Text(value)
                .font(YZFont.subheadSemi)
                .foregroundStyle(theme.t1)
                .lineLimit(2)
                .truncationMode(.head)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.sep).frame(height: 0.5)
        }
    }

    private func actionButtons(_ file: FileRecord) -> some View {
        VStack(spacing: 10) {
            if file.status == .trashed {
                paneButton("Restaurer", icon: "arrow.uturn.backward", variant: .primary) {
                    try await env.triage?.restore(file)
                }
            } else {
                HStack(spacing: 10) {
                    paneButton("Poubelle", icon: "trash.fill", variant: .destructive) {
                        try await env.triage?.trash(file)
                    }
                    paneButton("Garder", icon: "checkmark", variant: .keep) {
                        try await env.triage?.keep(file)
                    }
                }
            }
            // 3ᵉ bouton : annuler la dernière action (intégré ici → plus de
            // bouton flottant qui chevauche « Garder »).
            if env.triage?.canUndo == true {
                Button {
                    Task {
                        if let restored = try? await env.triage?.undo() {
                            self.file = restored
                        }
                        onAction()
                    }
                } label: {
                    Label("Annuler la dernière action", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(YZButtonStyle(.secondary, size: .md, fullWidth: true))
            }
        }
        .padding(12)
    }

    private func paneButton(
        _ title: String, icon: String, variant: YZButtonStyle.Variant,
        action: @escaping () async throws -> Void
    ) -> some View {
        Button {
            Task {
                do {
                    try await action()
                    // On ne vide PAS le volet : la grille enchaîne sur le fichier
                    // suivant (auto-avance gérée par MediaGridView via onAction).
                    onAction()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        } label: {
            Label(title, systemImage: icon)
        }
        .buttonStyle(YZButtonStyle(variant, size: .lg, fullWidth: true))
    }

    private func load() async {
        player?.pause()
        player = nil
        image = nil
        zoom = 1
        baseZoom = 1
        dragX = 0   // nouvelle photo → recentrée (après un swipe précédent)
        guard let file else { return }
        let store = env.currentStore ?? LocalMediaStore(root: root)
        if file.kind == .video {
            if let url = store.localURL(for: file) {
                let p = AVPlayer(url: url)
                player = p
                // Lecture automatique selon le réglage (Réglages → Vidéos).
                if env.settings.autoPlayVideos {
                    p.play()
                }
            } else if let stream = SMBVideoThumbnailer.streamingAsset(
                store: store, relativePath: file.relativePath, size: file.sizeBytes, ext: file.ext
            ) {
                // Vidéo réseau : streaming par plages SMB.
                smbLoader = stream.loader
                let p = AVPlayer(playerItem: AVPlayerItem(asset: stream.asset))
                player = p
                if env.settings.autoPlayVideos { p.play() }
            }
        } else {
            image = await env.thumbnails.cardImage(for: file, store: store)
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
    @Environment(\.yzTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Sélection", systemImage: "checkmark.circle.fill")
                .font(YZFont.title2)
                .foregroundStyle(theme.accent)

            VStack(alignment: .leading, spacing: 4) {
                Text(Fmt.count(summary.count))
                    .yzDisplay(52)
                    .monospacedDigit()
                    .foregroundStyle(theme.t1)
                Text("éléments sélectionnés")
                    .font(YZFont.body)
                    .foregroundStyle(theme.t2)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(Fmt.bytes(summary.bytes))
                    .yzDisplay(36)
                    .monospacedDigit()
                    .foregroundStyle(theme.trash)
                Text("au total")
                    .font(YZFont.headline)
                    .foregroundStyle(theme.t2)
            }

            Rectangle().fill(theme.sep).frame(height: 0.5)

            summaryRow(icon: "photo", color: theme.accent,
                       text: "\(Fmt.count(summary.photoCount)) photos")
            summaryRow(icon: "video", color: theme.accent,
                       text: "\(Fmt.count(summary.videoCount)) vidéos"
                       + (summary.videoCount > 0 ? " · \(Fmt.bytes(summary.videoBytes))" : ""))
            if summary.screenshotCount > 0 {
                summaryRow(icon: "camera.viewfinder", color: theme.accent,
                           text: "\(Fmt.count(summary.screenshotCount)) captures d'écran")
            }
            if summary.duplicateCount > 0 {
                summaryRow(icon: "square.on.square", color: theme.warn,
                           text: "\(Fmt.count(summary.duplicateCount)) doublons")
            }

            Spacer()

            Text("Utilise les boutons en haut pour garder, jeter ou restaurer toute la sélection.")
                .font(YZFont.subhead)
                .foregroundStyle(theme.t2)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.bg)
    }

    private func summaryRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 30)
            Text(text)
                .font(YZFont.headline.monospacedDigit())
                .foregroundStyle(theme.t1)
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

    /// Largeur TOTALE en dessous de laquelle on n'affiche PAS le volet d'aperçu
    /// latéral : on privilégie le contenu (liste de fichiers). Sinon, en fenêtre
    /// étroite (Stage Manager / Split View) le volet mangeait la moitié de la place
    /// et la liste se tassait jusqu'au texte vertical (un caractère par ligne).
    private let sidePaneMinWidth: CGFloat = 760

    var body: some View {
        GeometryReader { geo in
            // Décision basée sur la LARGEUR RÉELLE (pas seulement la classe de taille,
            // qui reste « regular » même en demi-écran sur iPad).
            let wide = hSize == .regular && geo.size.width >= sidePaneMinWidth
            HStack(spacing: 0) {
                // `master()` reste TOUJOURS le 1er enfant (position stable) → il n'est
                // PAS recréé quand le volet apparaît/disparaît au resize (pas de reset
                // de la liste / du défilement).
                master()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if wide {
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
            }
            .onChange(of: wide) { _, nowWide in
                // En passant en fenêtre étroite : on ferme l'aperçu (priorité au
                // contenu) et on évite qu'une feuille surgisse toute seule.
                if !nowWide { selectedFile = nil }
            }
            // En étroit seulement : un tap ouvre l'aperçu en feuille (pas de volet
            // permanent). En large, l'aperçu est dans le volet → pas de feuille.
            .sheet(item: wide ? Binding.constant(nil) : $selectedFile) { file in
                FileViewerSheet(file: file, root: root, onAction: onAction)
                    .environment(env)
            }
        }
        // L'aperçu ne doit jamais montrer un fichier qui n'est plus « à trier / gardé »
        // (déjà à la corbeille / supprimé) : on le vide à chaque changement de
        // sélection ET à chaque redimensionnement.
        .task(id: selectedFile?.id) { await clearSelectedIfStale() }
        .onChange(of: hSize) { _, _ in Task { await clearSelectedIfStale() } }
        // …ET dès qu'une action de tri touche la base (ex. suppression multiple) :
        // si le fichier prévisualisé vient de partir à la corbeille, on vide l'aperçu
        // (sinon il montrait une photo déjà supprimée).
        .onChange(of: env.triage?.changeTick) { _, _ in Task { await clearSelectedIfStale() } }
    }

    private func clearSelectedIfStale() async {
        guard let id = selectedFile?.id else { return }
        let status = try? await env.database.writer.read { db in
            try Queries.fileStatus(db, id: id)
        }
        // Disparu, ou plus à trier/gardé (corbeille, en cours de suppression, supprimé).
        if status == nil
            || (status != FileStatus.untriaged.rawValue && status != FileStatus.kept.rawValue) {
            selectedFile = nil
        }
    }
}

/// Élément à partager (URL prête), Identifiable pour `.sheet(item:)`.
struct SharePayload: Identifiable {
    let id = UUID()
    let url: URL
}

/// Feuille de partage iOS (UIActivityViewController) — Photos, Fichiers, AirDrop…
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
