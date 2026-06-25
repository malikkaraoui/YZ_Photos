import AMSMB2
import ImageIO
import SwiftUI

#if DEBUG
/// Écran « Vérifications » : avant de faire confiance à l'app pour déplacer
/// de vraies photos, on teste les opérations sensibles sur le disque branché.
/// Aucune photo n'est touchée : chaque test utilise un petit fichier témoin
/// créé puis effacé, ou remet immédiatement les choses en place.
struct DriveChecksView: View {
    let drive: DriveRecord
    let root: URL

    @Environment(AppEnvironment.self) private var env
    @Environment(\.yzTheme) private var theme
    @State private var checks: [CheckRow] = CheckRow.all
    @State private var running = false

    struct CheckRow: Identifiable {
        enum State {
            case pending
            case running
            case passed(String)
            case failed(String)
            case skipped(String)   // non applicable (ex. test USB sur un disque réseau)
        }

        let id: Int
        let title: String
        /// Ce que le test fait, en français simple.
        let explanation: String
        var state: State = .pending

        static let all: [CheckRow] = [
            CheckRow(
                id: 1,
                title: "Mémorisation du disque",
                explanation: "Vérifie que l'app retrouvera ton disque toute seule au prochain lancement, sans te le redemander."
            ),
            CheckRow(
                id: 2,
                title: "Corbeille instantanée",
                explanation: "Crée un petit fichier témoin à la racine du disque, le met à la corbeille, le restaure, puis l'efface. Vérifie que le déplacement est instantané : rien n'est copié, rien ne peut se perdre."
            ),
            CheckRow(
                id: 3,
                title: "Bibliothèques Photos",
                explanation: "Prend UN fichier dans une bibliothèque Photos (.photoslibrary) du disque, le déplace vers la corbeille, et le remet exactement à sa place. C'est le point le plus délicat : si ça marche, le tri dans tes bibliothèques est fiable."
            ),
            CheckRow(
                id: 4,
                title: "Vitesse : listage des fichiers",
                explanation: "Mesure à quelle vitesse l'app peut lister les fichiers du disque (étape 1 de l'analyse). Sert à estimer la durée."
            ),
            CheckRow(
                id: 5,
                title: "Vitesse : empreintes",
                explanation: "Mesure la vitesse de calcul des empreintes qui servent à détecter les doublons (lecture de 128 Ko par fichier seulement)."
            ),
            CheckRow(
                id: 6,
                title: "Vitesse : miniatures",
                explanation: "Mesure la vitesse de création des vignettes affichées dans les grilles et le deck de tri."
            ),
            CheckRow(
                id: 7,
                title: "Noms de fichiers français",
                explanation: "Crée un fichier témoin avec accents et emoji (« Capture d'écran 🎉 tëst café.png »), lui fait faire l'aller-retour corbeille, puis l'efface. Vérifie que les noms français ne posent aucun problème sur ce disque."
            ),
            CheckRow(
                id: 8,
                title: "Diagnostic réseau (listage brut)",
                explanation: "Liste BRUTE de la racine du disque (sans filtre média ni taille) pour comprendre l'accès. Sert surtout aux partages réseau SMB : indique combien d'éléments sont vus, combien de dossiers, si les tailles sont lisibles, et l'erreur exacte en cas d'échec."
            ),
        ]
    }

    var body: some View {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pourquoi cet écran ?")
                            .font(YZFont.headline)
                            .foregroundStyle(theme.t1)
                        Text("Avant de laisser l'app déplacer de vraies photos, on vérifie que les opérations sensibles fonctionnent sur CE disque. Aucune photo n'est touchée : les tests utilisent des fichiers témoins, et le test des bibliothèques remet immédiatement le fichier à sa place.")
                            .font(YZFont.subhead)
                            .foregroundStyle(theme.t2)
                        Button {
                            run()
                        } label: {
                            Label(running ? "Vérifications en cours…" : "Lancer les vérifications",
                                  systemImage: running ? "hourglass" : "play.fill")
                        }
                        .buttonStyle(YZButtonStyle(.primary, size: .lg))
                        .disabled(running || env.scan.isRunning)
                        .padding(.top, 4)
                        if env.scan.isRunning {
                            Label("Indisponible pendant une analyse — les vérifications et l'analyse utilisent le disque en même temps. Attends la fin de l'analyse (ou arrête-la depuis « Analyse »).",
                                  systemImage: "exclamationmark.triangle.fill")
                                .font(YZFont.subhead)
                                .foregroundStyle(theme.warn)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(theme.isGlass ? AnyView(Rectangle().fill(.ultraThinMaterial)) : AnyView(theme.card))

                Section("Les 7 vérifications") {
                    ForEach(checks) { check in
                        checkRow(check)
                    }
                }
                .listRowBackground(theme.isGlass ? AnyView(Rectangle().fill(.ultraThinMaterial)) : AnyView(theme.card))

                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Test manuel : débranchage surprise", systemImage: "cable.connector.slash")
                            .font(YZFont.headline)
                            .foregroundStyle(theme.t1)
                        Text("Celui-là, c'est toi qui le fais : lance une analyse depuis l'onglet Stats, puis débranche le disque en plein milieu. L'app doit survivre sans planter et proposer « Brancher le disque » quand tu le rebranches.")
                            .font(YZFont.subhead)
                            .foregroundStyle(theme.t2)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(theme.isGlass ? AnyView(Rectangle().fill(.ultraThinMaterial)) : AnyView(theme.card))

                Section("Spike — client SMB natif") {
                    SMBSpikeSection()
                }
                .listRowBackground(theme.isGlass ? AnyView(Rectangle().fill(.ultraThinMaterial)) : AnyView(theme.card))

                Section("Journal de l'app (dev)") {
                    AppLogSection()
                }
                .listRowBackground(theme.isGlass ? AnyView(Rectangle().fill(.ultraThinMaterial)) : AnyView(theme.card))
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder
    private func checkRow(_ check: CheckRow) -> some View {
        HStack(alignment: .top, spacing: 12) {
            statusIcon(check.state)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(check.title)
                    .font(YZFont.headline)
                    .foregroundStyle(theme.t1)
                Text(check.explanation)
                    .font(YZFont.subhead)
                    .foregroundStyle(theme.t2)
                switch check.state {
                case .passed(let detail):
                    Text("✅ \(detail)")
                        .font(YZFont.subheadSemi)
                        .foregroundStyle(theme.keep)
                case .failed(let detail):
                    Text("❌ \(detail)")
                        .font(YZFont.subheadSemi)
                        .foregroundStyle(theme.trash)
                case .running:
                    Text("En cours…")
                        .font(YZFont.subheadSemi)
                        .foregroundStyle(theme.accent)
                case .skipped(let detail):
                    Text(detail)
                        .font(YZFont.subheadSemi)
                        .foregroundStyle(theme.t3)
                case .pending:
                    EmptyView()
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func statusIcon(_ state: CheckRow.State) -> some View {
        switch state {
        case .pending:
            Image(systemName: "circle.dashed")
                .font(.title3)
                .foregroundStyle(.tertiary)
        case .running:
            ProgressView()
                .controlSize(.small)
        case .passed:
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.red)
        case .skipped:
            Image(systemName: "minus.circle")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Exécution (séquentielle, résultat affiché au fil de l'eau)

    private func run() {
        running = true
        for index in checks.indices { checks[index].state = .pending }
        let root = self.root
        let database = env.database
        let driveId = drive.id

        // Disque réseau (URL non-fichier) : les vérifs USB ne s'appliquent pas.
        // On les marque « non applicable » et on renvoie vers le test SMB du bas.
        if !root.isFileURL {
            for index in checks.indices {
                checks[index].state = .skipped("Non applicable à un disque réseau — utilise « Tester la connexion SMB » plus bas.")
            }
            running = false
            return
        }

        Task {
            for index in checks.indices {
                checks[index].state = .running
                let id = checks[index].id
                let result = await Task.detached(priority: .userInitiated) { () -> CheckRow.State in
                    switch id {
                    case 1: Self.checkBookmark(database: database, driveId: driveId)
                    case 2: Self.checkTrashRoundTrip(root: root)
                    case 3: await Self.checkPhotosLibraryMove(root: root)
                    case 4: await Self.checkEnumerationSpeed(root: root)
                    case 5: await Self.checkHashSpeed(root: root)
                    case 6: await Self.checkThumbnailSpeed(root: root)
                    case 7: Self.checkFrenchFilenames(root: root)
                    case 8: Self.checkRawListing(root: root)
                    default: .failed("Test inconnu")
                    }
                }.value
                checks[index].state = result
            }
            running = false
        }
    }

    // 1 — L'app retrouve le disque via le « marque-page » enregistré en base.
    private static func checkBookmark(database: AppDatabase, driveId: String) -> CheckRow.State {
        do {
            guard let record = try database.writer.read({ db in
                try DriveRecord.fetchOne(db, key: driveId)
            }) else {
                return .failed("Le disque n'est pas enregistré en base.")
            }
            var stale = false
            let url = try URL(resolvingBookmarkData: record.bookmarkData, bookmarkDataIsStale: &stale)
            let ok = url.startAccessingSecurityScopedResource()
            defer { if ok { url.stopAccessingSecurityScopedResource() } }
            let reachable = (try? url.checkResourceIsReachable()) == true
            return ok && reachable
                ? .passed("Le disque sera retrouvé automatiquement au prochain lancement.")
                : .failed("L'accès mémorisé ne fonctionne plus — il faudra rechoisir le disque.")
        } catch {
            return .failed("Impossible de retrouver le disque : \(error.localizedDescription)")
        }
    }

    // 2 — Aller-retour corbeille d'un fichier témoin, chronométré.
    private static func checkTrashRoundTrip(root: URL) -> CheckRow.State {
        let fm = FileManager.default
        let testFile = root.appendingPathComponent("yzphotos_test_temoin.txt")
        let trashDir = TrashManager.trashDirURL(driveRoot: root)
        let inTrash = trashDir.appendingPathComponent("test_temoin.txt")
        do {
            try Data("témoin".utf8).write(to: testFile)
            try fm.createDirectory(at: trashDir, withIntermediateDirectories: true)
            let start = Date()
            try fm.moveItem(at: testFile, to: inTrash)
            let moveMs = Date().timeIntervalSince(start) * 1000
            try fm.moveItem(at: inTrash, to: testFile)
            try fm.removeItem(at: testFile)
            return moveMs < 100
                ? .passed(String(format: "Déplacement en %.1f ms — instantané, aucune copie.", moveMs))
                : .failed(String(format: "Déplacement lent (%.0f ms) — le disque copie au lieu de renommer ?", moveMs))
        } catch {
            try? fm.removeItem(at: testFile)
            try? fm.removeItem(at: inTrash)
            return .failed("Erreur pendant le test : \(error.localizedDescription)")
        }
    }

    // 3 — Sortir un fichier d'un .photoslibrary et le remettre.
    // async sans aucun blocage de thread (un wait ici gelait toute l'app).
    private static func checkPhotosLibraryMove(root: URL) async -> CheckRow.State {
        let fm = FileManager.default
        var sample: URL?
        do {
            for try await meta in FileEnumerator.enumerate(root: root)
            where meta.sourceType == .photosLibrary {
                sample = root.appending(path: meta.relativePath)
                break
            }
        } catch {
            return .failed("Impossible de parcourir le disque : \(error.localizedDescription)")
        }
        guard let file = sample else {
            return .passed("Aucune bibliothèque Photos sur ce disque — test sans objet.")
        }
        let trashDir = TrashManager.trashDirURL(driveRoot: root)
        let inTrash = trashDir.appendingPathComponent("test_\(file.lastPathComponent)")
        do {
            try fm.createDirectory(at: trashDir, withIntermediateDirectories: true)
            let start = Date()
            try fm.moveItem(at: file, to: inTrash)
            let ms = Date().timeIntervalSince(start) * 1000
            try fm.moveItem(at: inTrash, to: file)
            return .passed(String(format: "Fichier sorti puis remis en place en %.1f ms (%@). Le tri dans les bibliothèques est fiable.", ms, file.lastPathComponent))
        } catch {
            try? fm.moveItem(at: inTrash, to: file)
            return .failed("Le disque refuse de sortir des fichiers d'une bibliothèque Photos. Dis-le-moi : il faudra passer en copie+suppression. (\(error.localizedDescription))")
        }
    }

    // 4 — Vitesse de listage (jusqu'à 10 000 fichiers).
    private static func checkEnumerationSpeed(root: URL) async -> CheckRow.State {
        var count = 0
        let start = Date()
        do {
            for try await _ in FileEnumerator.enumerate(root: root) {
                count += 1
                if count >= 10_000 { break }
            }
        } catch {}
        let seconds = Date().timeIntervalSince(start)
        let rate = seconds > 0 ? Double(count) / seconds : 0
        return rate > 200
            ? .passed(String(format: "%d fichiers listés en %.1f s → %.0f fichiers/seconde.", count, seconds, rate))
            : .failed(String(format: "Lent : %.0f fichiers/seconde. L'étape 1 de l'analyse sera longue.", rate))
    }

    // 5 — Vitesse des empreintes (200 fichiers).
    private static func checkHashSpeed(root: URL) async -> CheckRow.State {
        var urls: [URL] = []
        do {
            for try await meta in FileEnumerator.enumerate(root: root) {
                urls.append(root.appending(path: meta.relativePath))
                if urls.count >= 200 { break }
            }
        } catch {}
        guard !urls.isEmpty else { return .failed("Aucun fichier média trouvé sur le disque.") }
        let start = Date()
        var hashed = 0
        for url in urls {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            if size > 0, (try? HashWorker.partialHash(url: url, sizeBytes: size)) != nil {
                hashed += 1
            }
        }
        let seconds = Date().timeIntervalSince(start)
        let rate = seconds > 0 ? Double(hashed) / seconds : 0
        return rate > 20
            ? .passed(String(format: "%d empreintes en %.1f s → %.0f/seconde (et l'analyse réelle travaille sur 8 fichiers à la fois).", hashed, seconds, rate))
            : .failed(String(format: "Lent : %.0f empreintes/seconde.", rate))
    }

    // 6 — Vitesse des miniatures (100 photos).
    private static func checkThumbnailSpeed(root: URL) async -> CheckRow.State {
        var urls: [URL] = []
        do {
            for try await meta in FileEnumerator.enumerate(root: root) where meta.kind == .photo {
                urls.append(root.appending(path: meta.relativePath))
                if urls.count >= 100 { break }
            }
        } catch {}
        guard !urls.isEmpty else { return .failed("Aucune photo trouvée sur le disque.") }
        let start = Date()
        var done = 0
        for url in urls {
            let options = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 512,
            ] as [CFString: Any] as CFDictionary
            if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
               CGImageSourceCreateThumbnailAtIndex(source, 0, options) != nil {
                done += 1
            }
        }
        let seconds = Date().timeIntervalSince(start)
        let rate = seconds > 0 ? Double(done) / seconds : 0
        return rate > 5
            ? .passed(String(format: "%d vignettes en %.1f s → %.0f/seconde.", done, seconds, rate))
            : .failed(String(format: "Lent : %.0f vignettes/seconde.", rate))
    }

    // 8 — Listage brut de la racine (diagnostic réseau SMB / File Provider).
    // Tout est mis dans le message affiché, pour me le recopier tel quel.
    private static func checkRawListing(root: URL) -> CheckRow.State {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .nameKey]
        let reachable = (try? root.checkResourceIsReachable()) == true
        let coordinator = NSFileCoordinator()
        var coordErr: NSError?
        var items: [URL] = []
        var readErr: NSError?
        coordinator.coordinate(readingItemAt: root, options: [], error: &coordErr) { url in
            do {
                items = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: [])
            } catch let e as NSError {
                readErr = e
            }
        }
        if let e = coordErr ?? readErr {
            return .failed("joignable=\(reachable). Listage KO → \(e.domain) code \(e.code) : \(e.localizedDescription)")
        }
        let dirs = items.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }.count
        let withSize = items.filter { (((try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) ?? 0) > 0 }.count
        let firstNames = items.prefix(6).map { $0.lastPathComponent }.joined(separator: " · ")
        if items.isEmpty {
            return .failed("joignable=\(reachable). 0 élément listé à la racine (le partage réseau ne renvoie pas son contenu via FileManager).")
        }
        return .passed("joignable=\(reachable). \(items.count) éléments, \(dirs) dossiers, \(withSize) avec taille>0. Premiers : \(firstNames)")
    }

    // 7 — Accents français et emoji dans les noms de fichiers.
    private static func checkFrenchFilenames(root: URL) -> CheckRow.State {
        let fm = FileManager.default
        let name = "Capture d'écran 🎉 tëst café.png"
        let testFile = root.appendingPathComponent(name)
        let trashDir = TrashManager.trashDirURL(driveRoot: root)
        let inTrash = trashDir.appendingPathComponent("test_\(name)")
        do {
            try Data([0x89, 0x50, 0x4E, 0x47]).write(to: testFile)
            try fm.createDirectory(at: trashDir, withIntermediateDirectories: true)
            try fm.moveItem(at: testFile, to: inTrash)
            try fm.moveItem(at: inTrash, to: testFile)
            let nfc = FileEnumerator.relativePath(of: testFile, from: root)
            let roundTrip = fm.fileExists(atPath: root.appending(path: nfc).path)
            try fm.removeItem(at: testFile)
            return roundTrip
                ? .passed("Accents et emoji : aucun problème sur ce disque.")
                : .failed("Les chemins avec accents sont instables sur ce disque — dis-le-moi.")
        } catch {
            try? fm.removeItem(at: testFile)
            try? fm.removeItem(at: inTrash)
            return .failed("Erreur pendant le test : \(error.localizedDescription)")
        }
    }
}

/// Spike : connexion SMB **directe** (client natif AMSMB2), sans passer par
/// l'app Fichiers. Prouve l'accès réseau de bout en bout avant tout refactor :
/// connexion → listage racine → lecture d'un fichier → miniature.
/// Affiche le journal de l'app (dernières lignes) + export du fichier complet.
private struct AppLogSection: View {
    @Environment(\.yzTheme) private var theme
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trace en direct (écrite dans un fichier qui survit aux crashes). Au prochain crash, exporte ce journal et envoie-le.")
                .font(YZFont.subhead).foregroundStyle(theme.t2)
            HStack(spacing: 16) {
                Button { text = AppLog.recentText() } label: { Label("Rafraîchir", systemImage: "arrow.clockwise") }
                    .font(YZFont.subheadSemi).foregroundStyle(theme.accent)
                ShareLink(item: AppLog.fileURL) { Label("Exporter", systemImage: "square.and.arrow.up") }
                    .font(YZFont.subheadSemi)
                Spacer()
                Button { AppLog.clear(); text = AppLog.recentText() } label: { Label("Effacer", systemImage: "trash") }
                    .font(YZFont.subheadSemi).foregroundStyle(theme.trash)
            }
            ScrollView {
                Text(text.isEmpty ? "(journal vide — agis dans l'app puis rafraîchis)" : text)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(theme.t1)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 360)
        }
        .padding(.vertical, 4)
        .onAppear { text = AppLog.recentText() }
    }
}

private struct SMBSpikeSection: View {
    @Environment(\.yzTheme) private var theme
    @Environment(AppEnvironment.self) private var env
    @State private var host = "192.168.0.83"
    @State private var share = "T7"
    @State private var user = ""
    @State private var password = ""
    @State private var result = ""
    @State private var running = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Connexion SMB directe — sans Fichiers. Saisis tes identifiants Freebox/NAS.")
                .font(YZFont.subhead)
                .foregroundStyle(theme.t2)
            TextField("Hôte (ex. 192.168.0.83)", text: $host)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .textFieldStyle(.roundedBorder).focused($fieldFocused)
            TextField("Partage (ex. T7)", text: $share)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .textFieldStyle(.roundedBorder).focused($fieldFocused)
            TextField("Utilisateur", text: $user)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .textFieldStyle(.roundedBorder).focused($fieldFocused)
            SecureField("Mot de passe", text: $password)
                .textFieldStyle(.roundedBorder).focused($fieldFocused)
                .submitLabel(.done)
                .onSubmit { fieldFocused = false }
            Button {
                fieldFocused = false
                test()
            } label: {
                Label(running ? "Connexion en cours…" : "Tester la connexion SMB",
                      systemImage: running ? "hourglass" : "network")
            }
            .buttonStyle(YZButtonStyle(.primary, size: .lg))
            .disabled(running || host.isEmpty || share.isEmpty || env.scan.isRunning)
            if env.scan.isRunning {
                Text("Indisponible pendant une analyse (le disque est déjà sollicité).")
                    .font(YZFont.subhead)
                    .foregroundStyle(theme.warn)
            }
            if !result.isEmpty {
                Text(result)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(theme.t1)
                    .textSelection(.enabled)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Terminé") { fieldFocused = false }
            }
        }
    }

    private func test() {
        running = true
        result = "Connexion à smb://\(host) / \(share)…"
        let host = self.host, share = self.share, user = self.user, password = self.password
        Task {
            let report = await Self.run(host: host, share: share, user: user, password: password)
            await MainActor.run {
                result = report
                running = false
            }
        }
    }

    private static func run(host: String, share: String, user: String, password: String) async -> String {
        guard let serverURL = URL(string: "smb://\(host)") else { return "❌ URL invalide." }
        let credential = URLCredential(user: user, password: password, persistence: .forSession)
        guard let client = SMB2Manager(url: serverURL, credential: credential) else {
            return "❌ Initialisation du client SMB impossible."
        }
        do {
            func isImage(_ e: [URLResourceKey: Any]) -> Bool {
                let isDir = (e[.fileResourceTypeKey] as? URLFileResourceType) == .directory
                let name = (e[.nameKey] as? String ?? "")
                // Ignore les fichiers AppleDouble/cachés (« ._photo.png », 4 Ko de
                // métadonnées macOS) : ce ne sont PAS de vraies images → ils
                // donnaient un faux « Miniature KO ». Le vrai scan les skippe aussi.
                guard !name.hasPrefix(".") else { return false }
                return !isDir && FileEnumerator.photoExtensions.contains((name as NSString).pathExtension.lowercased())
            }

            var lines: [String] = []
            // 1) Partages disponibles sur le serveur (pour repérer le vrai nom du disque T7).
            do {
                let shares = try await client.listShares()
                lines.append("Partages : " + shares.map(\.name).joined(separator: ", "))
            } catch {
                lines.append("Partages : (listage KO — \(error.localizedDescription))")
            }

            // 2) Connexion au partage demandé + exploration sur 1 niveau.
            try await client.connectShare(name: share)
            let entries = try await client.contentsOfDirectory(atPath: "/")
            let dirs = entries.filter { ($0[.fileResourceTypeKey] as? URLFileResourceType) == .directory }
            lines.append("✅ « \(share) » : \(entries.count) éléments (\(dirs.count) dossiers).")
            lines.append("→ " + entries.prefix(10).compactMap { $0[.nameKey] as? String }.joined(separator: ", "))
            for dir in dirs.prefix(5) {
                guard let dname = dir[.nameKey] as? String else { continue }
                let sub = (try? await client.contentsOfDirectory(atPath: "/\(dname)")) ?? []
                let subNames = sub.prefix(6).compactMap { $0[.nameKey] as? String }
                lines.append("  \(dname)/ : \(sub.count) — " + subNames.joined(separator: ", "))
            }

            // 3) Première image (racine ou 1 niveau) → lecture + miniature.
            var imagePath: String?
            if let img = entries.first(where: isImage), let n = img[.nameKey] as? String {
                imagePath = "/\(n)"
            } else {
                for dir in dirs.prefix(5) {
                    guard let dname = dir[.nameKey] as? String else { continue }
                    let sub = (try? await client.contentsOfDirectory(atPath: "/\(dname)")) ?? []
                    if let img = sub.first(where: isImage), let n = img[.nameKey] as? String {
                        imagePath = "/\(dname)/\(n)"
                        break
                    }
                }
            }
            if let imagePath {
                let data = try await client.contents(atPath: imagePath)
                lines.append("Lu « \(imagePath) » : \(data.count) octets.")
                let opts = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: 256,
                ] as CFDictionary
                if let src = CGImageSourceCreateWithData(data as CFData, nil),
                   let thumb = CGImageSourceCreateThumbnailAtIndex(src, 0, opts) {
                    lines.append("✅ Miniature OK : \(thumb.width)×\(thumb.height).")
                } else {
                    lines.append("⚠️ Miniature KO.")
                }
            } else {
                lines.append("Aucune image (racine + 1 niveau).")
            }

            // Test d'écriture (fichier témoin, JAMAIS une de tes photos). On teste
            // SÉPARÉMENT création de dossier, écriture, DÉPLACEMENT et SUPPRESSION —
            // chacun avec son code — pour savoir précisément ce que le serveur
            // autorise (clé du « lecture seule ? »).
            func codeName(_ e: Error) -> String {
                switch (e as NSError).code {
                case 1:  return "1 EPERM (interdit)"
                case 13: return "13 EACCES (accès refusé)"
                case 17: return "17 EEXIST (existe déjà)"
                case 20: return "20 ENOTDIR"
                case 21: return "21 EISDIR"
                case 22: return "22 EINVAL"
                case 30: return "30 EROFS (lecture seule !)"
                case 39: return "39 ENOTEMPTY"
                default: return "\((e as NSError).code)"
                }
            }
            let testPath = "/yz_smb_temoin.txt"
            let trashDir = "/.YZTrash"
            let trashPath = "\(trashDir)/yz_smb_temoin.txt"

            // 1) Création du dossier .YZTrash.
            do { try await client.createDirectory(atPath: trashDir); lines.append("• Créer .YZTrash : ✅") }
            catch { let c = (error as NSError).code
                lines.append(c == 17 ? "• Créer .YZTrash : ✅ (déjà présent)" : "• Créer .YZTrash : ❌ \(codeName(error))") }

            // 2) S'assurer qu'un témoin existe (EEXIST = déjà là = OK pour la suite).
            var temoin = false
            do { try await client.write(data: Data("témoin".utf8), toPath: testPath, progress: nil); temoin = true; lines.append("• Écriture : ✅") }
            catch { let c = (error as NSError).code
                if c == 17 { temoin = true; lines.append("• Écriture : témoin déjà présent (OK)") }
                else { lines.append("• Écriture : ❌ \(codeName(error))") } }

            // 3) DÉPLACEMENT = opération exacte de la corbeille. LE test clé.
            if temoin {
                do {
                    try await client.moveItem(atPath: testPath, toPath: trashPath)
                    lines.append("• Déplacement (corbeille) : ✅  ← LA corbeille marche")
                    try? await client.moveItem(atPath: trashPath, toPath: testPath) // on remet
                } catch {
                    lines.append("• Déplacement (corbeille) : ❌ \(codeName(error))  ← LA corbeille bloque ici")
                }
                // 4) SUPPRESSION (= vider la corbeille).
                do { try await client.removeFile(atPath: testPath); lines.append("• Suppression : ✅") }
                catch { lines.append("• Suppression : ❌ \(codeName(error))") }
                try? await client.removeFile(atPath: trashPath)
            } else {
                lines.append("• Déplacement/suppression non testés (écriture refusée → probable lecture seule).")
            }

            try? await client.disconnectShare()
            return lines.joined(separator: "\n")
        } catch {
            return "❌ Échec : \(error.localizedDescription)\n\n\(String(describing: error))"
        }
    }
}
#endif
