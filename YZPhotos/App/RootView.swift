import SwiftUI
import UIKit

/// Porte d'entrée : picker du disque → écran de reconnexion → onglets.
struct RootView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var showPicker = false
    @State private var pickerError: String?
    @State private var didRestore = false

    var body: some View {
        Group {
            switch env.driveAccess.state {
            case .noDrive:
                WelcomeView(showPicker: $showPicker)
            case .disconnected(let drive):
                DisconnectedView(
                    driveName: drive.name,
                    showPicker: $showPicker,
                    onRetry: { reconnect(drive) }
                )
            case .connected(let drive, let url):
                MainTabView(drive: drive, root: url)
            }
        }
        .fileImporter(isPresented: $showPicker, allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let url):
                do {
                    let drive = try env.driveAccess.attach(pickedURL: url)
                    env.driveDidConnect(drive, root: url)
                } catch {
                    pickerError = error.localizedDescription
                }
            case .failure:
                break
            }
        }
        .alert("Impossible d'accéder au disque", isPresented: .init(
            get: { pickerError != nil },
            set: { if !$0 { pickerError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(pickerError ?? "")
        }
        .environment(\.yzTheme, env.settings.theme)
        .tint(env.settings.theme.accent)
        .preferredColorScheme(env.settings.themeKind.colorScheme)
        .onAppear {
            // Le tri et l'analyse sont longs : l'iPad ne doit jamais se verrouiller
            // tant que l'app est au premier plan.
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .task {
            guard !didRestore else { return }
            didRestore = true
            await env.driveAccess.restoreOnLaunch()
            if case .connected(let drive, let url) = env.driveAccess.state {
                env.driveDidConnect(drive, root: url)
            }
        }
    }

    private func reconnect(_ drive: DriveRecord) {
        if env.driveAccess.reconnect(drive),
           case .connected(let connected, let url) = env.driveAccess.state {
            env.driveDidConnect(connected, root: url)
        }
    }
}

enum WelcomeSheet: Identifiable { case smb, info; var id: Int { hashValue } }

struct WelcomeView: View {
    @Binding var showPicker: Bool
    @Environment(\.yzTheme) private var theme
    // Une SEULE feuille à la fois (empiler deux .sheet sur la même vue affichait
    // un double bouton « Annuler »).
    @State private var activeSheet: WelcomeSheet?

    var body: some View {
        VStack(spacing: 0) {
            AppLogoTile(theme: theme)
                .padding(.bottom, 22)
            Text("YZPhotos")
                .yzDisplay(30)
                .foregroundStyle(theme.t1)
                .padding(.bottom, 8)
            Text("Branche ton SSD en USB-C, puis choisis-le pour commencer le tri.")
                .font(YZFont.body)
                .foregroundStyle(theme.t2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
                .padding(.bottom, 30)
            Button {
                showPicker = true
            } label: {
                Label("Brancher un disque USB-C", systemImage: "externaldrive.badge.plus")
            }
            .buttonStyle(YZButtonStyle(.primary, size: .lg))
            Button {
                activeSheet = .smb
            } label: {
                Label("Disque réseau (SMB)", systemImage: "network")
            }
            .buttonStyle(YZButtonStyle(.secondary, size: .lg))
            .padding(.top, 12)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .yzScreenBackground(theme)
        .overlay(alignment: .topLeading) { LanguageToggle().padding(16) }
        .overlay(alignment: .topTrailing) { InfoButton(action: { activeSheet = .info }) }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .smb: SMBBrowserView()
            case .info: AppInfoView()
            }
        }
    }
}

/// Bouton « i » discret en haut à droite des écrans d'accueil.
struct InfoButton: View {
    let action: () -> Void
    @Environment(\.yzTheme) private var theme
    var body: some View {
        Button(action: action) {
            Image(systemName: "info.circle")
                .font(.title2)
                .foregroundStyle(theme.t2)
                .padding(20)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("À propos")
    }
}

/// Sélecteur de langue compact (🇫🇷/🇬🇧) pour les écrans SANS disque branché
/// (où Réglages n'existe pas encore) → on n'est jamais coincé dans une langue.
struct LanguageToggle: View {
    @Environment(LocalizationManager.self) private var localization
    @Environment(\.yzTheme) private var theme
    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppLanguage.allCases) { lang in
                let on = localization.language == lang
                Button { localization.set(lang) } label: {
                    Text("\(lang.flag) \(lang.rawValue.uppercased())")
                        .font(.subheadline.weight(on ? .bold : .regular))
                        .foregroundStyle(on ? theme.t1 : theme.t3)
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .background { if on { Capsule().fill(theme.accent.opacity(0.28)) } }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay { Capsule().strokeBorder(theme.sep, lineWidth: 0.5) }
        .accessibilityLabel("Langue")
    }
}

/// Écran « À propos » accessible sans disque branché : version + infos de l'app.
struct AppInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.yzTheme) private var theme

    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(v) (build \(b))"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                AppLogoTile(theme: theme)
                    .padding(.top, 24)
                Text("YZPhotos")
                    .yzDisplay(30)
                    .foregroundStyle(theme.t1)

                VStack(spacing: 4) {
                    Text("Version")
                        .font(YZFont.subhead)
                        .foregroundStyle(theme.t2)
                    Text(version)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(theme.t1)
                }
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .yzSurface(theme, radius: YZRadius.card)

                Text("Tri rapide de photos et vidéos sur disque USB-C ou réseau (SMB). Repère les doublons, libère de l'espace, sans jamais déplacer tes fichiers sans toi.")
                    .font(YZFont.subhead)
                    .foregroundStyle(theme.t2)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)

                Spacer()
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .yzScreenBackground(theme)
            .navigationTitle("À propos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .tint(theme.accent)
    }
}

struct DisconnectedView: View {
    let driveName: String
    @Binding var showPicker: Bool
    let onRetry: () -> Void
    @Environment(\.yzTheme) private var theme
    @State private var showInfo = false

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(theme.warn)
                .frame(width: 92, height: 92)
                .yzSurface(theme, radius: 24)
                .padding(.bottom, 22)
            Text("Brancher « \(driveName) »")
                .yzDisplay(26)
                .foregroundStyle(theme.t1)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)
            Text("Le disque n'est pas accessible. Branche-le, attends quelques secondes, puis réessaie.")
                .font(YZFont.body)
                .foregroundStyle(theme.t2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
                .padding(.bottom, 30)
            HStack(spacing: 12) {
                Button { onRetry() } label: {
                    Label("Réessayer", systemImage: "arrow.clockwise")
                }
                .buttonStyle(YZButtonStyle(.primary, size: .lg))
                Button { showPicker = true } label: {
                    Text("Autre dossier")
                }
                .buttonStyle(YZButtonStyle(.secondary, size: .lg))
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .yzScreenBackground(theme)
        .overlay(alignment: .topLeading) { LanguageToggle().padding(16) }
        .overlay(alignment: .topTrailing) { InfoButton(action: { showInfo = true }) }
        .sheet(isPresented: $showInfo) { AppInfoView() }
    }
}

/// Pastille logo de l'app (dégradé accent) pour les écrans de lancement.
struct AppLogoTile: View {
    let theme: YZTheme
    var body: some View {
        Image(systemName: "rectangle.stack.fill")
            .font(.system(size: 34, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 78, height: 78)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(colors: [theme.isGlass ? Color(hex: 0xE87B3E) : theme.accent,
                                                  theme.isGlass ? Color(hex: 0xB23A5D) : Color(hex: 0x6E6CE0)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .shadow(color: .blackA(0.25), radius: 12, y: 6)
    }
}
