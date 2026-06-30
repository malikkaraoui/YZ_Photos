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
    /// Image de la carte du dessus, réutilisée pour le fond flouté « à la Apple ».
    @State private var topImage: UIImage?
    @Environment(\.horizontalSizeClass) private var hSize
    /// Pic du nombre « à trier » vu cette session → barre de progression de l'en-tête.
    @State private var sessionMax = 0
    /// Mode concentration : dès qu'on swipe, on cache la tab bar + l'en-tête (et son
    /// bouton aléatoire) pour ne voir que la photo. Tap à côté de la photo → réapparaît.
    @State private var focusMode = false

    // motion.json → swipe_gesture
    private let engageThreshold: CGFloat = 110
    private let hintStart: CGFloat = 30
    private let flyDistance: CGFloat = 900
    private let flyRotation: Double = 18
    /// Carte portrait (≈ 3:4) : la photo remplit, pas de bandes noires.
    private let cardAspect: CGFloat = 0.74

    var body: some View {
        Group {
            if let vm {
                deck(vm)
            } else {
                ProgressView().tint(theme.t2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // CLÉ du fix paysage : le deck est le contenu PRINCIPAL → il RESPECTE la safe
        // area, donc le chrome (en-tête + boutons) ne peut PLUS sortir de l'écran. Le
        // fond flou passe DERRIÈRE en .background (lui ignore la safe area = plein écran).
        .background { backgroundLayer }
        // Mode concentration : la tab bar disparaît pendant le swipe.
        .toolbar(focusMode ? .hidden : .visible, for: .tabBar)
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

    /// Fond plein écran : aurora du thème + la photo de la carte du dessus,
    /// fortement floutée et assombrie. C'est elle qui fait « respirer » la carte
    /// nette posée par-dessus (effet Apple). Pas de photo → simple aurora.
    @ViewBuilder private var backgroundLayer: some View {
        ZStack {
            YZBackground(theme: theme)
            if let topImage {
                Image(uiImage: topImage)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 12, opaque: true)        // entre-deux : on distingue bien la photo
                    .overlay(Color.black.opacity(0.16))    // voile léger
            }
        }
        .ignoresSafeArea()
    }

    /// Charge la miniature de la carte du dessus pour le fond (réutilise le cache
    /// → pas de second décodage). Vide le fond quand il n'y a plus rien à trier.
    private func loadTopImage(_ vm: TriageViewModel) async {
        guard let top = vm.window.first else {
            withAnimation(.easeInOut(duration: 0.25)) { topImage = nil }
            return
        }
        let img = await env.thumbnails.cardImage(for: top, store: env.currentStore ?? LocalMediaStore(root: root))
        withAnimation(.easeInOut(duration: 0.3)) { topImage = img }
    }

    @ViewBuilder
    private func deck(_ vm: TriageViewModel) -> some View {
        // Layout ROBUSTE (paysage / portrait / fenêtré Stage Manager) : les cartes
        // occupent le centre ; le chrome est posé en SAFE-AREA INSET — en-tête en
        // haut, boutons + légende en bas → TOUJOURS dans la zone visible, jamais
        // poussé sous le dock ni hors écran par le GeometryReader des cartes (le bug
        // qu'on voyait en paysage). Mode concentration = opacité (le chrome garde sa
        // place réservée → réapparaît de façon fiable au tap).
        ZStack {
            // Calque de tap : tap dans le VIDE (à côté de la photo) → bascule le mode
            // concentration. Derrière la carte (qui a ses propres gestes) et le chrome.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.22)) { focusMode.toggle() }
                }

            Group {
                if vm.window.isEmpty {
                    emptyState(vm)
                } else {
                    cards(vm)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .top, spacing: 0) {
                header(vm)
                    .opacity(focusMode ? 0 : 1)
                    .allowsHitTesting(!focusMode)
                    .padding(.horizontal, 28)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !vm.window.isEmpty {
                    VStack(spacing: 10) {
                        controls(vm)
                        caption
                    }
                    .opacity(focusMode ? 0 : 1)
                    .allowsHitTesting(!focusMode)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 18)
                }
            }
        }
        .task(id: vm.window.first?.id) { await loadTopImage(vm) }
        .onChange(of: vm.remaining, initial: true) { _, r in
            if r > sessionMax { sessionMax = r }   // pic de la session → progression
        }
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
        let total = max(sessionMax, vm.remaining)
        let progress = total > 0 ? Double(total - vm.remaining) / Double(total) : 0
        return HStack(spacing: 14) {
            if isModal {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.t2)
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(deckTitle)
                    .yzDisplay(26)
                    .foregroundStyle(theme.t1)
                    .lineLimit(1)
                Text("\(Fmt.count(vm.remaining)) à trier")
                    .font(YZFont.subhead)
                    .foregroundStyle(theme.t3)
            }
            Spacer(minLength: 10)
            // Jauge SANS GeometryReader (YZProgressBar en contenait un, glouton :
            // il ignorait la largeur fixe → prenait toute la largeur et écrasait le
            // bouton/les autres éléments). Deux capsules à largeur FIXE = robuste.
            ZStack(alignment: .leading) {
                Capsule().fill(Color.whiteA(0.18))
                Capsule().fill(theme.accent)
                    .frame(width: 110 * max(0, min(1, progress)))
            }
            .frame(width: 110, height: 6)
            // Bouton aléatoire : sur iPHONE il reste dans l'en-tête. Sur iPAD il
            // rejoint le menu flottant du bas (avec poubelle/annuler/valider).
            if hSize != .regular {
                Button { Task { await vm.refreshRandom() } } label: {
                    Image(systemName: "shuffle")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(theme.accent)
                        .frame(width: 34, height: 34)
                        .background { Circle().fill(theme.isGlass ? Color.whiteA(0.16) : theme.bg2) }
                }
                .layoutPriority(1)
                .accessibilityLabel("Trier au hasard")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .yzSurface(theme, radius: 26, elevated: true)
        // iPad : la tab bar flotte EN HAUT → on descend l'en-tête sous elle (sinon
        // le bouton aléatoire passait « sous » la tab bar). iPhone : tab bar en bas.
        .padding(.top, hSize == .regular ? 52 : 6)
    }

    private var deckTitle: String {
        if let scopeTitle { return "Trier : \(scopeTitle)" }
        return filter == .all ? "Trier" : "Trier : \(filter.title)"
    }

    private func cards(_ vm: TriageViewModel) -> some View {
        // La zone occupe tout l'espace central ; la carte (portrait) y est centrée
        // avec de larges marges → l'écran respire (« aéré au premier abord »).
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height * cardAspect)
            let w = min(side * 0.92, 430)
            let h = w / cardAspect
            ZStack {
                // Pile visible : profondeur 2 (motion.stack.max_visible_depth).
                // UNE SEULE SwipeCardView par carte (pas de branche if/else qui
                // recréerait la vue à la promotion → l'image se rechargeait, d'où le
                // saut au swipe). Tout est piloté par des VALEURS conditionnelles :
                // l'identité reste stable, l'image n'est décodée qu'une fois.
                ForEach(Array(vm.window.prefix(3).enumerated().reversed()), id: \.element.id) { index, file in
                    let isTop = index == 0
                    SwipeCardView(file: file, root: root, showInfo: isTop && !focusMode)
                        .frame(width: w, height: h)
                        .scaleEffect(1 - CGFloat(index) * 0.04)
                        .opacity(index <= 1 ? 1 : 0.55)
                        .offset(isTop ? dragOffset : CGSize(width: 0, height: CGFloat(index) * 16))
                        .rotationEffect(.degrees(isTop ? Double(dragOffset.width / 22) : 0))
                        .overlay { if isTop { tintOverlay } }
                        .overlay { if isTop { stamps } }
                        .zIndex(Double(-index))
                        .allowsHitTesting(isTop)
                        .gesture(dragGesture(vm))
                        .onTapGesture {
                            // Plein écran (photo zoomable ou vidéo) avec détails + poubelle/garder.
                            if isTop { fullScreenFile = file }
                        }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.8), value: vm.window.first?.id)
        }
    }

    /// Teinte verte (garder) / rose (poubelle) qui monte avec le glissement (max 0.5).
    private var tintOverlay: some View {
        let w = dragOffset.width
        let intensity = min(0.5, max(0, (abs(w) - hintStart) / (engageThreshold - hintStart)) * 0.5)
        return RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(w >= 0 ? theme.keep : Color(hex: 0xF06A8C))
            .opacity(w == 0 ? 0 : intensity)
            .blendMode(.overlay)
            .allowsHitTesting(false)
    }

    /// Tampons GARDER (droite) / POUBELLE (gauche) — motion.stamp.
    private var stamps: some View {
        let w = dragOffset.width
        let ramp = max(0, min(1, (abs(w) - hintStart) / (engageThreshold - hintStart)))
        return ZStack {
            stamp("GARDER", color: theme.keep, rotation: -8)
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
        HStack(spacing: 6) {
            Image(systemName: "arrow.left.and.right")
            Text("Glisse la carte, ou utilise les boutons")
        }
        .font(YZFont.footnote)
        .foregroundStyle(theme.t3)
    }

    @ViewBuilder
    private func controls(_ vm: TriageViewModel) -> some View {
        // GlassEffectContainer : les 3 pastilles se « fondent » entre elles façon
        // Liquid Glass Apple (iOS 26). En deçà, simple HStack.
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 22) { controlButtons(vm) }
        } else {
            controlButtons(vm)
        }
    }

    private func controlButtons(_ vm: TriageViewModel) -> some View {
        HStack(spacing: 22) {
            roundButton(icon: "trash.fill", tone: theme.trash, size: 64) {
                performSwipe(vm, keep: false)
            }
            roundButton(icon: "arrow.uturn.backward", tone: theme.t2, size: 52, tinted: false, disabled: !vm.canUndo) {
                Task { await vm.undo() }
            }
            roundButton(icon: "checkmark", tone: theme.keep, size: 64, glow: true) {
                performSwipe(vm, keep: true)
            }
            // iPad : le bouton aléatoire rejoint le menu flottant du bas (sur iPhone
            // il reste dans l'en-tête). Même Liquid Glass que les autres.
            if hSize == .regular {
                roundButton(icon: "shuffle", tone: theme.accent, size: 52, tinted: false) {
                    Task { await vm.refreshRandom() }
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func roundButton(
        icon: String, tone: Color, size: CGFloat,
        glow: Bool = false, tinted: Bool = true, disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.40, weight: .bold))
                .foregroundStyle(theme.isGlass ? .white : tone)
                .frame(width: size, height: size)
                .modifier(GlassCircle(theme: theme, tone: tone, glow: glow, tinted: tinted))
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
        withAnimation(.easeIn(duration: 0.42)) {
            dragOffset = CGSize(width: keep ? flyDistance : -flyDistance,
                                height: dragOffset.height + 40)
        }
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            // Retrait optimiste ET remise à zéro de l'offset DANS LA MÊME transaction
            // synchrone (aucun await entre les deux) : la nouvelle carte du dessus
            // apparaît directement AU CENTRE, sans hériter de l'offset de vol — sinon
            // elle « revenait à sa place avant de disparaître ». Le tri réel
            // (garder/poubelle) se fait en arrière-plan dans advance().
            vm.advance(file: top, keep: keep)
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
    /// Déplacement (pan) de l'image zoomée — permet de viser un coin, pas que le centre.
    @State private var pan: CGSize = .zero
    @State private var panBase: CGSize = .zero
    @State private var working = false
    @State private var preparingShare = false
    @State private var sharePayload: SharePayload?

    private var store: MediaStore { env.currentStore ?? LocalMediaStore(root: root) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 0) {
                topInfoBar
                Spacer()
                HStack(alignment: .bottom) {
                    roundButton("trash.fill", tint: Color(hex: 0xF06A8C)) { decide(keep: false) }
                    Spacer()
                    // Annuler la dernière décision SANS quitter le plein écran d'abord.
                    roundButton("arrow.uturn.backward", tint: theme.t2) { undoLast() }
                        .opacity((env.triage?.canUndo ?? false) ? 1 : 0.4)
                        .disabled(!(env.triage?.canUndo ?? false))
                    Spacer()
                    roundButton("checkmark", tint: theme.keep) { decide(keep: true) }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
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
        .sheet(item: $sharePayload) { ShareSheet(url: $0.url) }
    }

    @ViewBuilder private var content: some View {
        if let player {
            // Vidéo ENCADRÉE (pas plein bord) : les contrôles natifs (AirPlay, son,
            // jauge de lecture) restent DANS ce cadre — sous la barre du haut
            // (nom + croix + partage) et au-dessus des boutons poubelle/garder.
            // Fini les chevauchements.
            VideoPlayer(player: player)
                .padding(.top, 88)
                .padding(.bottom, 110)
        } else if let image {
            GeometryReader { geo in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(zoom)
                    .offset(pan)
                    .gesture(
                        MagnifyGesture()
                            .onChanged { zoom = min(6, max(1, baseZoom * $0.magnification)) }
                            .onEnded { _ in
                                baseZoom = zoom
                                if zoom <= 1 { withAnimation(.snappy) { pan = .zero }; panBase = .zero }
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation {
                            zoom = zoom > 1 ? 1 : 2.5
                            baseZoom = zoom
                            if zoom <= 1 { pan = .zero; panBase = .zero }
                        }
                    }
                    .highPriorityGesture(
                        DragGesture()
                            .onChanged { value in
                                guard zoom > 1 else { return }
                                // Déplacement borné : on peut viser un coin sans
                                // perdre l'image hors écran.
                                let maxX = geo.size.width * (zoom - 1) / 2
                                let maxY = geo.size.height * (zoom - 1) / 2
                                pan = CGSize(
                                    width: min(maxX, max(-maxX, panBase.width + value.translation.width)),
                                    height: min(maxY, max(-maxY, panBase.height + value.translation.height))
                                )
                            }
                            .onEnded { value in
                                if zoom > 1 {
                                    panBase = pan
                                } else if value.translation.height > 110 {
                                    dismiss()   // glisser vers le bas (hors zoom) = fermer
                                }
                            }
                    )
            }
        } else {
            VStack(spacing: 10) {
                ProgressView().tint(.white)
                if file.kind == .video {
                    Text("Chargement de la vidéo…").font(.footnote).foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }

    /// Bandeau du haut : titre, chemin, taille (+ dimensions, date) — ces détails
    /// n'apparaissent QU'ICI, jamais sur la carte de tri (qui reste épurée).
    private var topInfoBar: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(file.fileName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(folderName)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 10) {
                    Text(Fmt.bytes(file.sizeBytes))
                    if let w = file.pixelWidth, let h = file.pixelHeight {
                        Text("\(w) × \(h)")
                    }
                    Text(Fmt.date(file.captureDate ?? file.modifiedAt))
                }
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(.white.opacity(0.6))
            }
            Spacer(minLength: 8)
            shareButton
            closeButton
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 18)
        .background(
            LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
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

    private var closeButton: some View {
        Button { player?.pause(); dismiss() } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(.white.opacity(0.9))
                .padding(12)
        }
    }

    /// Partager / enregistrer en local (Photos, Fichiers, AirDrop…). Réseau : on
    /// télécharge d'abord dans un fichier temporaire, puis on ouvre la feuille iOS.
    private var shareButton: some View {
        Button { Task { await prepareShare() } } label: {
            Group {
                if preparingShare {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 26))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .frame(width: 34, height: 34)
            .padding(12)
        }
        .disabled(preparingShare)
        .accessibilityLabel("Partager")
    }

    private func prepareShare() async {
        preparingShare = true
        defer { preparingShare = false }
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
            AppLog.error("Préparation partage plein écran", error)
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

    /// Annule la DERNIÈRE décision (poubelle/garder), depuis le plein écran : le
    /// fichier restauré revient en tête du deck, puis on referme le plein écran.
    private func undoLast() {
        guard !working, env.triage?.canUndo == true else { return }
        working = true
        player?.pause()
        Task {
            _ = try? await env.triage?.undo()
            onDecided()
            dismiss()
        }
    }
}

/// Pastille ronde en **Liquid Glass** : vrai `glassEffect` (iOS 26 → iPad) avec
/// repli sur le matériau translucide (iOS 18 → iPhone). `tinted` = teinte colorée
/// (poubelle/garder) vs neutre (retour) ; `glow` = halo coloré (bouton « garder »).
private struct GlassCircle: ViewModifier {
    let theme: YZTheme
    let tone: Color
    let glow: Bool
    let tinted: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if theme.isGlass {
            if #available(iOS 26.0, *) {
                content
                    .glassEffect(glassStyle, in: Circle())
                    .shadow(color: glow ? tone.opacity(0.55) : .black.opacity(0.22),
                            radius: glow ? 16 : 8, y: 4)
            } else {
                content
                    .background {
                        Circle().fill(tinted ? tone.opacity(0.34) : Color.whiteA(0.14))
                        Circle().fill(.ultraThinMaterial).opacity(0.5)
                    }
                    .overlay { Circle().strokeBorder(Color.whiteA(0.42), lineWidth: 0.5) }
                    .shadow(color: glow ? tone.opacity(0.50) : .black.opacity(0.20),
                            radius: glow ? 14 : 8, y: 4)
            }
        } else {
            content
                .background { Circle().fill(theme.card) }
                .overlay { Circle().strokeBorder(theme.sep, lineWidth: 1) }
                .shadow(color: .blackA(0.12), radius: 8, y: 4)
        }
    }

    @available(iOS 26.0, *)
    private var glassStyle: Glass {
        tinted
            ? .regular.tint(tone.opacity(0.55)).interactive()
            : .regular.interactive()
    }
}
