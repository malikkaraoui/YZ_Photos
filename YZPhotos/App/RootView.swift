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
        .preferredColorScheme(env.settings.appearance.colorScheme)
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

    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: "externaldrive.badge.plus")
                .font(.system(size: 90))
                .foregroundStyle(.tint)
            Text("YZPhotos")
                .font(.system(size: 44, weight: .bold))
            Text("Branche ton disque en USB-C, puis choisis-le dans la liste pour commencer le tri.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
            Button {
                showPicker = true
            } label: {
                Label("Choisir le disque", systemImage: "externaldrive")
                    .font(.title2.bold())
                    .padding(.horizontal, 28)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DisconnectedView: View {
    let driveName: String
    @Binding var showPicker: Bool
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 90))
                .foregroundStyle(.orange)
            Text("Brancher « \(driveName) »")
                .font(.system(size: 36, weight: .bold))
            Text("Le disque n'est pas accessible. Branche-le, attends quelques secondes, puis réessaie.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
            HStack(spacing: 16) {
                Button {
                    onRetry()
                } label: {
                    Label("Réessayer", systemImage: "arrow.clockwise")
                        .font(.title2.bold())
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                Button {
                    showPicker = true
                } label: {
                    Text("Choisir un autre dossier")
                        .font(.title3)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
