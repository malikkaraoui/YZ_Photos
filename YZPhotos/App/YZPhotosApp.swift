import SwiftUI

@main
struct YZPhotosApp: App {
    @State private var environment = AppEnvironment()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
        }
        // Arrière-plan : sursis maximal autorisé par iOS (~30 s de travail),
        // puis arrêt propre ; reprise automatique au retour au premier plan.
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                environment.scan.enteredBackground()
                environment.duplicates.enteredBackground()
            case .active:
                environment.scan.enteredForeground()
                environment.duplicates.enteredForeground()
            default:
                break
            }
        }
    }
}
