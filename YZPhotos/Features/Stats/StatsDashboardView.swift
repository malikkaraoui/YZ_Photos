import GRDB
import SwiftUI

/// Tableau de bord : progression du tri, espace libéré, compteurs —
/// mis à jour en temps réel via ValueObservation.
struct StatsDashboardView: View {
    let drive: DriveRecord
    let root: URL

    @Environment(AppEnvironment.self) private var env
    @Environment(\.yzTheme) private var theme
    @State private var stats = DriveStats()

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 12) {
                    heroCard
                    chipsGrid
                    scanCard
                }
                .padding(14)
                .frame(minHeight: geo.size.height - 8, alignment: .top)
            }
            .scrollContentBackground(.hidden)
        }
        .tint(theme.accent)
        .task(id: drive.id) {
            let driveId = drive.id
            let observation = ValueObservation.tracking { db in
                try Queries.stats(db, driveId: driveId)
            }
            do {
                for try await value in observation.values(in: env.database.writer) {
                    stats = value
                }
            } catch {}
        }
    }

    // MARK: Hero (anneau de progression + chiffres clés)

    private var heroCard: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle().stroke(theme.isGlass ? Color.whiteA(0.18) : theme.bg3, lineWidth: 13)
                Circle()
                    .trim(from: 0, to: stats.progress)
                    .stroke(AngularGradient(colors: [theme.keep, theme.keep.opacity(0.55)], center: .center),
                            style: StrokeStyle(lineWidth: 13, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(stats.progress.formatted(.percent.precision(.fractionLength(0))))
                        .font(.system(size: 28, weight: .bold).monospacedDigit())
                        .foregroundStyle(theme.t1)
                    Text("triées").font(YZFont.caption).foregroundStyle(theme.t2)
                }
            }
            .frame(width: 116, height: 116)

            VStack(alignment: .leading, spacing: 12) {
                miniStat("Espace libéré", Fmt.bytes(stats.freedBytes), theme.keep)
                miniStat("Reste à trier", Fmt.count(stats.untriagedCount), theme.accent)
                miniStat("Dans la corbeille", Fmt.bytes(stats.trashedBytes), theme.trash)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .yzSurface(theme)
    }

    private func miniStat(_ title: LocalizedStringKey, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(YZFont.footnote).foregroundStyle(theme.t2)
            Text(value).font(.title3.bold().monospacedDigit()).foregroundStyle(color)
        }
    }

    // MARK: Grille compacte (chips)

    private var chipsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            chip("Photos", stats.photoCount, "photo", theme.accent)
            chip("Vidéos", stats.videoCount, "video", theme.accent)
            chip("Captures", stats.screenshotCount, "camera.viewfinder", theme.accent)
            chip("Doublons", stats.duplicateCount, "square.on.square", theme.warn)
            chip("Gardées", stats.keptCount, "checkmark.circle", theme.keep)
            chip("Supprimées", stats.deletedCount, "trash", theme.trash)
        }
    }

    private func chip(_ title: LocalizedStringKey, _ count: Int, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text(Fmt.count(count))
                .font(.system(size: 21, weight: .bold).monospacedDigit())
                .foregroundStyle(theme.t1)
            Text(title)
                .font(YZFont.caption).foregroundStyle(theme.t2)
                .lineLimit(1).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .yzSurface(theme, radius: YZRadius.card)
    }

    // MARK: Bandeau analyse (slim)

    private var scanCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "externaldrive").font(.title3).foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Fmt.count(stats.totalCount)) fichiers · \(Fmt.bytes(stats.totalBytes))")
                    .font(YZFont.subheadSemi).foregroundStyle(theme.t1)
                Text(scanStatusText)
                    .font(YZFont.footnote).foregroundStyle(theme.t2).lineLimit(1)
            }
            Spacer(minLength: 8)
            if env.scan.isRunning {
                Button("Arrêter") { env.scan.cancel() }
                    .buttonStyle(YZButtonStyle(.secondary))
            } else {
                Button {
                    env.scan.startScan(drive: drive, store: env.currentStore ?? LocalMediaStore(root: root))
                } label: {
                    Label("Analyser", systemImage: "arrow.clockwise")
                }
                .buttonStyle(YZButtonStyle(.secondary))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .yzSurface(theme)
    }

    private var scanStatusText: String {
        switch env.scan.phase {
        case .idle: "En attente."
        case .enumerating: "Parcours du disque… \(Fmt.count(env.scan.filesSeen)) fichiers vus."
        case .analyzing: "Analyse \(Fmt.count(env.scan.analyzedDone)) / \(Fmt.count(env.scan.analyzedTotal))."
        case .finished: "Terminée" + (drive.lastScanCompletedAt.map { " le \(Fmt.date($0))" } ?? ".")
        case .failed(let message): "Erreur : \(message)"
        case .diskDisconnected: "Disque débranché pendant l'analyse."
        }
    }
}
