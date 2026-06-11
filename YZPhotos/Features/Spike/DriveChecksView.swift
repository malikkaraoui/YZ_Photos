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
    @State private var checks: [CheckRow] = CheckRow.all
    @State private var running = false

    struct CheckRow: Identifiable {
        enum State {
            case pending
            case running
            case passed(String)
            case failed(String)
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
        ]
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pourquoi cet écran ?")
                            .font(.headline)
                        Text("Avant de laisser l'app déplacer de vraies photos, on vérifie que les opérations sensibles fonctionnent sur CE disque. Aucune photo n'est touchée : les tests utilisent des fichiers témoins, et le test des bibliothèques remet immédiatement le fichier à sa place.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button {
                            run()
                        } label: {
                            Label(running ? "Vérifications en cours…" : "Lancer les vérifications",
                                  systemImage: running ? "hourglass" : "play.fill")
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(running)
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 6)
                }

                Section("Les 7 vérifications") {
                    ForEach(checks) { check in
                        checkRow(check)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Test manuel : débranchage surprise", systemImage: "cable.connector.slash")
                            .font(.headline)
                        Text("Celui-là, c'est toi qui le fais : lance une analyse depuis l'onglet Stats, puis débranche le disque en plein milieu. L'app doit survivre sans planter et proposer « Brancher le disque » quand tu le rebranches.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Vérifications")
        }
    }

    @ViewBuilder
    private func checkRow(_ check: CheckRow) -> some View {
        HStack(alignment: .top, spacing: 12) {
            statusIcon(check.state)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(check.title)
                    .font(.headline)
                Text(check.explanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                switch check.state {
                case .passed(let detail):
                    Text("✅ \(detail)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.green)
                case .failed(let detail):
                    Text("❌ \(detail)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.red)
                case .running:
                    Text("En cours…")
                        .font(.subheadline.bold())
                        .foregroundStyle(.blue)
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
        }
    }

    // MARK: - Exécution (séquentielle, résultat affiché au fil de l'eau)

    private func run() {
        running = true
        for index in checks.indices { checks[index].state = .pending }
        let root = self.root
        let database = env.database
        let driveId = drive.id

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
#endif
