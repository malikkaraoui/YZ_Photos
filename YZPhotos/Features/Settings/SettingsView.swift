import GRDB
import SwiftUI

/// Onglet Réglages : apparence, vidéos, affichage par défaut, et les disques
/// connus — chaque disque garde ses statistiques en local, accrochées à son
/// identifiant unique (UUID du volume), même débranché.
struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var knownDrives: [DriveRecord] = []
    @State private var driveStats: [String: DriveStats] = [:]
    @State private var editedNames: [String: String] = [:]

    var body: some View {
        @Bindable var settings = env.settings
        NavigationStack {
            Form {
                Section("Apparence") {
                    Picker("Thème", selection: $settings.appearance) {
                        ForEach(AppSettings.Appearance.allCases) { appearance in
                            Text(appearance.rawValue).tag(appearance)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Toggle("Lecture automatique des vidéos", isOn: $settings.autoPlayVideos)
                } header: {
                    Text("Vidéos")
                } footer: {
                    Text("Quand c'est activé, la vidéo démarre dès que tu la touches, dans l'aperçu comme dans le deck de tri.")
                }

                Section {
                    Picker("Ranger par défaut", selection: $settings.defaultGridOrder) {
                        ForEach(GridOrder.allCases) { order in
                            Label(order.rawValue, systemImage: order.icon).tag(order)
                        }
                    }
                } header: {
                    Text("Affichage par défaut")
                } footer: {
                    Text("Appliqué à l'ouverture des onglets Photos, Vidéos et Captures. L'onglet « Par taille » garde toujours son ordre par taille.")
                }

                Section {
                    ForEach(knownDrives) { drive in
                        driveRow(drive)
                    }
                } header: {
                    Text("Disques connus")
                } footer: {
                    Text("Chaque disque est reconnu par son identifiant unique : ses statistiques, son tri et sa corbeille restent enregistrés sur l'iPad même quand il est débranché. Tu peux brancher plusieurs disques à tour de rôle sans rien mélanger.")
                }
            }
            .navigationTitle("Réglages")
        }
        .task { await reload() }
    }

    @ViewBuilder
    private func driveRow(_ drive: DriveRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "externaldrive.fill")
                    .foregroundStyle(env.driveAccess.connectedDrive?.id == drive.id ? .green : .secondary)
                TextField("Nom du disque", text: .init(
                    get: { editedNames[drive.id] ?? drive.name },
                    set: { editedNames[drive.id] = $0 }
                ), onCommit: { rename(drive) })
                    .font(.headline)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 320)
                if env.driveAccess.connectedDrive?.id == drive.id {
                    Text("Branché")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
                Spacer()
            }
            if let stats = driveStats[drive.id] {
                HStack(spacing: 16) {
                    Label("\(Fmt.count(stats.totalCount)) fichiers · \(Fmt.bytes(stats.totalBytes))", systemImage: "doc.on.doc")
                    Label("\(Fmt.bytes(stats.freedBytes)) libérés", systemImage: "trash")
                        .foregroundStyle(.green)
                    Label("\(stats.progress.formatted(.percent.precision(.fractionLength(0)))) triés", systemImage: "checkmark.circle")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            if let date = drive.lastScanCompletedAt {
                Text("Dernière analyse : \(Fmt.date(date))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private func rename(_ drive: DriveRecord) {
        guard let newName = editedNames[drive.id]?.trimmingCharacters(in: .whitespaces),
              !newName.isEmpty, newName != drive.name else { return }
        Task {
            try? await env.database.writer.write { db in
                try db.execute(sql: "UPDATE drive SET name = ? WHERE id = ?", arguments: [newName, drive.id])
            }
            await reload()
        }
    }

    private func reload() async {
        let drives = (try? await env.database.writer.read { db in
            try DriveRecord.fetchAll(db)
        }) ?? []
        var stats: [String: DriveStats] = [:]
        for drive in drives {
            stats[drive.id] = try? await env.database.writer.read { db in
                try Queries.stats(db, driveId: drive.id)
            }
        }
        knownDrives = drives
        driveStats = stats
    }
}
