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

struct WelcomeView: View {
    @Binding var showPicker: Bool
    @Environment(\.yzTheme) private var theme
    @State private var showSMB = false

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
                showSMB = true
            } label: {
                Label("Disque réseau (SMB)", systemImage: "network")
            }
            .buttonStyle(YZButtonStyle(.secondary, size: .lg))
            .padding(.top, 12)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .yzScreenBackground(theme)
        .sheet(isPresented: $showSMB) {
            SMBBrowserView()
        }
    }
}

struct DisconnectedView: View {
    let driveName: String
    @Binding var showPicker: Bool
    let onRetry: () -> Void
    @Environment(\.yzTheme) private var theme

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
