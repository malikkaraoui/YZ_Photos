import GRDB
import StoreKit
import SwiftUI

/// Onglet Réglages : apparence, vidéos, affichage par défaut, et les disques
/// connus — chaque disque garde ses statistiques en local, accrochées à son
/// identifiant unique (UUID du volume), même débranché.
struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(LocalizationManager.self) private var localization
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
                        Picker("Langue", selection: Binding(
                            get: { localization.language },
                            set: { localization.set($0) }
                        )) {
                            ForEach(AppLanguage.allCases) { lang in
                                Text("\(lang.flag) \(lang.nativeName)").tag(lang)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 360)
                        Spacer(minLength: 0)
                    }
                } header: {
                    Text("Langue")
                } footer: {
                    Text("Change la langue de l'app immédiatement, sans la redémarrer.")
                }

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

                // Disque BRANCHÉ : carte teintée bien distincte, placée TOUT EN HAUT.
                if let connectedDrive = knownDrives.first(where: { env.driveAccess.connectedDrive?.id == $0.id }) {
                    Section {
                        connectedDriveCard(connectedDrive)
                            .listRowBackground(Color.clear)
                    } header: {
                        Text("Disque branché")
                    }
                }

                // Les AUTRES disques : lignes compactes (peu de hauteur).
                Section {
                    ForEach(otherDrives) { drive in
                        compactDriveRow(drive)
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
                    Text(otherDrives.isEmpty ? "Disques connus" : "Autres disques")
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

    /// Tous les disques connus SAUF celui qui est branché (qui a sa propre carte).
    private var otherDrives: [DriveRecord] {
        knownDrives.filter { env.driveAccess.connectedDrive?.id != $0.id }
    }

    private func nameBinding(_ drive: DriveRecord) -> Binding<String> {
        .init(get: { editedNames[drive.id] ?? drive.name },
              set: { editedNames[drive.id] = $0 })
    }

    /// Disque branché : carte TEINTÉE (vert « gardé ») bien distincte, jauge,
    /// éjecter + supprimer. Volontairement plus visuelle que les autres.
    private func connectedDriveCard(_ drive: DriveRecord) -> some View {
        let capacity = drive.totalBytes ?? 0
        let media = driveStats[drive.id]?.totalBytes ?? 0
        let fraction = capacity > 0 ? min(1, Double(media) / Double(capacity)) : 0
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "externaldrive.fill.badge.checkmark")
                    .font(.title2)
                    .foregroundStyle(theme.keep)
                TextField("Nom du disque", text: nameBinding(drive), onCommit: { rename(drive) })
                    .font(.headline)
                    .textFieldStyle(.roundedBorder)
                YZBadge("BRANCHÉ", systemImage: "bolt.fill", tone: .keep)
            }
            VStack(alignment: .leading, spacing: 5) {
                YZProgressBar(value: fraction, tone: theme.keep, height: 10)
                HStack {
                    Text("\(Fmt.bytes(media)) de photos & vidéos").foregroundStyle(theme.t2)
                    Spacer()
                    if capacity > 0 { Text("sur \(Fmt.bytes(capacity))").foregroundStyle(theme.t3) }
                }
                .font(.footnote)
            }
            HStack(spacing: 10) {
                driveButton("Éjecter", "eject.fill", .secondary) { ejectConnectedDrive() }
                driveButton("Supprimer", "trash", .destructive) { driveToForget = drive }
            }
        }
        .padding(16)
        .background {
            let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
            shape.fill(theme.keepSoft)
            shape.strokeBorder(theme.keep.opacity(0.55), lineWidth: 1.5)
        }
    }

    /// Disque NON branché : ligne compacte (nom + capacité sur 2 lignes, boutons
    /// dimensionnés au contenu) → beaucoup moins étalé qu'avant.
    private func compactDriveRow(_ drive: DriveRecord) -> some View {
        let capacity = drive.totalBytes ?? 0
        let media = driveStats[drive.id]?.totalBytes ?? 0
        return HStack(spacing: 12) {
            Image(systemName: "externaldrive").foregroundStyle(theme.t3)
            VStack(alignment: .leading, spacing: 2) {
                TextField("Nom du disque", text: nameBinding(drive), onCommit: { rename(drive) })
                    .font(.subheadline.weight(.semibold))
                Text("\(Fmt.bytes(media))" + (capacity > 0 ? " · sur \(Fmt.bytes(capacity))" : ""))
                    .font(.caption)
                    .foregroundStyle(theme.t3)
            }
            Spacer(minLength: 8)
            Button { switchTo(drive) } label: {
                Label("Brancher", systemImage: "externaldrive.connected.to.line.below")
            }
            .buttonStyle(YZButtonStyle(.primary))
            Button { driveToForget = drive } label: {
                Image(systemName: "trash").frame(minWidth: 20)
            }
            .buttonStyle(YZButtonStyle(.secondary))
            .accessibilityLabel("Supprimer")
        }
        .padding(.vertical, 4)
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
