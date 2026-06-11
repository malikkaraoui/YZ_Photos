import AVKit
import SwiftUI

/// Le deck façon Tinder : swipe gauche = poubelle, swipe droite = garder.
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
    @Environment(\.dismiss) private var dismiss
    @State private var vm: TriageViewModel?
    @State private var dragOffset: CGSize = .zero
    @State private var isFlying = false
    @State private var playingVideo: FileRecord?

    private let swipeThreshold: CGFloat = 150

    var body: some View {
        Group {
            if let vm {
                deck(vm)
            } else {
                ProgressView()
            }
        }
        .task(id: drive.id) {
            if vm == nil, let triage = env.triage {
                vm = TriageViewModel(
                    database: env.database,
                    thumbnails: env.thumbnails,
                    triage: triage,
                    driveId: drive.id,
                    root: root,
                    filter: filter,
                    scope: scope,
                    onDiskError: { env.driveDidDisconnect() }
                )
            }
            await vm?.refresh()
        }
        .onChange(of: env.scan.phase) { _, newPhase in
            // La passe 1 terminée (.analyzing) ou le scan fini : nouvelles cartes.
            if newPhase == .analyzing || newPhase == .finished {
                Task { await vm?.refresh() }
            }
        }
        // Undo global (bouton flottant) : le deck recharge sa fenêtre.
        .onChange(of: env.triage?.undoCount) { old, new in
            if let old, let new, new < old {
                Task { await vm?.refresh() }
            }
        }
        .fullScreenCover(item: $playingVideo) { file in
            VideoPlayerSheet(url: file.currentURL(driveRoot: root))
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
        HStack {
            if isModal {
                Button {
                    dismiss()
                } label: {
                    Label("Fermer", systemImage: "xmark")
                        .font(.title3)
                }
            }
            Text(deckTitle)
                .font(.largeTitle.bold())
                .lineLimit(1)
            Spacer()
            Text("\(Fmt.count(vm.remaining)) restantes")
                .font(.title3.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(.quaternary, in: Capsule())
        }
        .padding(.top, 12)
    }

    private var deckTitle: String {
        if let scopeTitle { return "Trier : \(scopeTitle)" }
        return filter == .all ? "Trier" : "Trier : \(filter.title)"
    }

    private func cards(_ vm: TriageViewModel) -> some View {
        ZStack {
            ForEach(Array(vm.window.prefix(3).enumerated().reversed()), id: \.element.id) { index, file in
                if index == 0 {
                    SwipeCardView(file: file, root: root)
                        .overlay(stamps)
                        .offset(dragOffset)
                        .rotationEffect(.degrees(Double(dragOffset.width / 25)))
                        .gesture(dragGesture(vm))
                        .onTapGesture {
                            if file.kind == .video { playingVideo = file }
                        }
                } else {
                    SwipeCardView(file: file, root: root)
                        .scaleEffect(1 - CGFloat(index) * 0.03)
                        .offset(y: CGFloat(index) * 10)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Tampons GARDER / POUBELLE qui apparaissent pendant le glissement.
    private var stamps: some View {
        ZStack(alignment: .top) {
            HStack {
                stamp("GARDER", color: .green, rotation: -12)
                    .opacity(dragOffset.width > 40 ? min(1, Double(dragOffset.width - 40) / 110) : 0)
                Spacer()
                stamp("POUBELLE", color: .red, rotation: 12)
                    .opacity(dragOffset.width < -40 ? min(1, Double(-dragOffset.width - 40) / 110) : 0)
            }
            .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func stamp(_ text: String, color: Color, rotation: Double) -> some View {
        Text(text)
            .font(.system(size: 38, weight: .heavy))
            .foregroundStyle(color)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(color, lineWidth: 4))
            .rotationEffect(.degrees(rotation))
    }

    private func controls(_ vm: TriageViewModel) -> some View {
        HStack(spacing: 60) {
            controlButton(
                icon: "trash.fill", color: .red, size: 76,
                label: "Poubelle"
            ) { performSwipe(vm, keep: false) }

            controlButton(
                icon: "arrow.uturn.backward", color: .orange, size: 60,
                label: "Retour", disabled: !vm.canUndo
            ) {
                Task { await vm.undo() }
            }

            controlButton(
                icon: "checkmark", color: .green, size: 76,
                label: "Garder"
            ) { performSwipe(vm, keep: true) }
        }
        .padding(.vertical, 8)
    }

    private func controlButton(
        icon: String, color: Color, size: CGFloat,
        label: String, disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 6) {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(disabled ? Color.gray : color)
                    .frame(width: size, height: size)
                    .background(.regularMaterial, in: Circle())
                    .overlay(Circle().stroke(disabled ? Color.gray.opacity(0.3) : color.opacity(0.5), lineWidth: 2))
            }
            .disabled(disabled || isFlying)
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func emptyState(_ vm: TriageViewModel) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
            Text("Tout est trié ici !")
                .font(.title.bold())
            Text(env.scan.isRunning
                 ? "L'analyse du disque continue, de nouvelles photos vont arriver."
                 : "Aucun fichier à trier pour ce filtre.")
                .font(.title3)
                .foregroundStyle(.secondary)
            if vm.canUndo {
                Button {
                    Task { await vm.undo() }
                } label: {
                    Label("Annuler la dernière décision", systemImage: "arrow.uturn.backward")
                        .font(.title3)
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Gestes

    private func dragGesture(_ vm: TriageViewModel) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isFlying else { return }
                dragOffset = value.translation
            }
            .onEnded { value in
                guard !isFlying else { return }
                if value.translation.width > swipeThreshold {
                    performSwipe(vm, keep: true)
                } else if value.translation.width < -swipeThreshold {
                    performSwipe(vm, keep: false)
                } else {
                    withAnimation(.spring(duration: 0.3)) { dragOffset = .zero }
                }
            }
    }

    private func performSwipe(_ vm: TriageViewModel, keep: Bool) {
        guard !isFlying, let top = vm.window.first else { return }
        isFlying = true
        withAnimation(.easeOut(duration: 0.22)) {
            dragOffset = CGSize(width: keep ? 1400 : -1400, height: dragOffset.height)
        }
        Task {
            try? await Task.sleep(for: .milliseconds(230))
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
