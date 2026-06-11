import GRDB
import SwiftUI

/// Tableau de bord : progression du tri, espace libéré, compteurs —
/// mis à jour en temps réel via ValueObservation.
struct StatsDashboardView: View {
    let drive: DriveRecord
    let root: URL

    @Environment(AppEnvironment.self) private var env
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
            .navigationTitle("Statistiques · \(drive.name)")
        }
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
                    .stroke(Color(.systemGray5), lineWidth: 22)
                Circle()
                    .trim(from: 0, to: stats.progress)
                    .stroke(
                        AngularGradient(colors: [.green, .mint], center: .center),
                        style: StrokeStyle(lineWidth: 22, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack {
                    Text(stats.progress.formatted(.percent.precision(.fractionLength(0))))
                        .font(.system(size: 44, weight: .bold).monospacedDigit())
                    Text("triées")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 220, height: 220)

            VStack(alignment: .leading, spacing: 14) {
                bigStat("Espace libéré", value: Fmt.bytes(stats.freedBytes), color: .green)
                bigStat("Dans la corbeille", value: "\(Fmt.bytes(stats.trashedBytes)) · \(Fmt.count(stats.trashedCount)) fichiers", color: .red)
                bigStat("Reste à trier", value: Fmt.count(stats.untriagedCount), color: .blue)
            }
        }
        .padding(.top, 12)
    }

    private func bigStat(_ title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title.bold().monospacedDigit())
                .foregroundStyle(color)
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
            statCard("Fichiers sur le disque", value: Fmt.count(stats.totalCount), sub: Fmt.bytes(stats.totalBytes), icon: "externaldrive", color: .gray)
            statCard("Photos", value: Fmt.count(stats.photoCount), sub: nil, icon: "photo", color: .blue)
            statCard("Vidéos", value: Fmt.count(stats.videoCount), sub: nil, icon: "video", color: .purple)
            statCard("Captures d'écran", value: Fmt.count(stats.screenshotCount), sub: nil, icon: "camera.viewfinder", color: .indigo)
            statCard("Doublons", value: Fmt.count(stats.duplicateCount), sub: nil, icon: "square.on.square", color: .orange)
            statCard("Gardées", value: Fmt.count(stats.keptCount), sub: nil, icon: "checkmark.circle", color: .green)
            statCard("Supprimées", value: Fmt.count(stats.deletedCount), sub: "\(Fmt.bytes(stats.freedBytes)) libérés", icon: "trash", color: .red)
        }
    }

    private func statCard(_ title: String, value: String, sub: String?, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.system(size: 34, weight: .bold).monospacedDigit())
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            if let sub {
                Text(sub)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
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
                    env.scan.startScan(drive: drive, root: root)
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
