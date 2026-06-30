import SwiftUI

@main
struct YZPhotosApp: App {
    @UIApplicationDelegateAdaptor(YZAppDelegate.self) private var appDelegate
    @State private var environment = AppEnvironment()
    @State private var localization = LocalizationManager.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .environment(localization)
                // Langue choisie dans Réglages : change \.locale → toute l'UI se
                // re-localise instantanément (le bundle pointe déjà sur le bon .lproj).
                .environment(\.locale, localization.locale)
        }
        // Arrière-plan : sursis maximal autorisé par iOS (~30 s de travail),
        // puis arrêt propre ; reprise automatique au retour au premier plan.
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                environment.scan.enteredBackground()
                environment.duplicates.enteredBackground()
                environment.enteredBackground()   // libère la mémoire (anti-jetsam)
            case .active:
                environment.scan.enteredForeground()
                environment.duplicates.enteredForeground()
                environment.enteredForeground()
            default:
                break
            }
        }
    }
}
