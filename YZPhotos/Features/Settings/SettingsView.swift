import GRDB
import SwiftUI

/// Onglet Réglages : apparence, vidéos, affichage par défaut, et les disques
/// connus — chaque disque garde ses statistiques en local, accrochées à son
/// identifiant unique (UUID du volume), même débranché.
struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.yzTheme) private var theme
    @State private var knownDrives: [DriveRecord] = []
    @State private var driveStats: [String: DriveStats] = [:]
    @State private var editedNames: [String: String] = [:]
    @State private var showPicker = false
    @State private var confirmEject = false
    @State private var driveToForget: DriveRecord?
    @State private var actionError: String?

    /// Version affichée = celle du build (toujours synchronisée avec MARKETING_VERSION).
    static var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(v) (build \(b))"
    }

    var body: some View {
        @Bindable var settings = env.settings
            Form {
                Section {
                    HStack {
                        Picker("Thème", selection: $settings.themeKind) {
                            ForEach(YZThemeKind.allCases) { kind in
                                Label(kind.rawValue, systemImage: kind.sfSymbol).tag(kind)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 360)
                        Spacer(minLength: 0)
                    }
                } header: {
                    Text("Apparence")
                } footer: {
                    Text("« Verre » est le thème signature (aurora translucide). « Clair » et « Sombre » sont des variantes sobres.")
                }

                Section {
                    HStack {
                        Toggle("Lecture automatique des vidéos", isOn: $settings.autoPlayVideos)
                            .frame(maxWidth: 420)
                        Spacer(minLength: 0)
                    }
                } header: {
                    Text("Vidéos")
                } footer: {
                    Text("Quand c'est activé, la vidéo démarre dès que tu la touches, dans l'aperçu comme dans le deck de tri.")
                }

                if UIDevice.current.userInterfaceIdiom == .phone {
                    Section {
                        HStack {
                            Toggle("Autoriser la rotation paysage", isOn: $settings.allowLandscapeIPhone)
                                .frame(maxWidth: 420)
                            Spacer(minLength: 0)
                        }
                    } header: {
                        Text("Rotation")
                    } footer: {
                        Text("Par défaut, l'iPhone reste en portrait. Active pour permettre l'affichage en paysage.")
                    }
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
                    Button {
                        showPicker = true
                    } label: {
                        Label("Brancher un autre disque…", systemImage: "externaldrive.badge.plus")
                    }
                } header: {
                    Text("Disques connus")
                } footer: {
                    Text("Chaque disque est reconnu par son identifiant unique : ses statistiques, son tri et sa corbeille restent enregistrés sur l'appareil même quand il est débranché. Tu peux brancher plusieurs disques à tour de rôle sans rien mélanger.")
                }

                Section {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                            .foregroundStyle(theme.t1)
                        Spacer()
                        Text(Self.appVersion)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(theme.t2)
                    }
                } header: {
                    Text("À propos")
                }
            }
            .scrollContentBackground(.hidden)
        .task { await reload() }
        .fileImporter(isPresented: $showPicker, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result {
                do {
                    try env.attachNewDrive(pickedURL: url)
                } catch {
                    actionError = error.localizedDescription
                }
            }
        }
        .confirmationDialog(
            "Une analyse est en cours",
            isPresented: $confirmEject,
            titleVisibility: .visible
        ) {
            Button("Éjecter quand même", role: .destructive) {
                env.ejectDrive()
            }
            Button("Continuer l'analyse", role: .cancel) {}
        } message: {
            Text("Le travail déjà fait est enregistré : si tu rebranches ce disque plus tard, l'analyse reprendra où elle s'est arrêtée.")
        }
        .confirmationDialog(
            "Supprimer « \(driveToForget?.name ?? "") » ?",
            isPresented: .init(
                get: { driveToForget != nil },
                set: { if !$0 { driveToForget = nil } }
            ),
            titleVisibility: .visible,
            presenting: driveToForget
        ) { drive in
            Button("Supprimer le disque et ses données", role: .destructive) {
                forget(drive)
            }
            Button("Annuler", role: .cancel) {}
        } message: { drive in
            Text("Toutes les statistiques, le tri et la corbeille enregistrés pour « \(drive.name) » seront effacés de l'appareil. Le contenu du disque lui-même n'est pas touché. Cette action est irréversible.")
        }
        .alert("Impossible de changer de disque", isPresented: .init(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(actionError ?? "")
        }
    }

    /// Éjecte le disque branché ; demande confirmation si un travail tourne
    /// (l'interrompre est sans risque mais autant prévenir).
    private func ejectConnectedDrive() {
        if env.scan.isRunning || env.duplicates.isRunning {
            confirmEject = true
        } else {
            env.ejectDrive()
        }
    }

    /// Bascule sur un disque connu déjà branché ; sinon explique pourquoi.
    private func switchTo(_ drive: DriveRecord) {
        if !env.switchDrive(to: drive) {
            actionError = "« \(drive.name) » n'est pas branché ou n'est pas accessible. Branche-le en USB-C, attends quelques secondes, puis réessaie."
        }
    }

    @ViewBuilder
    private func driveRow(_ drive: DriveRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "externaldrive.fill")
                    .foregroundStyle(env.driveAccess.connectedDrive?.id == drive.id ? theme.keep : theme.t2)
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
                        .foregroundStyle(theme.keep)
                }
                Spacer()
                if env.driveAccess.connectedDrive?.id == drive.id {
                    Button(role: .destructive) {
                        ejectConnectedDrive()
                    } label: {
                        Label("Éjecter", systemImage: "eject.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(theme.trash)
                } else {
                    Button {
                        switchTo(drive)
                    } label: {
                        Label("Brancher", systemImage: "externaldrive.connected.to.line.below")
                    }
                    .buttonStyle(.bordered)
                }
                // Suppression définitive du disque connu (en plus de l'éjection) :
                // efface ses données locales. Confirmation obligatoire (détrompeur).
                Button(role: .destructive) {
                    driveToForget = drive
                } label: {
                    Label("Supprimer", systemImage: "trash")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
            if let stats = driveStats[drive.id] {
                HStack(spacing: 16) {
                    Label("\(Fmt.count(stats.totalCount)) fichiers · \(Fmt.bytes(stats.totalBytes))", systemImage: "doc.on.doc")
                    Label("\(Fmt.bytes(stats.freedBytes)) libérés", systemImage: "trash")
                        .foregroundStyle(theme.keep)
                    Label("\(stats.progress.formatted(.percent.precision(.fractionLength(0)))) triés", systemImage: "checkmark.circle")
                }
                .font(.subheadline)
                .foregroundStyle(theme.t2)
            }
            if let date = drive.lastScanCompletedAt {
                Text("Dernière analyse : \(Fmt.date(date))")
                    .font(.caption)
                    .foregroundStyle(theme.t3)
            }
        }
        .padding(.vertical, 4)
    }

    /// Suppression définitive confirmée : efface la fiche du disque et toutes
    /// ses données locales, puis rafraîchit la liste.
    private func forget(_ drive: DriveRecord) {
        Task {
            do {
                try await env.forgetDrive(drive)
                editedNames[drive.id] = nil
                await reload()
            } catch {
                actionError = error.localizedDescription
            }
        }
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
