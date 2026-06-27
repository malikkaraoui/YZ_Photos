import SwiftUI

/// Écran « Disque réseau » : connexion SMB directe (client natif), puis choix
/// du partage et navigation dans les dossiers — sans passer par le sélecteur
/// de fichiers d'iOS. À la fin, le dossier choisi devient un disque de l'app.
struct SMBBrowserView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.yzTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    enum Step { case login, shares, browse }

    @State private var step: Step = .login
    @State private var host = "192.168.0.83"
    @State private var user = ""
    @State private var password = ""

    @State private var shares: [String] = []
    @State private var browseStore: SMBStore?
    @State private var currentShare = ""
    @State private var path = "/"
    @State private var entries: [SMBStore.Entry] = []
    @State private var capacity: (total: Int64, free: Int64)?

    @State private var loading = false
    @State private var error: String?
    @FocusState private var keyboardUp: Bool

    var body: some View {
        NavigationStack {
            content
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .yzScreenBackground(theme)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annuler") { dismiss() }.foregroundStyle(theme.t2)
                    }
                    if step == .browse {
                        ToolbarItem(placement: .primaryAction) {
                            Button(path == "/" ? "Choisir tout" : "Choisir ici") { choose() }
                                .disabled(loading)
                                .foregroundStyle(theme.isGlass ? .white : theme.accent)
                                .fontWeight(.semibold)
                        }
                    }
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Terminé") { keyboardUp = false }
                    }
                }
                .tint(theme.accent)
                .onAppear(perform: prefillFromSaved)
        }
    }

    /// Pré-remplit avec la dernière connexion mémorisée (mot de passe au trousseau).
    private func prefillFromSaved() {
        guard host == "192.168.0.83", user.isEmpty else { return }  // ne pas écraser une saisie en cours
        if !env.settings.lastSMBHost.isEmpty { host = env.settings.lastSMBHost }
        if !env.settings.lastSMBUser.isEmpty { user = env.settings.lastSMBUser }
        if let pw = env.settings.lastSMBPassword { password = pw }
    }

    private var title: String {
        switch step {
        case .login: "Disque réseau"
        case .shares: host
        case .browse: currentShare + path
        }
    }

    @ViewBuilder private var content: some View {
        switch step {
        case .login: loginForm
        case .shares: sharesList
        case .browse: browser
        }
        if loading { ProgressView().tint(theme.t2).padding(.top, 12) }
        if let error {
            Text(error)
                .font(YZFont.subhead)
                .foregroundStyle(theme.trash)
                .padding(.top, 10)
        }
    }

    // MARK: Étapes

    private var loginForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connecte-toi à ton serveur (Freebox, NAS…). Le mot de passe est conservé en sécurité dans le trousseau de l'appareil.")
                .font(YZFont.subhead).foregroundStyle(theme.t2)
            field("Adresse du serveur (ex. 192.168.0.83)", text: $host).focused($keyboardUp)
            field("Utilisateur", text: $user).focused($keyboardUp)
            secureField("Mot de passe", text: $password).focused($keyboardUp)
                .submitLabel(.go).onSubmit { connect() }
            Button { connect() } label: {
                Label("Se connecter", systemImage: "network")
            }
            .buttonStyle(YZButtonStyle(.primary, size: .lg, fullWidth: true))
            .disabled(loading)   // toujours actif : on affiche un message clair si un champ manque
            .padding(.top, 4)
        }
    }

    private var sharesList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Partages disponibles").font(YZFont.subheadSemi).foregroundStyle(theme.t3)
            ForEach(shares, id: \.self) { share in
                Button { openShare(share) } label: {
                    row(icon: "externaldrive.connected.to.line.below", title: share, chevron: true)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var browser: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if path != "/" {
                    Button { goUp() } label: { Label("Retour", systemImage: "chevron.left") }
                        .font(YZFont.subheadSemi).foregroundStyle(theme.accent)
                }
                Spacer()
                Text(path).font(YZFont.footnote).foregroundStyle(theme.t3).lineLimit(1)
            }
            if path == "/" {
                // Capacité réelle du partage (libre / occupé) — affichée dès qu'on
                // entre dans le disque, sans bloquer la navigation (chargée à part).
                if let capacity { capacityCard(capacity) }
                // Choisir le partage ENTIER comme un dossier (en un tap).
                Button { choose() } label: {
                    Label("Scanner tout le disque « \(currentShare) »", systemImage: "externaldrive.fill")
                }
                .buttonStyle(YZButtonStyle(.primary, fullWidth: true))
                .disabled(loading)
                Text("Ou descends dans un dossier pour n'en scanner qu'une partie.")
                    .font(YZFont.footnote).foregroundStyle(theme.t3)
            }
            let content = folderContent
            ScrollView {
                LazyVStack(spacing: 6) {
                    // On n'affiche QUE les dossiers (un sélecteur de dossier) : lister
                    // les dizaines de milliers de fichiers d'un dossier figeait l'app.
                    ForEach(content.dirs, id: \.name) { entry in
                        Button { openFolder(entry.name) } label: {
                            row(icon: "folder.fill", title: entry.name, chevron: true)
                        }.buttonStyle(.plain)
                    }
                    // Carte « contenu » : un dossier plein de photos sans sous-dossier
                    // ne doit PAS avoir l'air vide → on affiche le compte en grand.
                    if content.photos + content.videos > 0 {
                        mediaContentCard(photos: content.photos, videos: content.videos)
                            .padding(.top, content.dirs.isEmpty ? 24 : 12)
                    } else if content.dirs.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "tray").font(.system(size: 34)).foregroundStyle(theme.t3)
                            Text(content.others > 0 ? "Aucune photo ni vidéo ici." : "Dossier vide.")
                                .font(YZFont.subhead).foregroundStyle(theme.t3)
                        }
                        .frame(maxWidth: .infinity).padding(.top, 30)
                    }
                }
            }
            Text("Astuce : descends jusqu'au dossier qui contient tes photos (ou choisis la racine du partage), puis « Choisir ici ».")
                .font(YZFont.footnote).foregroundStyle(theme.t3)
        }
    }

    /// Contenu du dossier en UNE seule passe : dossiers triés + comptes médias.
    private var folderContent: (dirs: [SMBStore.Entry], photos: Int, videos: Int, others: Int) {
        var dirs: [SMBStore.Entry] = []
        var photos = 0, videos = 0, others = 0
        for e in entries {
            if e.isDirectory { dirs.append(e); continue }
            switch FileEnumerator.mediaKind(forExtension: (e.name as NSString).pathExtension) {
            case .photo: photos += 1
            case .video: videos += 1
            default: others += 1
            }
        }
        dirs.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return (dirs, photos, videos, others)
    }

    /// « 1 200 photos · 34 vidéos » (omet les zéros).
    private func mediaBreakdown(photos: Int, videos: Int) -> String {
        var parts: [String] = []
        if photos > 0 { parts.append("\(Fmt.count(photos)) photo\(photos > 1 ? "s" : "")") }
        if videos > 0 { parts.append("\(Fmt.count(videos)) vidéo\(videos > 1 ? "s" : "")") }
        return parts.joined(separator: " · ")
    }

    /// Carte « contenu » : compte de médias en grand (un dossier plein sans
    /// sous-dossier n'a plus l'air vide).
    private func mediaContentCard(photos: Int, videos: Int) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "photo.stack.fill")
                .font(.system(size: 40))
                .foregroundStyle(theme.accent)
            Text("\(Fmt.count(photos + videos))")
                .yzDisplay(46)
                .foregroundStyle(theme.t1)
            Text("photos & vidéos")
                .font(YZFont.headline)
                .foregroundStyle(theme.t2)
            Text(mediaBreakdown(photos: photos, videos: videos))
                .font(YZFont.subhead)
                .foregroundStyle(theme.t2)
            Text("Touche « Choisir ici » en haut pour trier ce dossier.")
                .font(YZFont.footnote)
                .foregroundStyle(theme.t3)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .yzSurface(theme, radius: YZRadius.card)
    }

    /// Jauge de capacité du partage : occupé / libre / total (style identique à
    /// la jauge des Réglages). Affichée à la racine du disque réseau.
    private func capacityCard(_ cap: (total: Int64, free: Int64)) -> some View {
        let used = max(0, cap.total - cap.free)
        let fraction = cap.total > 0 ? min(1, Double(used) / Double(cap.total)) : 0
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "internaldrive.fill").foregroundStyle(theme.accent)
                Text("Capacité du disque").font(YZFont.subheadSemi).foregroundStyle(theme.t1)
                Spacer()
                Text("\(Fmt.bytes(cap.free)) libre")
                    .font(YZFont.subheadSemi).foregroundStyle(theme.keep)
            }
            YZProgressBar(value: fraction, tone: theme.accent, height: 9)
            HStack {
                Text("\(Fmt.bytes(used)) occupés").foregroundStyle(theme.t2)
                Spacer()
                Text("sur \(Fmt.bytes(cap.total))").foregroundStyle(theme.t3)
            }
            .font(YZFont.footnote)
        }
        .padding(14)
        .yzSurface(theme, radius: YZRadius.card)
    }

    // MARK: Composants

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            .padding(12).background(theme.bg2, in: RoundedRectangle(cornerRadius: YZRadius.button))
            .overlay { RoundedRectangle(cornerRadius: YZRadius.button).strokeBorder(theme.sep, lineWidth: 0.5) }
            .foregroundStyle(theme.t1)
    }

    private func secureField(_ placeholder: String, text: Binding<String>) -> some View {
        SecureField(placeholder, text: text)
            .padding(12).background(theme.bg2, in: RoundedRectangle(cornerRadius: YZRadius.button))
            .overlay { RoundedRectangle(cornerRadius: YZRadius.button).strokeBorder(theme.sep, lineWidth: 0.5) }
            .foregroundStyle(theme.t1)
    }

    private func row(icon: String, title: String, chevron: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(theme.accent).frame(width: 26)
            Text(title).font(YZFont.body).foregroundStyle(theme.t1).lineLimit(1)
            Spacer()
            if chevron { Image(systemName: "chevron.right").font(.footnote).foregroundStyle(theme.t3) }
        }
        .padding(.vertical, 11).padding(.horizontal, 14)
        .yzSurface(theme, radius: YZRadius.button)
    }

    // MARK: Actions

    private func connect() {
        keyboardUp = false   // rétracte le clavier dès qu'on lance la connexion
        let h = host.trimmingCharacters(in: .whitespaces)
        let u = user.trimmingCharacters(in: .whitespaces)
        let p = password
        // Validation CLAIRE avant toute tentative réseau : un champ vide donnait un
        // « error code 1 » cryptique de libsmb2. On dit précisément ce qui manque.
        if h.isEmpty { error = "Indique l'adresse du serveur (ex. 192.168.0.83)."; return }
        if u.isEmpty { error = "Indique le nom d'utilisateur."; return }
        if p.isEmpty { error = "Indique le mot de passe."; return }
        run {
            shares = try await smbWithTimeout(10) { try await SMBStore.listShares(host: h, user: u, password: p) }
            env.settings.rememberSMB(host: h, user: u, password: p)
            step = .shares
        }
    }

    private func openShare(_ share: String) {
        let h = host, u = user, p = password
        capacity = nil
        run {
            let store = SMBStore(host: h, share: share, user: u, password: p)
            try await smbWithTimeout(10) { try await store.connect() }
            currentShare = share
            path = "/"
            entries = try await smbWithTimeout(10) { try await store.list("/") }
            browseStore = store
            step = .browse
            loadCapacity(store)
        }
    }

    /// Interroge la capacité du partage **sans bloquer** la navigation ni écraser
    /// une erreur : best-effort, la carte apparaît quand la réponse arrive.
    private func loadCapacity(_ store: SMBStore) {
        Task {
            if let cap = try? await smbWithTimeout(10, { try await store.capacity() }), cap.total > 0 {
                capacity = cap
            }
        }
    }

    private func openFolder(_ name: String) {
        guard let store = browseStore else { return }
        let newPath = SMBMediaStore.join(path, name)
        run {
            entries = try await store.list(newPath)
            path = newPath
        }
    }

    private func goUp() {
        guard let store = browseStore, path != "/" else { return }
        let parent = (path as NSString).deletingLastPathComponent
        let newPath = parent.isEmpty ? "/" : parent
        run {
            entries = try await store.list(newPath)
            path = newPath
        }
    }

    private func choose() {
        run {
            try await env.attachSMBDrive(host: host, share: currentShare, path: path, user: user, password: password)
            dismiss()
        }
    }

    /// Exécute une tâche async en gérant chargement + erreur.
    private func run(_ work: @escaping () async throws -> Void) {
        loading = true
        error = nil
        Task {
            do { try await work() } catch { self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription }
            loading = false
        }
    }
}

/// Erreur de délai dépassé (message en français, le plus fréquent : pas sur le
/// bon Wi-Fi / en données mobiles → l'adresse locale du disque est injoignable).
struct SMBConnectionTimeout: LocalizedError {
    var errorDescription: String? {
        "Connexion trop longue. Vérifie que tu es sur le même réseau Wi-Fi que le disque — ça ne fonctionne pas en données mobiles ni à distance."
    }
}

/// Exécute une opération SMB avec un délai maximal : au-delà, on abandonne et on
/// lève `SMBConnectionTimeout` (au lieu d'attendre >1 min le timeout réseau natif).
func smbWithTimeout<T: Sendable>(_ seconds: Double, _ op: @Sendable @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await op() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw SMBConnectionTimeout()
        }
        defer { group.cancelAll() }
        guard let result = try await group.next() else { throw SMBConnectionTimeout() }
        return result
    }
}
