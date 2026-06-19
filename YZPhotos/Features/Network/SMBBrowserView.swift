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

    @State private var loading = false
    @State private var error: String?

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
                }
                .tint(theme.accent)
        }
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
            Text("Connecte-toi à ton serveur (Freebox, NAS…). Le mot de passe est stocké dans le trousseau de l'iPad.")
                .font(YZFont.subhead).foregroundStyle(theme.t2)
            field("Adresse du serveur (ex. 192.168.0.83)", text: $host)
            field("Utilisateur", text: $user)
            secureField("Mot de passe", text: $password)
            Button { connect() } label: {
                Label("Se connecter", systemImage: "network")
            }
            .buttonStyle(YZButtonStyle(.primary, size: .lg, fullWidth: true))
            .disabled(loading || host.isEmpty)
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
                    Button { goUp() } label: { Label("Remonter", systemImage: "chevron.up") }
                        .font(YZFont.subheadSemi).foregroundStyle(theme.accent)
                }
                Spacer()
                Text(path).font(YZFont.footnote).foregroundStyle(theme.t3).lineLimit(1)
            }
            if path == "/" {
                // Choisir le partage ENTIER comme un dossier (en un tap).
                Button { choose() } label: {
                    Label("Scanner tout le disque « \(currentShare) »", systemImage: "externaldrive.fill")
                }
                .buttonStyle(YZButtonStyle(.primary, fullWidth: true))
                .disabled(loading)
                Text("Ou descends dans un dossier pour n'en scanner qu'une partie.")
                    .font(YZFont.footnote).foregroundStyle(theme.t3)
            }
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(sortedEntries, id: \.name) { entry in
                        if entry.isDirectory {
                            Button { openFolder(entry.name) } label: {
                                row(icon: "folder.fill", title: entry.name, chevron: true)
                            }.buttonStyle(.plain)
                        } else {
                            row(icon: "doc", title: entry.name, chevron: false).opacity(0.55)
                        }
                    }
                }
            }
            Text("Astuce : descends jusqu'au dossier qui contient tes photos (ou choisis la racine du partage), puis « Choisir ici ».")
                .font(YZFont.footnote).foregroundStyle(theme.t3)
        }
    }

    private var sortedEntries: [SMBStore.Entry] {
        entries.sorted { a, b in
            a.isDirectory != b.isDirectory ? a.isDirectory : a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
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
        run {
            shares = try await SMBStore.listShares(host: host, user: user, password: password)
            step = .shares
        }
    }

    private func openShare(_ share: String) {
        run {
            let store = SMBStore(host: host, share: share, user: user, password: password)
            try await store.connect()
            currentShare = share
            path = "/"
            entries = try await store.list("/")
            browseStore = store
            step = .browse
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
