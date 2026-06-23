import AVKit
import SwiftUI

/// Le deck façon Tinder : swipe gauche = poubelle, swipe droite = garder.
/// Mouvement réglé sur `motion.json` (handoff design).
struct TriageDeckView: View {
    let drive: DriveRecord
    let root: URL
    let filter: TriageFilter
    /// Restreint le deck à un dossier (nil = tout le disque).
    var scope: String?
    /// Titre affiché quand on trie un dossier précis.
    var scopeTitle: String?
    var isModal = false

    @Environment(AppEnvironment.self) private var env
    @Environment(\.yzTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var vm: TriageViewModel?
    @State private var dragOffset: CGSize = .zero
    @State private var isFlying = false
    @State private var didCrossThreshold = false
    @State private var fullScreenFile: FileRecord?

    // motion.json → swipe_gesture
    private let engageThreshold: CGFloat = 110
    private let hintStart: CGFloat = 30
    private let flyDistance: CGFloat = 900
    private let flyRotation: Double = 18

    var body: some View {
        Group {
            if let vm {
                deck(vm)
            } else {
                ProgressView().tint(theme.t2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .yzScreenBackground(theme)
        .task(id: drive.id) {
            if vm == nil, let triage = env.triage {
                vm = TriageViewModel(
                    database: env.database,
                    thumbnails: env.thumbnails,
                    triage: triage,
                    driveId: drive.id,
                    store: env.currentStore ?? LocalMediaStore(root: root),
                    filter: filter,
                    scope: scope,
                    onDiskError: { env.driveDidDisconnect() }
                )
            }
            await vm?.refresh()
        }
        .onChange(of: env.scan.phase) { _, newPhase in
            if newPhase == .analyzing || newPhase == .finished {
                Task { await vm?.refresh() }
            }
        }
        .onChange(of: env.libraryReloadTick) { _, _ in
            Task { await vm?.refresh() }
        }
        .onChange(of: env.triage?.undoCount) { old, new in
            if let old, let new, new < old {
                Task { await vm?.refresh() }
            }
        }
        .fullScreenCover(item: $fullScreenFile) { file in
            FullScreenMediaView(file: file, root: root) {
                Task { await vm?.refresh() }
            }
        }
    }

    @ViewBuilder
    private func deck(_ vm: TriageViewModel) -> some View {
        VStack(spacing: 12) {
            header(vm)
            if vm.window.isEmpty {
                emptyState(vm)
            } else {
                cards(vm)
                caption
                controls(vm)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .alert("Erreur", isPresented: .init(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.clearError() } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    private func header(_ vm: TriageViewModel) -> some View {
        HStack(alignment: .firstTextBaseline) {
            if isModal {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.t2)
                }
                .padding(.trailing, 4)
            }
            Text(deckTitle)
                .yzDisplay(30)
                .foregroundStyle(theme.t1)
                .lineLimit(1)
            Spacer()
            HStack(spacing: 3) {
                Text(Fmt.count(vm.remaining))
                    .font(.system(size: 22, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(theme.isGlass ? .white : theme.accent)
                Text("restantes")
                    .font(YZFont.subhead)
                    .foregroundStyle(theme.t3)
            }
        }
        .padding(.top, 14)
    }

    private var deckTitle: String {
        if let scopeTitle { return "Trier : \(scopeTitle)" }
        return filter == .all ? "Trier" : "Trier : \(filter.title)"
    }

    private func cards(_ vm: TriageViewModel) -> some View {
        ZStack {
            // Pile visible : profondeur 2 (motion.stack.max_visible_depth).
            ForEach(Array(vm.window.prefix(3).enumerated().reversed()), id: \.element.id) { index, file in
                if index == 0 {
                    SwipeCardView(file: file, root: root)
                        .overlay { tintOverlay }
                        .overlay { stamps }
                        .offset(dragOffset)
                        .rotationEffect(.degrees(Double(dragOffset.width / 22)))
                        .gesture(dragGesture(vm))
                        .onTapGesture {
                            // Plein écran (photo zoomable ou vidéo) avec poubelle/garder.
                            fullScreenFile = file
                        }
                } else {
                    SwipeCardView(file: file, root: root)
                        .scaleEffect(1 - CGFloat(index) * 0.05)
                        .offset(y: CGFloat(index) * 20)
                        .opacity(index == 1 ? 1 : 0.6)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.8), value: vm.window.first?.id)
    }

    /// Teinte verte (garder) / rose (poubelle) qui monte avec le glissement (max 0.5).
    private var tintOverlay: some View {
        let w = dragOffset.width
        let intensity = min(0.5, max(0, (abs(w) - hintStart) / (engageThreshold - hintStart)) * 0.5)
        return RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(w >= 0 ? theme.accent : Color(hex: 0xF06A8C))
            .opacity(w == 0 ? 0 : intensity)
            .blendMode(.overlay)
            .allowsHitTesting(false)
    }

    /// Tampons GARDER (droite) / POUBELLE (gauche) — motion.stamp.
    private var stamps: some View {
        let w = dragOffset.width
        let ramp = max(0, min(1, (abs(w) - hintStart) / (engageThreshold - hintStart)))
        return ZStack {
            stamp("GARDER", color: theme.accent, rotation: -8)
                .opacity(w > 0 ? ramp : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            stamp("POUBELLE", color: Color(hex: 0xF06A8C), rotation: 8)
                .opacity(w < 0 ? ramp : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(26)
        .allowsHitTesting(false)
    }

    private func stamp(_ text: String, color: Color, rotation: Double) -> some View {
        Text(text)
            .font(.system(size: 26, weight: .heavy))
            .tracking(1.5)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(color.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.white, lineWidth: 3.5) }
            .rotationEffect(.degrees(rotation))
    }

    private var caption: some View {
        Text("Un swipe. C'est trié.")
            .font(YZFont.footnote)
            .foregroundStyle(theme.t3)
    }

    private func controls(_ vm: TriageViewModel) -> some View {
        HStack(spacing: 22) {
            roundButton(icon: "trash.fill", tone: theme.trash, size: 62) {
                performSwipe(vm, keep: false)
            }
            roundButton(icon: "arrow.uturn.backward", tone: theme.t2, size: 50, disabled: !vm.canUndo) {
                Task { await vm.undo() }
            }
            roundButton(icon: "checkmark", tone: theme.accent, size: 62) {
                performSwipe(vm, keep: true)
            }
        }
        .padding(.vertical, 6)
    }

    private func roundButton(
        icon: String, tone: Color, size: CGFloat,
        disabled: Bool = false, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.40, weight: .bold))
                .foregroundStyle(theme.isGlass ? .white : tone)
                .frame(width: size, height: size)
                .background {
                    Circle().fill(theme.isGlass ? tone.opacity(0.34) : theme.card)
                    if theme.isGlass { Circle().fill(.ultraThinMaterial).opacity(0.5) }
                }
                .overlay {
                    Circle().strokeBorder(theme.isGlass ? .whiteA(0.42) : theme.sep, lineWidth: theme.isGlass ? 0.5 : 1)
                }
                .shadow(color: theme.isGlass ? tone.opacity(0.45) : .blackA(0.12), radius: 8, y: 4)
        }
        .opacity(disabled ? 0.4 : 1)
        .disabled(disabled || isFlying)
    }

    private func emptyState(_ vm: TriageViewModel) -> some View {
        VStack(spacing: 16) {
            if env.scan.isRunning {
                scanProgressState
            } else {
                YZEmptyState(
                    systemImage: "checkmark.seal",
                    title: "Tout est trié ici !",
                    message: "Aucun fichier à trier pour ce filtre."
                )
            }
            if vm.canUndo {
                Button { Task { await vm.undo() } } label: {
                    Label("Annuler la dernière décision", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(YZButtonStyle(.secondary))
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// État affiché dans le deck quand il n'y a (encore) rien à trier MAIS que
    /// l'analyse tourne : on montre sa progression, pas un « tout est trié ».
    private var scanProgressState: some View {
        VStack(spacing: 14) {
            Image(systemName: "waveform.badge.magnifyingglass")
                .font(.system(size: 46))
                .foregroundStyle(theme.accent)
            Text("Analyse en cours…")
                .font(YZFont.title2)
                .foregroundStyle(theme.t1)
            if env.scan.analyzedTotal > 0 {
                YZProgressBar(value: Double(env.scan.analyzedDone) / Double(env.scan.analyzedTotal), tone: theme.accent)
                Text("\(Fmt.count(env.scan.analyzedDone)) / \(Fmt.count(env.scan.analyzedTotal)) analysés"
                     + (env.scan.etaSeconds.map { " · reste \(Fmt.eta($0))" } ?? ""))
                    .font(YZFont.subheadSemi.monospacedDigit())
                    .foregroundStyle(theme.t2)
            } else {
                YZIndeterminateBar(tone: theme.accent)
                Text("\(Fmt.count(env.scan.filesSeen)) fichiers découverts…")
                    .font(YZFont.subheadSemi.monospacedDigit())
                    .foregroundStyle(theme.t2)
            }
            Text("Les photos à trier apparaîtront ici au fur et à mesure.")
                .font(YZFont.subhead)
                .foregroundStyle(theme.t3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 380)
        .padding(.horizontal, 30)
    }

    // MARK: - Gestes

    private func dragGesture(_ vm: TriageViewModel) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isFlying else { return }
                dragOffset = value.translation
                // Haptique légère au franchissement du seuil (motion.haptic).
                let crossed = abs(value.translation.width) >= engageThreshold
                if crossed && !didCrossThreshold {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                didCrossThreshold = crossed
            }
            .onEnded { value in
                guard !isFlying else { return }
                didCrossThreshold = false
                let dx = value.translation.width
                let flick = abs(value.predictedEndTranslation.width - dx) > 120
                if dx > engageThreshold || (dx > hintStart && flick) {
                    performSwipe(vm, keep: true)
                } else if dx < -engageThreshold || (dx < -hintStart && flick) {
                    performSwipe(vm, keep: false)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { dragOffset = .zero }
                }
            }
    }

    private func performSwipe(_ vm: TriageViewModel, keep: Bool) {
        guard !isFlying, let top = vm.window.first else { return }
        isFlying = true
        withAnimation(.easeIn(duration: 0.55)) {
            dragOffset = CGSize(width: keep ? flyDistance : -flyDistance,
                                height: dragOffset.height + 40)
        }
        Task {
            try? await Task.sleep(for: .milliseconds(360))
            await vm.decide(file: top, keep: keep)
            dragOffset = .zero
            isFlying = false
        }
    }
}

/// Lecteur vidéo plein écran (lecture directe depuis le SSD).
struct VideoPlayerSheet: View {
    let url: URL
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            }
            Button {
                player?.pause()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(20)
            }
        }
        .background(.black)
        .onAppear {
            let p = AVPlayer(url: url)
            player = p
            if env.settings.autoPlayVideos {
                p.play()
            }
        }
        .onDisappear {
            player?.pause()
        }
    }
}

/// Plein écran depuis le deck : photo (zoomable) ou vidéo, avec sortie (X en haut
/// à gauche, glisser vers le bas), poubelle en bas à gauche, garder en bas à droite.
struct FullScreenMediaView: View {
    let file: FileRecord
    let root: URL
    /// Appelé après une décision (poubelle/garder) pour que le deck se recharge.
    var onDecided: () -> Void

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @Environment(\.yzTheme) private var theme
    @State private var image: UIImage?
    @State private var player: AVPlayer?
    /// Retient le resource loader SMB tant que le lecteur vit (sinon le stream coupe).
    @State private var smbLoader: AVAssetResourceLoaderDelegate?
    @State private var zoom: CGFloat = 1
    @State private var baseZoom: CGFloat = 1
    @State private var working = false

    private var store: MediaStore { env.currentStore ?? LocalMediaStore(root: root) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack {
                HStack {
                    closeButton
                    Spacer()
                }
                Spacer()
                HStack(alignment: .bottom) {
                    roundButton("trash.fill", tint: Color(hex: 0xF06A8C)) { decide(keep: false) }
                    Spacer()
                    roundButton("checkmark", tint: theme.accent) { decide(keep: true) }
                }
                .padding(.horizontal, 28)
                // Vidéo : on remonte les boutons au-dessus de la jauge de lecture
                // native (sinon ils la chevauchent).
                .padding(.bottom, player != nil ? 104 : 24)
            }
        }
        .task(id: file.id) {
            if file.kind == .video {
                if let url = store.localURL(for: file) {
                    let p = AVPlayer(url: url)
                    player = p
                    if env.settings.autoPlayVideos { p.play() }
                } else if let stream = SMBVideoThumbnailer.streamingAsset(
                    store: store, relativePath: file.relativePath, size: file.sizeBytes, ext: file.ext
                ) {
                    // Vidéo réseau : lecture en streaming par plages SMB.
                    smbLoader = stream.loader
                    let p = AVPlayer(playerItem: AVPlayerItem(asset: stream.asset))
                    player = p
                    if env.settings.autoPlayVideos { p.play() }
                } else {
                    image = await env.thumbnails.cardImage(for: file, store: store)
                }
            } else {
                image = await env.thumbnails.cardImage(for: file, store: store)
            }
        }
        .onDisappear { player?.pause() }
    }

    @ViewBuilder private var content: some View {
        if let player {
            VideoPlayer(player: player).ignoresSafeArea()
        } else if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(zoom)
                .gesture(
                    MagnifyGesture()
                        .onChanged { zoom = min(6, max(1, baseZoom * $0.magnification)) }
                        .onEnded { _ in baseZoom = zoom }
                )
                .onTapGesture(count: 2) { withAnimation { zoom = zoom > 1 ? 1 : 2.5; baseZoom = zoom } }
                .highPriorityGesture(
                    // Glisser vers le bas (hors zoom) = fermer.
                    DragGesture().onEnded { if zoom <= 1, $0.translation.height > 110 { dismiss() } }
                )
        } else {
            VStack(spacing: 10) {
                ProgressView().tint(.white)
                if file.kind == .video {
                    Text("Chargement de la vidéo…").font(.footnote).foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }

    private var closeButton: some View {
        Button { player?.pause(); dismiss() } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(.white.opacity(0.9))
                .padding(20)
        }
    }

    private func roundButton(_ icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 66, height: 66)
                .background { Circle().fill(tint.opacity(0.9)); Circle().fill(.ultraThinMaterial).opacity(0.3) }
                .overlay { Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1) }
                .shadow(color: tint.opacity(0.5), radius: 10, y: 4)
        }
        .disabled(working)
        .opacity(working ? 0.5 : 1)
    }

    private func decide(keep: Bool) {
        guard !working else { return }
        working = true
        player?.pause()
        Task {
            do {
                if keep { try await env.triage?.keep(file) }
                else { try await env.triage?.trash(file) }
            } catch {
                AppLog.error("Décision plein écran (\(keep ? "garder" : "poubelle"))", error)
            }
            onDecided()
            dismiss()
        }
    }
}
