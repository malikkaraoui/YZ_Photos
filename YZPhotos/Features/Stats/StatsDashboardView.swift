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
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    progressRing
                    statsGrid
                    scanSection
                }
                .padding(24)
            }
            .scrollContentBackground(.hidden)
            .yzScreenBackground(theme)
            .navigationTitle("Statistiques · \(drive.name)")
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

    private var progressRing: some View {
        HStack(spacing: 40) {
            ZStack {
                Circle()
                    .stroke(theme.bg3, lineWidth: 22)
                Circle()
                    .trim(from: 0, to: stats.progress)
                    .stroke(
                        AngularGradient(colors: [theme.keep, theme.keep.opacity(0.6)], center: .center),
                        style: StrokeStyle(lineWidth: 22, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack {
                    Text(stats.progress.formatted(.percent.precision(.fractionLength(0))))
                        .font(.system(size: 44, weight: .bold).monospacedDigit())
                        .foregroundStyle(theme.t1)
                    Text("triées")
                        .font(YZFont.headline)
                        .foregroundStyle(theme.t2)
                }
            }
            .frame(width: 220, height: 220)

            VStack(alignment: .leading, spacing: 14) {
                bigStat("Espace libéré", value: Fmt.bytes(stats.freedBytes), color: theme.keep)
                bigStat("Dans la corbeille", value: "\(Fmt.bytes(stats.trashedBytes)) · \(Fmt.count(stats.trashedCount)) fichiers", color: theme.trash)
                bigStat("Reste à trier", value: Fmt.count(stats.untriagedCount), color: theme.accent)
            }
        }
        .padding(.top, 12)
    }

    private func bigStat(_ title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(YZFont.headline)
                .foregroundStyle(theme.t2)
            Text(value)
                .font(.title.bold().monospacedDigit())
                .foregroundStyle(color)
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
            statCard("Fichiers sur le disque", value: Fmt.count(stats.totalCount), sub: Fmt.bytes(stats.totalBytes), icon: "externaldrive", accent: true)
            statCard("Photos", value: Fmt.count(stats.photoCount), sub: nil, icon: "photo")
            statCard("Vidéos", value: Fmt.count(stats.videoCount), sub: nil, icon: "video")
            statCard("Captures d'écran", value: Fmt.count(stats.screenshotCount), sub: nil, icon: "camera.viewfinder")
            statCard("Doublons", value: Fmt.count(stats.duplicateCount), sub: nil, icon: "square.on.square")
            statCard("Gardées", value: Fmt.count(stats.keptCount), sub: nil, icon: "checkmark.circle", tint: theme.keep)
            statCard("Supprimées", value: Fmt.count(stats.deletedCount), sub: "\(Fmt.bytes(stats.freedBytes)) libérés", icon: "trash", tint: theme.trash)
        }
    }

    private func statCard(_ title: String, value: String, sub: String?, icon: String, tint: Color? = nil, accent: Bool = false) -> some View {
        let iconColor = accent ? theme.accent : (tint ?? theme.accent)
        let valueColor = accent ? theme.accent : theme.t1
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(iconColor)
                Spacer()
            }
            Text(value)
                .font(.system(size: 34, weight: .bold).monospacedDigit())
                .foregroundStyle(valueColor)
            Text(title)
                .font(YZFont.subheadSemi)
                .foregroundStyle(theme.t2)
            if let sub {
                Text(sub)
                    .font(YZFont.footnote)
                    .foregroundStyle(theme.t3)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .yzSurface(theme)
    }

    private var scanSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Analyse du disque")
                    .font(.headline)
                Text(scanStatusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if env.scan.isRunning {
                Button("Arrêter") { env.scan.cancel() }
                    .buttonStyle(.bordered)
            } else {
                Button {
                    env.scan.startScan(drive: drive, store: env.currentStore ?? LocalMediaStore(root: root))
                } label: {
                    Label("Relancer l'analyse", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
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
