import GRDB
import SwiftUI

/// Bannière flottante de progression du scan — un tap ouvre le détail complet.
struct ScanProgressBanner: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.yzTheme) private var theme
    @State private var showDetail = false

    var body: some View {
        Button {
            showDetail = true
        } label: {
            HStack(spacing: 12) {
                ProgressView()
                    .controlSize(.small)
                Text(label)
                    .font(YZFont.subhead.monospacedDigit())
                    .foregroundStyle(theme.t1)
                    .lineLimit(1)
                if env.scan.phase == .analyzing, env.scan.analyzedTotal > 0 {
                    YZProgressBar(
                        value: Double(env.scan.analyzedDone) / Double(env.scan.analyzedTotal),
                        tone: theme.accent
                    )
                    .frame(width: 160)
                }
                Image(systemName: "chevron.down.circle.fill")
                    .foregroundStyle(theme.t2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .yzSurface(theme, radius: 100, elevated: true)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            ScrollView {
                ScanDetailView(asSheet: true)
            }
            .scrollContentBackground(.hidden)
            .yzScreenBackground(theme)
            .presentationDetents([.medium, .large])
        }
    }

    private var label: String {
        switch env.scan.phase {
        case .enumerating:
            "Parcours… \(Fmt.count(env.scan.filesSeen)) fichiers"
        case .analyzing:
            "Analyse \(Fmt.count(env.scan.analyzedDone))/\(Fmt.count(env.scan.analyzedTotal))"
            + (env.scan.etaSeconds.map { " · \(Fmt.eta($0))" } ?? "")
        default:
            ""
        }
    }
}

/// Onglet Analyse : étapes détaillées, progression, lancement/relance.
struct ScanTabView: View {
    let drive: DriveRecord
    let root: URL

    @Environment(\.yzTheme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                ScanDetailView(asSheet: false, drive: drive, root: root)
            }
            .scrollContentBackground(.hidden)
            .yzScreenBackground(theme)
            .navigationTitle("Analyse du disque")
        }
        .tint(theme.accent)
    }
}

/// Le détail du scan étape par étape, façon « Vérifs » : chaque étape a son
/// état (à venir / en cours / terminée), sa barre de progression et son
/// explication en français simple.
struct ScanDetailView: View {
    /// true = présenté en sheet (titre + bouton Fermer intégrés).
    var asSheet = true
    /// Fournis en mode onglet : permettent de (re)lancer l'analyse.
    var drive: DriveRecord?
    var root: URL?

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @Environment(\.yzTheme) private var theme
    /// Date de dernière analyse, lue en direct depuis la base (pas la struct figée).
    @State private var lastCompletedAt: Date?

    private enum StepState {
        case pending, running, done, failed
    }

    var body: some View {
        VStack(spacing: 20) {
            if asSheet {
                HStack {
                    Text("Analyse du disque")
                        .yzDisplay(30)
                        .foregroundStyle(theme.t1)
                    Spacer()
                    Button("Fermer") { dismiss() }
                        .buttonStyle(YZButtonStyle(.secondary))
                }
            }

            statusHeader

            stepCard(
                number: 1,
                title: "Parcours du disque",
                explanation: "L'app liste tous les fichiers (noms, tailles, dates) — les onglets se remplissent dès cette étape. Pas de barre de progression possible ici : on ne connaît pas encore le nombre total de fichiers.",
                state: step1State
            ) {
                if step1State == .running {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                    Text("\(Fmt.count(env.scan.filesSeen)) fichiers · \(Fmt.bytes(env.scan.bytesSeen)) découverts…")
                        .font(YZFont.headline.monospacedDigit())
                        .foregroundStyle(theme.t1)
                    currentFileLine
                } else if step1State == .done {
                    // Les octets sont LE chiffre qui bouge après un nettoyage :
                    // -100 vidéos est invisible sur 150 000 fichiers, mais
                    // -100 Go se voit immédiatement ici.
                    Text("\(Fmt.count(env.scan.filesSeen)) fichiers · \(Fmt.bytes(env.scan.bytesSeen)) listés ✓")
                        .font(YZFont.subheadSemi)
                        .foregroundStyle(theme.keep)
                }
            }

            stepCard(
                number: 2,
                title: "Analyse des fichiers",
                explanation: "Pour chaque fichier nouveau ou modifié : empreinte (pour les doublons), miniature, dimensions, détection de capture d'écran. Un fichier déjà analysé n'est jamais retraité.",
                state: step2State
            ) {
                if step2State == .running, env.scan.analyzedTotal > 0 {
                    YZProgressBar(
                        value: Double(env.scan.analyzedDone) / Double(env.scan.analyzedTotal),
                        tone: theme.accent
                    )
                    HStack {
                        Text("\(Fmt.count(env.scan.analyzedDone)) / \(Fmt.count(env.scan.analyzedTotal))")
                            .font(YZFont.headline.monospacedDigit())
                            .foregroundStyle(theme.t1)
                        Spacer()
                        if env.scan.rate > 1 {
                            Text("\(Int(env.scan.rate))/s")
                                .font(YZFont.headline.monospacedDigit())
                                .foregroundStyle(theme.t2)
                        }
                        if let eta = env.scan.etaSeconds {
                            Text("· reste \(Fmt.eta(eta))")
                                .font(YZFont.headline)
                                .foregroundStyle(theme.t2)
                        }
                    }
                    currentFileLine
                    HStack(spacing: 18) {
                        Label("\(Fmt.count(env.scan.photosAnalyzed)) photos", systemImage: "photo")
                        Label("\(Fmt.count(env.scan.videosAnalyzed)) vidéos", systemImage: "video")
                        Label("\(Fmt.count(env.scan.screenshotsFound)) captures", systemImage: "camera.viewfinder")
                    }
                    .font(YZFont.subhead.monospacedDigit())
                    .foregroundStyle(theme.t2)
                } else if step2State == .done {
                    Text("\(Fmt.count(env.scan.analyzedDone)) fichiers analysés ✓")
                        .font(YZFont.subheadSemi)
                        .foregroundStyle(theme.keep)
                }
            }

            actionButton
        }
        .padding(asSheet ? 28 : 20)
        .task(id: env.scan.phase) { await refreshLastCompleted() }
    }

    // MARK: - En-tête d'état

    private var statusHeader: some View {
        HStack(spacing: 12) {
            statusIcon
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(YZFont.headline)
                    .foregroundStyle(theme.t1)
                Text(lastCompletedText)
                    .font(YZFont.subhead)
                    .foregroundStyle(theme.t2)
                if env.scan.isRunning, env.scan.memoryFootprintMB > 0 {
                    Text("Mémoire de l'app : \(env.scan.memoryFootprintMB) Mo (garde-fou anti-crash actif)")
                        .font(YZFont.caption)
                        .foregroundStyle(theme.t3)
                }
            }
            Spacer()
        }
        .padding(16)
        .yzSurface(theme)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch env.scan.phase {
        case .enumerating, .analyzing:
            ProgressView()
        case .finished:
            Image(systemName: "checkmark.circle.fill")
                .font(.title)
                .foregroundStyle(theme.keep)
        case .failed, .diskDisconnected:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title)
                .foregroundStyle(theme.warn)
        case .idle:
            Image(systemName: "circle.dashed")
                .font(.title)
                .foregroundStyle(theme.t2)
        }
    }

    private var statusTitle: String {
        switch env.scan.phase {
        case .idle: "Aucune analyse en cours"
        case .enumerating: "Analyse en cours — étape 1 sur 2"
        case .analyzing: "Analyse en cours — étape 2 sur 2"
        case .finished: "Analyse terminée"
        case .failed(let message): "Erreur : \(message)"
        case .diskDisconnected: "Disque débranché pendant l'analyse — rebranche-le puis relance, elle reprendra où elle en était."
        }
    }

    private var lastCompletedText: String {
        if let lastCompletedAt {
            return "Dernière analyse complète : \(Fmt.date(lastCompletedAt))"
        }
        return "Aucune analyse complète pour l'instant."
    }

    // MARK: - Cartes d'étapes

    private var step1State: StepState {
        switch env.scan.phase {
        case .idle: .pending
        case .enumerating: .running
        case .analyzing, .finished: .done
        case .failed, .diskDisconnected: .failed
        }
    }

    private var step2State: StepState {
        switch env.scan.phase {
        case .idle, .enumerating: .pending
        case .analyzing: .running
        case .finished: .done
        case .failed, .diskDisconnected: .failed
        }
    }

    @ViewBuilder
    private func stepCard(
        number: Int,
        title: String,
        explanation: String,
        state: StepState,
        @ViewBuilder detail: () -> some View
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: YZRadius.card, style: .continuous)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                stepIcon(state)
                Text("Étape \(number) — \(title)")
                    .font(YZFont.headline)
                    .foregroundStyle(theme.t1)
                Spacer()
            }
            Text(explanation)
                .font(YZFont.subhead)
                .foregroundStyle(theme.t2)
            detail()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if state == .running { shape.fill(theme.accentSoft) }
        }
        .yzSurface(theme)
        .overlay {
            switch state {
            case .running:
                shape.strokeBorder(theme.accent, lineWidth: 1)
            case .done:
                shape.strokeBorder(theme.keep, lineWidth: 1)
            default:
                EmptyView()
            }
        }
        .opacity(state == .pending ? 0.6 : 1)
    }

    @ViewBuilder
    private func stepIcon(_ state: StepState) -> some View {
        switch state {
        case .pending:
            Image(systemName: "circle.dashed")
                .font(.title3)
                .foregroundStyle(theme.t3)
        case .running:
            ProgressView()
                .controlSize(.small)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(theme.keep)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(theme.warn)
        }
    }

    @ViewBuilder
    private var currentFileLine: some View {
        if !env.scan.currentPath.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text((env.scan.currentPath as NSString).deletingLastPathComponent)
                    .font(YZFont.caption)
                    .foregroundStyle(theme.t3)
                    .lineLimit(1)
                    .truncationMode(.head)
                Text((env.scan.currentPath as NSString).lastPathComponent)
                    .font(.system(size: 11, weight: .regular).monospaced())
                    .foregroundStyle(theme.t2)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionButton: some View {
        if env.scan.isRunning {
            Button(role: .destructive) {
                env.scan.cancel()
                if asSheet { dismiss() }
            } label: {
                Label("Arrêter l'analyse", systemImage: "stop.fill")
            }
            .buttonStyle(YZButtonStyle(.destructive, size: .lg))
        } else if let drive, let root {
            Button {
                env.scan.startScan(drive: drive, store: env.currentStore ?? LocalMediaStore(root: root))
            } label: {
                Label(
                    env.scan.phase == .idle ? "Lancer l'analyse" : "Relancer l'analyse",
                    systemImage: "arrow.clockwise"
                )
            }
            .buttonStyle(YZButtonStyle(.primary, size: .lg))
        }
    }

    private func refreshLastCompleted() async {
        guard let driveId = drive?.id ?? env.driveAccess.connectedDrive?.id else { return }
        lastCompletedAt = try? await env.database.writer.read { db in
            try DriveRecord.fetchOne(db, key: driveId)?.lastScanCompletedAt
        }
    }
}
