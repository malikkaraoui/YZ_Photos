import Foundation

/// Journal de bord de l'app (mode développement).
/// - Chaque entrée est écrite **immédiatement dans un fichier** (`yzphotos.log`
///   dans Documents) → la trace survit même si l'app crashe juste après.
/// - Tampon mémoire pour l'affichage dans l'écran « Journal ».
/// - Capture les exceptions et signaux fatals (best-effort).
enum AppLog {
    private static let lock = NSLock()
    private static var buffer: [String] = []
    private static let maxBuffer = 3000

    static let fileURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("yzphotos.log")
    }()

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    /// Journalise une ligne (catégorie = petit préfixe visuel).
    /// NO-OP en build Release (App Store) : aucun journal, aucune écriture disque.
    static func log(_ message: String, _ category: String = "·") {
        #if DEBUG
        let line = "\(formatter.string(from: Date())) \(category) \(message)"
        lock.lock()
        buffer.append(line)
        if buffer.count > maxBuffer { buffer.removeFirst(buffer.count - maxBuffer) }
        lock.unlock()
        append(line + "\n")
        print("YZ \(line)")
        #endif
    }

    /// Journalise une erreur avec domaine + code (utile pour SMB / GRDB). NO-OP en Release.
    static func error(_ context: String, _ error: Error) {
        #if DEBUG
        let ns = error as NSError
        log("\(context) — \(error.localizedDescription) [\(ns.domain) · \(ns.code)]", "❌")
        #endif
    }

    /// Texte récent pour l'écran Journal (dernières lignes).
    static func recentText(limit: Int = 600) -> String {
        lock.lock(); defer { lock.unlock() }
        return buffer.suffix(limit).joined(separator: "\n")
    }

    static func clear() {
        lock.lock(); buffer.removeAll(); lock.unlock()
        try? Data().write(to: fileURL)
        log("Journal effacé", "🧹")
    }

    private static func append(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: fileURL)
        }
    }

    // MARK: - Capture des crashes

    /// À appeler une fois au démarrage. Démarre une nouvelle session de log et
    /// installe les capteurs d'exception / signaux.
    static func installCrashHandlers() {
        #if DEBUG
        // On CONSERVE le journal de la session précédente (essentiel pour lire la
        // trace après un crash/relancement) ; on ne tronque que s'il devient gros.
        if let size = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size]) as? Int,
           size > 2_000_000 {
            try? Data().write(to: fileURL)
        }
        let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"
        log("════ Démarrage YZPhotos v\(version) ════", "▶︎")

        NSSetUncaughtExceptionHandler { exception in
            AppLog.log("EXCEPTION: \(exception.name.rawValue) — \(exception.reason ?? "")", "💥")
            AppLog.log(exception.callStackSymbols.prefix(24).joined(separator: "\n"), "💥")
        }

        for sig in [SIGABRT, SIGSEGV, SIGILL, SIGTRAP, SIGBUS, SIGFPE] {
            signal(sig) { received in
                AppLog.log("SIGNAL fatal \(received)", "💥")
                AppLog.log(Thread.callStackSymbols.prefix(24).joined(separator: "\n"), "💥")
                signal(received, SIG_DFL)
                raise(received)
            }
        }
        #endif
    }
}
