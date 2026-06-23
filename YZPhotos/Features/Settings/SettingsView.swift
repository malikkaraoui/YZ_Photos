import GRDB
import StoreKit
import SwiftUI

/// Onglet Réglages : apparence, vidéos, affichage par défaut, et les disques
/// connus — chaque disque garde ses statistiques en local, accrochées à son
/// identifiant unique (UUID du volume), même débranché.
struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.yzTheme) private var theme
    @Environment(\.requestReview) private var requestReview
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
                            .tint(theme.keep)
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
                                .tint(theme.keep)
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
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(YZButtonStyle(.secondary, size: .lg, fullWidth: true))
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Disques connus")
                } footer: {
                    Text("Chaque disque est reconnu par son identifiant unique : ses statistiques, son tri et sa corbeille restent enregistrés sur l'appareil même quand il est débranché. Tu peux brancher plusieurs disques à tour de rôle sans rien mélanger.")
                }

                Section {
                    Button {
                        requestReview()
                    } label: {
                        Label("Noter l'application", systemImage: "star.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(YZButtonStyle(.primary, size: .lg, fullWidth: true))
                    .listRowBackground(Color.clear)

                    if let url = URL(string: "mailto:karaoui.malik@gmail.com?subject=YZPhotos%20\(Self.appVersion.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
                        Link(destination: url) {
                            Label("Donner mon avis (e-mail)", systemImage: "envelope.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(YZButtonStyle(.secondary, size: .lg, fullWidth: true))
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    Text("Aide & avis")
                } footer: {
                    Text("« Noter » ouvre la fenêtre d'évaluation. « Donner mon avis » écrit à karaoui.malik@gmail.com.")
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

    private func driveRow(_ drive: DriveRecord) -> some View {
        let connected = env.driveAccess.connectedDrive?.id == drive.id
        let capacity = drive.totalBytes ?? 0
        let media = driveStats[drive.id]?.totalBytes ?? 0
        let fraction = capacity > 0 ? min(1, Double(media) / Double(capacity)) : 0
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "externaldrive.fill")
                    .foregroundStyle(connected ? theme.keep : theme.t2)
                TextField("Nom du disque", text: .init(
                    get: { editedNames[drive.id] ?? drive.name },
                    set: { editedNames[drive.id] = $0 }
                ), onCommit: { rename(drive) })
                    .font(.headline)
                    .textFieldStyle(.roundedBorder)
                if connected {
                    Text("Branché").font(.caption.bold()).foregroundStyle(theme.keep)
                }
            }

            // Jauge : part des photos/vidéos sur la capacité réelle du disque.
            VStack(alignment: .leading, spacing: 5) {
                YZProgressBar(value: fraction, tone: theme.accent, height: 9)
                HStack {
                    Text("\(Fmt.bytes(media)) de photos & vidéos")
                        .foregroundStyle(theme.t2)
                    Spacer()
                    if capacity > 0 {
                        Text("sur \(Fmt.bytes(capacity))").foregroundStyle(theme.t3)
                    }
                }
                .font(.footnote)
            }

            // Deux boutons ÉQUILIBRÉS (même style maison → pas de blanc en Verre).
            HStack(spacing: 10) {
                if connected {
                    driveButton("Éjecter", "eject.fill", .secondary) { ejectConnectedDrive() }
                } else {
                    driveButton("Brancher", "externaldrive.connected.to.line.below", .primary) { switchTo(drive) }
                }
                driveButton("Supprimer", "trash", .destructive) { driveToForget = drive }
            }
        }
        .padding(.vertical, 6)
    }

    private func driveButton(_ title: String, _ icon: String, _ variant: YZButtonStyle.Variant,
                             _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).lineLimit(1).frame(maxWidth: .infinity)
        }
        .buttonStyle(YZButtonStyle(variant, fullWidth: true))
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
